#' Pre-flight award counts for a set of UEIs
#'
#' Cheap reconnaissance before committing to a pull: how many prime awards each
#' UEI has, by category. Use it to decide between the API and the archive path,
#' to size download batches, and to distinguish genuine non-recipients from
#' failed requests.
#'
#' Failures are recorded, never swallowed. A request that errors comes back with
#' `error = TRUE` and `n_awards = NA`, because a failure that reads as zero is
#' the most damaging silent bug in this pipeline -- it turns a rate-limit blip
#' into a permanent "this nonprofit gets no federal money".
#'
#' @param uei Character vector of UEIs.
#' @param start_date,end_date Action-date bounds.
#' @return A `data.table`: one row per UEI with `contracts`, `idvs`, `grants`,
#'   `direct_payments`, `loans`, `other`, `n_awards`, `error`, `message`.
#' @export
#' @examples
#' \dontrun{
#' us_award_counts(c("CFFMYPABYAG3", "H7LMD1ANJNN4"))
#' }
us_award_counts <- function(uei, start_date = "2007-10-01", end_date = Sys.Date()) {
  uei <- us_validate_uei(uei)
  cats <- c("contracts", "idvs", "grants", "direct_payments", "loans", "other")
  one <- function(u) {
    r <- us_api_try("search/spending_by_award_count/", body = list(
      filters = list(recipient_search_text = I(u),
                     time_period = list(list(start_date = as.character(as_date(start_date)),
                                             end_date = as.character(as_date(end_date))))),
      subawards = FALSE))
    if (!r$ok) {
      return(data.table::data.table(uei = u, error = TRUE, message = r$error))
    }
    res <- r$result$results %||% list()
    data.table::data.table(uei = u, error = FALSE, message = NA_character_,
                           data.table::as.data.table(lapply(res, function(x) x %||% NA)))
  }
  out <- data.table::rbindlist(lapply(uei, one), fill = TRUE)
  for (k in cats) if (!k %in% names(out)) out[, (k) := NA_integer_]
  out[, (cats) := lapply(.SD, as_int), .SDcols = cats]
  out[, "n_awards" := rowSums(as.matrix(.SD), na.rm = TRUE), .SDcols = cats]
  out[error == TRUE, "n_awards" := NA_integer_]
  n_err <- sum(out$error)
  if (n_err) cli::cli_warn("{n_err} of {nrow(out)} UEI{?s} did not resolve; their counts are NA, not zero.")
  data.table::setcolorder(out, c("uei", "error", "n_awards", cats, "message"))
  out[]
}

#' Prime award overview
#'
#' Fetches `GET /api/v2/awards/{award_key}/` for one award. This is the only
#' place USAspending exposes `subaward_count` and `total_subaward_amount`, which
#' is what makes the pass-through screen in [us_fetch_subawards_out()] cheap.
#'
#' Note that `total_obligation`, `total_outlay` and `total_subaward_amount` are
#' all award-lifetime figures. They are useful for reconciliation, never as an
#' annual measure.
#'
#' @param award_key A generated unique award id, e.g. `"ASST_NON_R01AA025947_075"`.
#' @return A one-row `data.table`, or a row with `error = TRUE` on failure.
#' @export
#' @examples
#' \dontrun{
#' us_fetch_award("ASST_NON_4482DRCAP00000001_070")
#' }
us_fetch_award <- function(award_key) {
  r <- us_api_try(paste0("awards/", utils::URLencode(award_key, reserved = TRUE), "/"))
  if (!r$ok) {
    return(data.table::data.table(award_key = award_key, error = TRUE, message = r$error))
  }
  a <- r$result
  data.table::data.table(
    award_key       = award_key,
    error           = FALSE,
    message         = NA_character_,
    award_id        = as_chr(a$fain %||% a$piid %||% NA),
    category        = as_chr(a$category %||% NA),
    award_type_code = as_chr(a$type %||% NA),
    date_signed     = as_date(a$date_signed %||% NA),
    total_obligated = as_num(a$total_obligation %||% NA),
    total_outlayed  = as_num(a$total_outlay %||% NA),
    subaward_count  = as_int(a$subaward_count %||% NA),
    subaward_total  = as_num(a$total_subaward_amount %||% NA)
  )
}

