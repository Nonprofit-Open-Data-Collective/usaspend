#' Plan an extraction before running it
#'
#' Compares the two acquisition paths for a given input and recommends one. The
#' API path costs time proportional to the number of UEIs; the archive path
#' costs a fixed volume proportional to the number of fiscal years. They cross
#' over somewhere in the low thousands of UEIs.
#'
#' The estimates are order-of-magnitude, built from measured constants:
#' a bulk-download job took 9-85 seconds server-side, `recipient_search_text`
#' caps near 20 values (and large recipients fail well below that, hence a
#' default batch of 5), and `FY2024_All_Assistance_Full` is 1.37 GB compressed.
#'
#' @param uei Character vector of UEIs.
#' @param years Integer vector of fiscal years to cover.
#' @param batch_size,concurrent Overrides for the API-path cost model.
#' @param mbps Assumed sustained download throughput, for the archive path.
#' @return A `data.table` comparing the paths, invisibly; the recommendation is
#'   printed and returned in the `recommended` attribute.
#' @export
#' @examples
#' us_extract_plan(rep("CFFMYPABYAG3", 40), years = 2015:2025)
us_extract_plan <- function(uei, years = 2008:2025,
                            batch_size = us_opt("batch_size"),
                            concurrent = us_opt("concurrent"),
                            mbps = 25) {
  n_uei <- length(unique(us_validate_uei(uei, strict = FALSE)))
  n_yr  <- length(years)

  ## API path: jobs run ~60s server-side, `concurrent` at a time. Allow 20% of
  ## batches to fail and be retried one UEI at a time -- the measured behaviour.
  n_jobs  <- ceiling(n_uei / batch_size)
  n_retry <- ceiling(0.20 * n_jobs) * batch_size
  api_min <- (n_jobs + n_retry) * 60 / concurrent / 60

  ## Archive path: two archives per fiscal year, ~1.4 GB each, plus a duckdb
  ## scan of the unpacked CSVs at roughly 1 GB/min.
  n_arch  <- n_yr * 2
  arch_gb <- n_arch * 1.4
  arch_min <- arch_gb * 1000 / mbps / 60 + arch_gb * 4

  out <- data.table::data.table(
    path = c("api", "archive"),
    unit = c(sprintf("%d download jobs (+%d single-UEI retries)", n_jobs, n_retry),
             sprintf("%d annual archives", n_arch)),
    download_gb = c(round(n_uei * 0.002, 2), round(arch_gb, 1)),
    est_minutes = round(c(api_min, arch_min)),
    disk_gb = c(round(n_uei * 0.01, 2), round(arch_gb * 4, 0)))

  rec <- if (api_min <= arch_min) "api" else "archive"
  ## api_min = n_uei * 1.2 / (batch_size * concurrent); solve for the n_uei at
  ## which that equals the archive path's fixed cost
  cross <- ceiling(arch_min * batch_size * concurrent / 1.2)
  us_msg(c("Recommended path: {.strong {rec}}.",
           "i" = "Crossover for {n_yr} fiscal year{?s} is around {cross} UEIs.",
           "i" = "Subawards paid out are NOT in the annual archives and always cost extra API calls -- see {.fn us_fetch_subawards_out}."))
  data.table::setattr(out, "recommended", rec)
  out[]
}

