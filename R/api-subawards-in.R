## Inbound subaward fetch -- the subawardee side of FSRS, by UEI.
##
## Measured 2026-08-28, all live:
##   * recipient_search_text with subawards=TRUE matches the SUBAWARDEE --
##     exactly the inbound direction. Verified against a known case (Kaiser
##     receiving FEMA money through CA OES).
##   * The count endpoint accepts ~20 UEIs; 50 returns HTTP 503. Batches of
##     very large organizations time out server-side even below the cap, so
##     batches split recursively on failure.
##   * award_type_codes is REQUIRED (HTTP 422 without it) and cannot mix
##     families -- one pass per family, as in us_fetch_subawards_batch().
##   * "Prime Award Recipient UEI" is the working field name for the prime's
##     UEI ("Prime Recipient UEI" is accepted but returns NULL).

#' Fetch inbound subawards for a set of UEIs
#'
#' Inbound subawards -- money an organization receives as a *subawardee* --
#' appear nowhere in prime award data, and the annual Award Data Archive
#' carries no subawards at all. This fetches them from the API, so an
#' archive-path extract (or any UEI list) can be given its inbound flows.
#'
#' Two routes:
#' \describe{
#'   \item{`via = "search"` (default)}{Filters
#'     `POST /api/v2/search/spending_by_award/` with `subawards = TRUE` on
#'     `recipient_search_text`, which -- measured live -- matches the
#'     **subawardee**. Each batch is counted first and skipped when it holds
#'     nothing, so the common case (an organization with no inbound
#'     subawards) costs one cheap count. Orders of magnitude faster than
#'     download jobs at crosswalk scale.}
#'   \item{`via = "download"`}{Runs the standard bulk-download jobs and
#'     harvests only their subaward files -- the API path's full cost. The
#'     fallback if the search route ever misbehaves; also the only route
#'     that returns FSRS report-period columns (`report_year`,
#'     `report_month`, `report_last_modified`).}
#' }
#'
#' Measured constraints the search route works around (all hit live):
#' `recipient_search_text` caps near 20 values (50 returns HTTP 503) and
#' batches of very large organizations time out server-side, so batches
#' split recursively on failure down to a single UEI, then split the time
#' period; `award_type_codes` is required and cannot mix families
#' (HTTP 422), so it runs one pass per family; the 10k result cap is per
#' filter set, so any batch counting near it is split before fetching. UEIs
#' that still fail after all splitting are reported in the `failures`
#' attribute and a warning -- a failure is never allowed to read as "no
#' subawards".
#'
#' One measured quirk shapes the design: the search view returns the
#' `Sub-Awardee UEI` field as `NULL` even on rows it matched *by* that UEI,
#' so returned rows cannot be attributed from their own columns. Fetches
#' therefore run **one UEI at a time** (counts stay batched), and
#' `subawardee_uei` is stamped from the query. The text search could in
#' principle match something other than the UEI string; the pilot validation
#' found no such strays, but per-organization totals should still be checked
#' against an independent figure where one exists. `prime_uei` is filled from
#' `Prime Award Recipient UEI`, so [us_normalize_subawards()] can classify
#' `internal` flows.
#'
#' @param uei Character vector of UEIs (the subawardee side).
#' @param years Integer vector of fiscal years; `NULL` for everything since
#'   FY2008.
#' @param via `"search"` (default) or `"download"`.
#' @param batch_size UEIs per search request. Max ~20; the conservative
#'   default leaves headroom for large organizations.
#' @param cap_guard Split a batch when its subaward count exceeds this.
#' @param dest `"download"` route only: directory for intermediate files
#'   (subaward CSVs land in a `subawards_in/` subdirectory).
#' @return A `data.table` matching `us_schema("subawards")`, one row per
#'   inbound subaward, with a `failures` attribute (a `data.table`, possibly
#'   empty) recording anything that could not be resolved. Direction is left
#'   unset -- [us_normalize_subawards()] assigns it from the organization's
#'   UEI set.
#' @export
#' @examples
#' \dontrun{
#' ex <- us_extract(ueis, years = 2008:2025, source = "archive")
#' ex$subawards <- us_fetch_subawards_in(ueis, 2008:2025)
#' }
us_fetch_subawards_in <- function(uei, years = NULL,
                                  via = c("search", "download"),
                                  batch_size = 10, cap_guard = 9000,
                                  dest = us_cache_dir("raw")) {
  via <- match.arg(via)
  uei <- unique(us_validate_uei(uei))
  uei <- uei[!is.na(uei)]
  if (!length(uei)) return(us_empty("subawards"))

  start_date <- if (is.null(years)) "2007-10-01" else sprintf("%d-10-01", min(years) - 1L)
  end_date   <- if (is.null(years)) as.character(Sys.Date() + 365) else sprintf("%d-09-30", max(years))

  if (via == "download") {
    n_jobs <- ceiling(length(uei) / us_opt("batch_size"))
    us_msg("Fetching inbound subawards for {length(uei)} UEI{?s} through {n_jobs} API download job{?s}.")
    dest_sub <- file.path(dest, "subawards_in")
    jobs <- us_download_run(uei, us_award_type_codes("all"), start_date, end_date)
    us_download_fetch(jobs, dest = dest_sub)
    out <- read_download_dir(dest_sub)$subawards
    data.table::setattr(out, "failures", data.table::data.table())
    return(out)
  }

  fields <- c("Sub-Award ID", "Sub-Award Amount", "Sub-Award Date",
              "Sub-Awardee Name", "Sub-Awardee UEI", "Prime Award ID",
              "Prime Recipient Name", "Prime Award Recipient UEI",
              "prime_award_generated_internal_id", "Sub-Award Type")
  failures <- list()

  count_q <- function(b, types, tp) {
    r <- us_api_try("search/spending_by_award_count/", body = list(
      filters = list(recipient_search_text = I(b), award_type_codes = I(types),
                     time_period = tp),
      subawards = TRUE))
    if (!r$ok) return(NA_integer_)
    sum(unlist(r$result$results), na.rm = TRUE)
  }
  fetch_q <- function(b, types, tp) {
    acc <- list(); page <- 1L
    repeat {
      r <- us_api_try("search/spending_by_award/", body = list(
        filters = list(recipient_search_text = I(b), award_type_codes = I(types),
                       time_period = tp),
        fields = I(fields), subawards = TRUE, limit = 100, page = page))
      if (!r$ok) return(NULL)          # transport failure: caller splits or records
      if (!length(r$result$results)) break
      acc <- c(acc, r$result$results)
      if (!isTRUE(r$result$page_metadata$hasNext) || page >= 100L) break
      page <- page + 1L
    }
    if (!length(acc)) return(data.table::data.table())
    data.table::rbindlist(lapply(acc, function(x) data.table::data.table(
      subaward_number      = as_chr(x[["Sub-Award ID"]] %||% NA),
      subaward_amount      = as_num(x[["Sub-Award Amount"]] %||% NA),
      subaward_action_date = as_date(x[["Sub-Award Date"]] %||% NA),
      subawardee_name      = as_chr(x[["Sub-Awardee Name"]] %||% NA),
      subawardee_uei       = clean_uei(x[["Sub-Awardee UEI"]] %||% NA),
      prime_award_id       = as_chr(x[["Prime Award ID"]] %||% NA),
      prime_name           = as_chr(x[["Prime Recipient Name"]] %||% NA),
      prime_uei            = clean_uei(x[["Prime Award Recipient UEI"]] %||% NA),
      prime_award_key      = as_chr(x[["prime_award_generated_internal_id"]] %||% NA),
      subaward_type        = as_chr(x[["Sub-Award Type"]] %||% NA))),
      fill = TRUE)
  }
  window <- function(s, e) list(list(start_date = as.character(s), end_date = as.character(e)))
  bind <- function(parts) {
    ## rbindlist, never rbind -- see us_fetch_subawards_batch()
    parts <- Filter(function(x) !is.null(x) && nrow(x) > 0L, parts)
    if (!length(parts)) return(NULL)
    data.table::rbindlist(parts, fill = TRUE)
  }
  ## One UEI at a time: the search view returns Sub-Awardee UEI as NULL even
  ## on rows it matched BY that UEI (measured: 29,327 of 29,327 rows), so the
  ## only reliable attribution is the query itself -- each fetch covers a
  ## single UEI and stamps it on the rows. A failing count or fetch splits the
  ## time window; only a window at a year or less is allowed to fail, and
  ## then it is recorded, never swallowed.
  run_one <- function(u, types, s, e) {
    tp <- window(s, e)
    n <- count_q(u, types, tp)
    if (!is.na(n) && n == 0L) return(NULL)
    res <- if (is.na(n) || n > cap_guard) NULL else fetch_q(u, types, tp)
    if (is.null(res)) {
      if (as.numeric(as.Date(e) - as.Date(s)) > 370) {
        mid <- as.Date(s) + floor(as.numeric(as.Date(e) - as.Date(s)) / 2)
        return(bind(list(run_one(u, types, s, mid),
                         run_one(u, types, mid + 1, e))))
      }
      failures[[length(failures) + 1L]] <<- data.table::data.table(
        uei = u, family = types[1], start = as.character(s), end = as.character(e))
      return(NULL)
    }
    if (nrow(res)) res[, "subawardee_uei" := u]
    res
  }
  ## Batched count screen: an organization with no inbound subawards -- the
  ## common case at scale -- costs 1/batch_size of a request. A batch whose
  ## count fails is halved (big-org batches time out server-side); a positive
  ## batch descends to per-UEI fetches for attribution.
  run <- function(b, types, s, e) {
    if (length(b) == 1L) return(run_one(b, types, s, e))
    n <- count_q(b, types, window(s, e))
    if (!is.na(n) && n == 0L) return(NULL)
    if (is.na(n)) {
      h <- ceiling(length(b) / 2)
      return(bind(list(run(b[1:h], types, s, e),
                       run(b[(h + 1):length(b)], types, s, e))))
    }
    bind(lapply(b, run_one, types = types, s = s, e = e))
  }

  fam <- list(assistance = us_award_type_codes("assistance"),
              contract   = c(us_award_type_codes("contract"),
                             us_award_type_codes("idv")))
  batches <- chunk(uei, batch_size)
  us_msg("Fetching inbound subawards: {length(uei)} UEI{?s} in {length(batches)} batch{?es} x {length(fam)} famil{?y/ies}.")
  res <- data.table::rbindlist(Filter(Negate(is.null), unlist(
    lapply(fam, function(ty) lapply(batches, run, types = ty,
                                    s = as.Date(start_date), e = as.Date(end_date))),
    recursive = FALSE)), fill = TRUE)

  ## Failures are overwhelmingly transient (validation: 5 failed orgs out of
  ## 130 on the first pass, all 5 clean on a retry), so retry each failed
  ## window once before reporting anything as unresolved.
  if (length(failures)) {
    fl0 <- data.table::rbindlist(failures)
    failures <- list()
    us_msg("Retrying {nrow(fl0)} failed window{?s} across {data.table::uniqueN(fl0$uei)} UEI{?s}.")
    retry <- data.table::rbindlist(Filter(Negate(is.null),
      lapply(seq_len(nrow(fl0)), function(i) {
        ty <- if (fl0$family[i] %in% us_award_type_codes("assistance")) fam$assistance else fam$contract
        run_one(fl0$uei[i], ty, as.Date(fl0$start[i]), as.Date(fl0$end[i]))
      })), fill = TRUE)
    if (nrow(retry)) res <- data.table::rbindlist(list(res, retry), fill = TRUE)
  }

  fl <- if (length(failures)) data.table::rbindlist(failures) else data.table::data.table()
  if (nrow(fl)) {
    cli::cli_warn(c("{data.table::uniqueN(fl$uei)} UEI{?s} could not be resolved after splitting; their inbound subawards are MISSING, not zero.",
                    "i" = "See {.code attr(result, \"failures\")}."))
  }
  if (!nrow(res)) {
    out <- us_empty("subawards")
    data.table::setattr(out, "failures", fl)
    return(out)
  }
  res <- unique(res)
  us_msg("{nrow(res)} inbound subaward row{?s} across {data.table::uniqueN(res$subawardee_uei)} UEI{?s}.")

  out <- us_empty("subawards")[seq_len(nrow(res))]
  for (cc in intersect(names(res), names(out))) out[, (cc) := res[[cc]]]
  out[, "subaward_year" := calendar_year(subaward_action_date)]
  out[, "subaward_fiscal_year" := fiscal_year(subaward_action_date)]
  out[, "subaward_key" := paste(prime_award_key, subaward_number,
                                format(subaward_action_date), sep = "|")]
  out[, "source_file" := "api:spending_by_award:subawards_in"]
  data.table::setattr(out, "failures", fl)
  out[]
}