#' Subawards paid out by a prime award
#'
#' **This is not the same thing as the subaward files that come back from the
#' bulk download endpoint.** Filtering `/download/transactions/` on
#' `recipient_search_text` returns subawards where your UEI is the
#' *subawardee* -- money flowing in. Verified twice: a three-UEI probe returned
#' 32 subaward rows, all inbound; the full 50-org pilot returned 39,243 rows,
#' every one inbound or internal, zero outbound.
#'
#' To measure pass-through -- money the organization is obliged to pay onward,
#' which must be netted out of revenue -- you have to query by prime award.
#' There is no bulk file for this; the annual Award Data Archive contains prime
#' transactions only.
#'
#' For many awards use [us_fetch_subawards_batch()], which batches hundreds of
#' award ids per query. This per-award walk survives for one-off inspection of
#' a single award; it screens on `subaward_count` first unless `screen = FALSE`.
#'
#' @param award_key Character vector of generated unique award ids.
#' @param screen Check `subaward_count` first and skip awards that report none.
#' @param page_limit Records per page (API maximum 100).
#' @return A `data.table` with one row per subaward: `award_key`,
#'   `subaward_number`, `subaward_action_date`, `subaward_amount`,
#'   `subawardee_name`, `description`.
#' @export
#' @examples
#' \dontrun{
#' us_fetch_subawards_out("ASST_NON_4482DRCAP00000001_070")
#' }
us_fetch_subawards_out <- function(award_key, screen = TRUE, page_limit = 100) {
  award_key <- unique(as_chr(award_key))
  award_key <- award_key[!is.na(award_key)]
  if (!length(award_key)) return(us_empty("subawards"))

  if (screen) {
    ov <- data.table::rbindlist(lapply(award_key, us_fetch_award), fill = TRUE)
    keep <- ov[error == FALSE & !is.na(subaward_count) & subaward_count > 0]$award_key
    us_msg("Screened {length(award_key)} award{?s}; {length(keep)} report subawards.")
    award_key <- keep
    if (!length(award_key)) return(us_empty("subawards"))
  }

  one <- function(k) {
    res <- tryCatch(
      us_api_pages("subawards/", body = list(award_id = k), limit = page_limit),
      error = function(e) {
        cli::cli_warn("Subaward fetch failed for {.val {k}}: {conditionMessage(e)}")
        list()
      })
    if (!length(res)) return(NULL)
    dt <- rows_to_dt(res)
    data.table::data.table(
      award_key            = k,
      subaward_number      = as_chr(dt$subaward_number),
      subaward_action_date = as_date(dt$action_date),
      subaward_amount      = as_num(dt$amount),
      subawardee_name      = as_chr(dt$recipient_name),
      description          = as_chr(dt$description))
  }
  out <- data.table::rbindlist(Filter(Negate(is.null), lapply(award_key, one)), fill = TRUE)
  if (!nrow(out)) return(out)
  out[, c("subaward_year", "subaward_fiscal_year") :=
        list(calendar_year(subaward_action_date), fiscal_year(subaward_action_date))]
  out[]
}