#' Extract raw award data for a set of UEIs
#'
#' The single entry point for acquisition. Both paths return the same canonical
#' tables, so downstream normalization does not know or care which was used.
#'
#' \describe{
#'   \item{`"api"`}{Submits bulk-download jobs to
#'     `POST /api/v2/download/transactions/`. Right for one organization or a
#'     small batch. Returns prime transactions and, as a by-product, subawards
#'     where the queried UEI is the *subawardee*.}
#'   \item{`"archive"`}{Downloads the annual Award Data Archive files and
#'     filters them locally with duckdb. Right for large batches: the cost is
#'     fixed in the number of fiscal years rather than the number of
#'     recipients. Prime transactions only -- there is no bulk subaward file.}
#'   \item{`"auto"`}{Picks whichever [us_extract_plan()] estimates as cheaper.}
#' }
#'
#' Subawards *paid out* -- the pass-through figure needed to compute net
#' revenue -- are not available from either bulk path. Set `subawards = "out"`
#' to walk the resulting award keys through [us_fetch_subawards_out()], which
#' costs roughly one extra API call per award and is screened so that awards
#' reporting no subawards are skipped.
#'
#' @param uei Character vector of UEIs.
#' @param years Integer vector of fiscal years.
#' @param award_types Award type codes; defaults to all.
#' @param source `"auto"`, `"api"`, or `"archive"`.
#' @param subawards `"none"`, `"in"` (subawards received: free by-product on
#'   the API path; on the archive path appended via [us_fetch_subawards_in()],
#'   which count-screens each UEI batch and fetches only where inbound rows
#'   exist), `"out"` (pass-through paid: queried by prime award from either
#'   path), or `"both"`.
#' @param dest Directory for intermediate files. Defaults to the package cache.
#' @return A list of class `usaspend_extract` with elements `transactions`,
#'   `subawards`, `jobs` (the acquisition manifest) and `meta`.
#' @export
#' @examples
#' \dontrun{
#' # one organization, the API path
#' ex <- us_extract("CFFMYPABYAG3", years = 2015:2025)
#'
#' # a batch, using the annual archives, with pass-through subawards
#' ueis <- readLines("TOP1000-UEIS.txt")
#' ex <- us_extract(ueis, years = 2008:2025, source = "archive", subawards = "out")
#' }
us_extract <- function(uei,
                       years = 2008:2025,
                       award_types = us_award_type_codes("all"),
                       source = c("auto", "api", "archive"),
                       subawards = c("in", "none", "out", "both"),
                       dest = us_cache_dir("raw")) {
  source <- match.arg(source)
  subawards <- match.arg(subawards)
  uei <- unique(us_validate_uei(uei))
  uei <- uei[!is.na(uei)]
  if (!length(uei)) us_abort("No valid UEIs supplied.")

  if (source == "auto") {
    plan <- us_extract_plan(uei, years)
    source <- attr(plan, "recommended")
  }

  start_date <- sprintf("%d-10-01", min(years) - 1L)
  end_date   <- sprintf("%d-09-30", max(years))

  if (source == "api") {
    jobs <- us_download_run(uei, award_types, start_date, end_date)
    us_download_fetch(jobs, dest = dest)
    parts <- read_download_dir(dest)
    tx <- parts$transactions
    sb <- parts$subawards
  } else {
    man <- us_archive_manifest(fiscal_year = years)
    man <- us_archive_download(man)
    jobs <- man
    tx <- data.table::rbindlist(lapply(seq_len(nrow(man)), function(i) {
      grp <- if (identical(man$type[i], "contracts")) "contract" else "assistance"
      us_archive_filter(uei, man$csv_dir[i], group = grp)
    }), use.names = TRUE, fill = TRUE)
    sb <- us_empty("subawards")
    if (subawards %in% c("in", "both")) {
      ## The archives carry no subawards at all; the search route count-screens
      ## each UEI batch so orgs with no inbound rows cost one cheap request.
      sb <- us_fetch_subawards_in(uei, years, dest = dest)
    }
  }

  if (nrow(tx) && subawards %in% c("out", "both")) {
    keys <- unique(tx$award_key[!is.na(tx$award_key)])
    us_msg("Fetching pass-through subawards for {length(keys)} award{?s}.")
    out <- us_fetch_subawards_out(keys)
    if (nrow(out)) {
      out[, "direction" := "out"]
      sb <- data.table::rbindlist(list(sb, out), use.names = TRUE, fill = TRUE)
    }
  }

  structure(list(
    transactions = tx,
    subawards    = sb,
    jobs         = jobs,
    meta = list(uei = uei, years = years, award_types = award_types,
                source = source, subawards = subawards,
                extracted_at = Sys.time())
  ), class = "usaspend_extract")
}

#' @export
print.usaspend_extract <- function(x, ...) {
  m <- x$meta
  cli::cli_h1("usaspend extract")
  cli::cli_bullets(c(
    "*" = "{length(m$uei)} UEI{?s}, FY{min(m$years)}-FY{max(m$years)}, path {.val {m$source}}",
    "*" = "{nrow(x$transactions)} transaction{?s} on {length(unique(x$transactions$award_key))} award{?s}",
    "*" = "{nrow(x$subawards)} subaward row{?s}",
    "*" = "extracted {format(m$extracted_at, '%Y-%m-%d %H:%M')}"))
  invisible(x)
}

## us_fetch_subawards_in() lives in api-search.R with the rest of the
## subaward-search machinery; its "download" route uses the job functions here.