#' Batched outbound subaward fetch
#'
#' The efficient way to get pass-through for a whole extract. Instead of one
#' request per award, this filters `POST /api/v2/search/spending_by_award/`
#' with `subawards = TRUE` on batches of prime `award_ids` -- measured cap:
#' 500 ids per request succeeds, 1,000 returns HTTP 503; the default batch of
#' 400 leaves headroom. On the 50-org pilot this reduced 61,738 per-award
#' calls to under 200 requests.
#'
#' Three safeguards, all measured:
#' \itemize{
#'   \item **Assistance and contract type codes cannot be mixed.** With
#'     `subawards = TRUE`, the *result* endpoint returns HTTP 422 when
#'     `award_type_codes` spans both families -- while the *count* endpoint
#'     accepts the mix, which makes the failure silent if unhandled. The fetch
#'     therefore runs one pass per family.
#'   \item **The 10k result cap is per filter set.** Each batch is counted
#'     first (`spending_by_award_count`, `subawards = TRUE`); a batch whose
#'     count nears the cap is split recursively, so nothing silently truncates.
#'   \item **FAINs and PIIDs are ambiguous.** `award_ids` matches the bare id,
#'     which different agencies can reuse, so results are filtered back to the
#'     exact `prime_award_generated_internal_id` values in `awards`. Strays are
#'     dropped, not kept.
#' }
#'
#' @param awards The award spine from [us_normalize_awards()], or any
#'   `data.frame` with `award_key` and `award_id` columns.
#' @param batch_size Prime award ids per request (max ~500).
#' @param cap_guard Split a batch when its subaward count exceeds this.
#' @return A `data.table` matching `us_schema("subawards")`, one row per
#'   outbound subaward, with `prime_uei` filled from the spine when available
#'   so [us_normalize_subawards()] can classify direction.
#' @export
#' @examples
#' \dontrun{
#' aw <- us_normalize_awards(tx)
#' out <- us_fetch_subawards_batch(aw)
#' }
us_fetch_subawards_batch <- function(awards, batch_size = 400, cap_guard = 9000) {
  awards <- data.table::as.data.table(awards)
  if (!all(c("award_key", "award_id") %in% names(awards))) {
    us_abort("{.arg awards} needs {.field award_key} and {.field award_id} columns.")
  }
  ids <- unique(awards$award_id[!is.na(awards$award_id)])
  keys <- unique(awards$award_key)
  if (!length(ids)) return(us_empty("subawards"))

  tp <- list(list(start_date = "2007-10-01",
                  end_date = as.character(Sys.Date() + 365)))
  fields <- c("Sub-Award ID", "Sub-Award Amount", "Sub-Award Date",
              "Sub-Awardee Name", "Sub-Awardee UEI", "Prime Award ID",
              "Prime Recipient Name", "prime_award_generated_internal_id",
              "Sub-Award Type")

  count_batch <- function(b, types) {
    r <- us_api_try("search/spending_by_award_count/", body = list(
      filters = list(award_ids = I(b), award_type_codes = I(types), time_period = tp),
      subawards = TRUE))
    if (!r$ok) return(NA_integer_)
    sum(unlist(r$result$results), na.rm = TRUE)
  }
  fetch_batch <- function(b, types) {
    acc <- list(); page <- 1L
    repeat {
      r <- us_api_try("search/spending_by_award/", body = list(
        filters = list(award_ids = I(b), award_type_codes = I(types), time_period = tp),
        fields = I(fields), subawards = TRUE, limit = 100, page = page))
      if (!r$ok || !length(r$result$results)) break
      acc <- c(acc, r$result$results)
      if (!isTRUE(r$result$page_metadata$hasNext) || page >= 100L) break
      page <- page + 1L
    }
    if (!length(acc)) return(NULL)
    data.table::rbindlist(lapply(acc, function(x) data.table::data.table(
      subaward_number      = as_chr(x[["Sub-Award ID"]] %||% NA),
      subaward_amount      = as_num(x[["Sub-Award Amount"]] %||% NA),
      subaward_action_date = as_date(x[["Sub-Award Date"]] %||% NA),
      subawardee_name      = as_chr(x[["Sub-Awardee Name"]] %||% NA),
      subawardee_uei       = clean_uei(x[["Sub-Awardee UEI"]] %||% NA),
      prime_award_id       = as_chr(x[["Prime Award ID"]] %||% NA),
      prime_name           = as_chr(x[["Prime Recipient Name"]] %||% NA),
      prime_award_key      = as_chr(x[["prime_award_generated_internal_id"]] %||% NA),
      subaward_type        = as_chr(x[["Sub-Award Type"]] %||% NA))),
      fill = TRUE)
  }
  run <- function(b, types) {
    n <- count_batch(b, types)
    if (!is.na(n) && n == 0L) return(NULL)
    if ((is.na(n) || n > cap_guard) && length(b) > 1L) {
      h <- ceiling(length(b) / 2)
      ## rbindlist, never rbind: rbind(NULL, NULL, fill = TRUE) falls through
      ## to base rbind, which treats fill as data and returns a 1x1 matrix
      halves <- Filter(function(x) !is.null(x) && nrow(x) > 0L,
                       list(run(b[1:h], types), run(b[(h + 1):length(b)], types)))
      if (!length(halves)) return(NULL)
      return(data.table::rbindlist(halves, fill = TRUE))
    }
    fetch_batch(b, types)
  }

  ## one pass per family: the subaward result endpoint 422s on mixed codes
  fam <- list(assistance = us_award_type_codes("assistance"),
              contract   = c(us_award_type_codes("contract"),
                             us_award_type_codes("idv")))
  batches <- chunk(ids, batch_size)
  us_msg("Fetching outbound subawards: {length(ids)} award id{?s} in {length(batches)} batch{?es} x {length(fam)} famil{?y/ies}.")
  res <- data.table::rbindlist(Filter(Negate(is.null), unlist(
    lapply(fam, function(ty) lapply(batches, run, types = ty)),
    recursive = FALSE)), fill = TRUE)
  if (!nrow(res)) return(us_empty("subawards"))
  ## the same FSRS line can surface in both family passes for parent/child ids
  res <- unique(res)

  n_raw <- nrow(res)
  res <- res[prime_award_key %in% keys]        # drop ambiguous-FAIN strays
  us_msg("{n_raw} row{?s} fetched; {nrow(res)} on the requested award keys.")

  ## shape into the canonical subawards schema
  out <- us_empty("subawards")[seq_len(nrow(res))]
  for (cc in intersect(names(res), names(out))) out[, (cc) := res[[cc]]]
  ## prime_uei from the spine lets us_normalize_subawards() classify direction
  spine <- unique(awards[, c("award_key", "recipient_uei")])
  out[spine, "prime_uei" := i.recipient_uei, on = c(prime_award_key = "award_key")]
  out[, "subaward_year" := calendar_year(subaward_action_date)]
  out[, "subaward_fiscal_year" := fiscal_year(subaward_action_date)]
  out[, "subaward_key" := paste(prime_award_key, subaward_number,
                                format(subaward_action_date), sep = "|")]
  out[, "source_file" := "api:spending_by_award:subawards"]
  out[]
}
