## Annual outlays from account-level (File C) data.
##
## The award data has no annual disbursement figure (ACCOUNTING.md 2.4); the
## only place annual outlays exist is the File C records behind
## POST /api/v2/awards/funding/. Everything here was validated against a
## 72-award stratified probe of the VUMC sample, 2026-08-28
## (data-raw/outlay-timing-analysis.R). The headline caveats, all measured:
##
##   * Coverage is gated three ways: era (monthly reporting mandatory only
##     from FY2022; COVID awards from April 2020; quarterly and optional
##     from FY2017), agency (post-FY2022 HHS 98% vs VA contracts 0%, DoD 2%),
##     and linkage (26 of 72 probed FY2017+ awards had no File C rows at all;
##     only 35 of 72 had File C obligations reconciling with their own award
##     transactions).
##   * Where both series exist, within-year obligations do NOT track
##     within-year outlays: obligations put a median 90% of an award's
##     dollars in its first fiscal year, outlays 2%; cash lags commitment by
##     roughly one year. Outlays are a separate measure, never a substitute.

#' Fetch account-level (File C) funding history per award
#'
#' Walks `POST /api/v2/awards/funding/` for each award: one row per federal
#' account x object class x program activity x reporting period, carrying the
#' two account-level money fields. This is the **only** source of annual
#' outlays -- the award data itself is lifetime-only (see [us_money_column()]).
#'
#' @section The two money columns are on different bases:
#' `transaction_obligated_amount` is **incremental** per period.
#' `gross_outlay_amount` is **cumulative within each fiscal year** per account
#' cell (File C reports it as of period end, resetting at the fiscal year
#' boundary). Summing it across periods double-counts; [us_outlays_by_year()]
#' applies the correct last-period-per-year rule.
#'
#' @section Failures are not empty results:
#' An award whose request errors is recorded in the `usaspend_failed`
#' attribute and warned about -- it must not be read as "this award has no
#' File C data". Awards that genuinely return zero records are simply absent
#' from the result.
#'
#' @param award_key Character vector of generated unique award ids.
#' @param page_limit Records per page (API maximum 100).
#' @return A `data.table` matching `us_schema("funding")`, with a
#'   `usaspend_failed` attribute naming awards whose fetch errored.
#' @export
#' @examples
#' \dontrun{
#' fc <- us_fetch_outlays("ASST_NON_NU2GGH002367_075")
#' us_outlays_by_year(fc)
#' }
us_fetch_outlays <- function(award_key, page_limit = 100) {
  award_key <- unique(as_chr(award_key))
  award_key <- award_key[!is.na(award_key)]
  if (!length(award_key)) return(us_empty("funding"))

  failed <- character(0)
  one <- function(k) {
    res <- tryCatch(
      us_api_pages("awards/funding/",
                   body = list(award_id = k, sort = "reporting_fiscal_date",
                               order = "asc"),
                   limit = page_limit),
      error = function(e) {
        cli::cli_warn("Funding fetch failed for {.val {k}}: {conditionMessage(e)}")
        failed <<- c(failed, k)
        NULL
      })
    if (!length(res)) return(NULL)
    dt <- rows_to_dt(res)
    grab <- function(nm) if (nm %in% names(dt)) dt[[nm]] else NA
    data.table::data.table(
      award_key                    = k,
      reporting_fiscal_year        = as_int(grab("reporting_fiscal_year")),
      reporting_fiscal_quarter     = as_int(grab("reporting_fiscal_quarter")),
      reporting_fiscal_month       = as_int(grab("reporting_fiscal_month")),
      is_quarterly_submission      = as.logical(grab("is_quarterly_submission")),
      federal_account              = as_chr(grab("federal_account")),
      account_title                = as_chr(grab("account_title")),
      disaster_emergency_fund_code = as_chr(grab("disaster_emergency_fund_code")),
      object_class                 = as_chr(grab("object_class")),
      object_class_name            = as_chr(grab("object_class_name")),
      program_activity_code        = as_chr(grab("program_activity_code")),
      program_activity_name        = as_chr(grab("program_activity_name")),
      funding_agency_id            = as_chr(grab("funding_agency_id")),
      funding_agency_name          = as_chr(grab("funding_agency_name")),
      transaction_obligated_amount = as_num(grab("transaction_obligated_amount")),
      gross_outlay_amount          = as_num(grab("gross_outlay_amount")))
  }
  out <- data.table::rbindlist(
    Filter(Negate(is.null), lapply(award_key, one)), fill = TRUE)
  if (!nrow(out)) out <- us_empty("funding")
  n_with <- data.table::uniqueN(out$award_key)
  us_msg(c("Fetched File C funding for {length(award_key)} award{?s}.",
           "*" = "{n_with} award{?s} have account-level records, {length(award_key) - n_with - length(failed)} have none, {length(failed)} failed"))
  data.table::setattr(out, "usaspend_failed", failed)
  out[]
}

#' Collapse File C funding records to annual outlays per award
#'
#' Turns the period-level funding table into one row per award x federal
#' fiscal year, applying the cumulative-within-year rule that
#' `gross_outlay_amount` requires: within each account cell (federal account x
#' DEFC x object class x program activity x funding agency) the annual outlay
#' is the **last reported value** of the fiscal year, and the award-year
#' outlay is the sum over cells. `transaction_obligated_amount` is
#' incremental, so it sums directly; it is returned as `filec_obligation` so
#' the caller can check File C against the award's own transaction ledger --
#' the linkage screen [us_add_outlays()] runs per award.
#'
#' Years are **federal fiscal years**; File C has no calendar-year form.
#'
#' @param funding A `data.table` matching `us_schema("funding")`, from
#'   [us_fetch_outlays()].
#' @return A `data.table` of `award_key`, `fiscal_year`, `outlay`
#'   (NA when the award-year reported no outlay rows, never a fake zero),
#'   `filec_obligation`, and `n_periods`.
#' @export
us_outlays_by_year <- function(funding) {
  stopifnot(is.data.frame(funding))
  need <- c("award_key", "reporting_fiscal_year", "reporting_fiscal_month",
            "gross_outlay_amount", "transaction_obligated_amount")
  missing <- setdiff(need, names(funding))
  if (length(missing)) {
    us_abort(c("{.arg funding} is missing {.val {missing}}.",
               "i" = "Pass the output of {.fn us_fetch_outlays}."))
  }
  x <- data.table::copy(data.table::as.data.table(funding))
  if (!nrow(x)) {
    return(data.table::data.table(award_key = character(0), fiscal_year = integer(0),
                                  outlay = numeric(0), filec_obligation = numeric(0),
                                  n_periods = integer(0)))
  }
  cellcols <- intersect(c("federal_account", "disaster_emergency_fund_code",
                          "object_class", "program_activity_code",
                          "funding_agency_id"), names(x))
  for (cc in cellcols) x[is.na(get(cc)), (cc) := ""]

  ol <- x[!is.na(gross_outlay_amount)]
  data.table::setorderv(ol, c("award_key", cellcols,
                              "reporting_fiscal_year", "reporting_fiscal_month"),
                        na.last = TRUE)
  ## last cumulative value per cell per fiscal year, then sum the cells
  ol <- ol[, .(outlay = data.table::last(gross_outlay_amount)),
           by = c("award_key", cellcols, "reporting_fiscal_year")]
  ol <- ol[, .(outlay = sum(outlay)),
           by = .(award_key, fiscal_year = reporting_fiscal_year)]

  ob <- x[!is.na(transaction_obligated_amount),
          .(filec_obligation = sum(transaction_obligated_amount)),
          by = .(award_key, fiscal_year = reporting_fiscal_year)]
  np <- x[, .(n_periods = data.table::uniqueN(
                paste(reporting_fiscal_year, reporting_fiscal_month))),
          by = .(award_key, fiscal_year = reporting_fiscal_year)]

  out <- Reduce(function(a, b) merge(a, b, by = c("award_key", "fiscal_year"), all = TRUE),
                list(ol, ob, np))
  out[is.na(filec_obligation), "filec_obligation" := 0]
  data.table::setorderv(out, c("award_key", "fiscal_year"))
  out[]
}

#' Attach annual outlays to a panel
#'
#' Adds a cash layer to a fiscal-year panel: `outlay_amount` per
#' org-award-year plus a per-award `outlay_coverage` grade, leaving
#' `obligation_net` and `net_revenue` untouched -- outlays are a *separate
#' measure* of the same award, never a substitute (measured on VUMC FY2022+
#' awards, two-thirds of an award's dollars land in a different year under
#' outlays than under obligations, and cash lags commitment by about a year).
#'
#' @section Coverage grades, one per award:
#' \describe{
#'   \item{`"complete"`}{First panel activity FY2022+ (inside the monthly
#'     reporting mandate), File C obligations reconcile with the award's own
#'     transactions, outlay rows present.}
#'   \item{`"truncated_pre_FY2022"`}{Linked and reporting, but the award
#'     predates the FY2022 mandate: pre-mandate outlays were never reported,
#'     so early years are `NA` and the lifetime sum is a floor.}
#'   \item{`"unlinked"`}{File C obligations differ from the award's
#'     transaction ledger by more than `tolerance` -- the outlay values
#'     describe money that cannot be reconciled to this award. Kept, flagged.}
#'   \item{`"no_outlay_rows"`}{File C records exist but none carry an outlay
#'     (typical for pre-mandate-only reporters). All `outlay_amount` is `NA`.}
#'   \item{`"no_file_c"`}{The endpoint returned no records at all (VA and DoD
#'     portfolios, mostly). All `NA`.}
#'   \item{`"fetch_failed"`}{The request errored. All `NA` -- a failure is
#'     never read as an empty result.}
#' }
#'
#' @section Zero versus NA:
#' `outlay_amount` is `0` only where a zero was plausibly *measured*: years
#' inside the award's reporting window (FY2022+, or any year with File C
#' outlay rows) for awards that report outlays. Years before the mandate and
#' awards with no outlay reporting are `NA`, so a missing measurement is
#' never mistaken for "no cash moved".
#'
#' @section Trailing cash years:
#' Outlays lag obligations, so an award's cash routinely arrives after its
#' last obligation year -- years the panel has no row for. With `fill_gaps =
#' TRUE` (the default, unlike [us_panel()] where trailing years are the
#' exception) those years get zero-obligation rows flagged
#' `"outlay_only_year"`, attributed to the award's dominant organization.
#' With `fill_gaps = FALSE` those outlay dollars are dropped and a message
#' reports how much.
#'
#' @param panel A `usaspend_panel` built with `period = "fiscal"` -- File C
#'   reports federal fiscal periods and has no calendar-year form.
#' @param funding Optional prefetched funding table from
#'   [us_fetch_outlays()]; when `NULL`, funding is fetched for every award in
#'   the panel (one paged request per award).
#' @param fill_gaps Add zero-obligation rows for outlay-years the panel does
#'   not cover.
#' @param tolerance Linkage screen: relative gap between File C lifetime
#'   obligations and the award's own allowed before the award is graded
#'   `"unlinked"`.
#' @return The panel with `outlay_amount` and `outlay_coverage` columns, a new
#'   `outlays` element (the award x fiscal-year table from
#'   [us_outlays_by_year()]), and `meta$outlays` recording the coverage tally.
#' @export
#' @examples
#' \dontrun{
#' p <- us_panel(ex, period = "fiscal")
#' p <- us_add_outlays(p)
#' p$panel[outlay_coverage == "complete",
#'         .(oblig = sum(obligation_net), cash = sum(outlay_amount)), by = year]
#' }
us_add_outlays <- function(panel, funding = NULL, fill_gaps = TRUE,
                           tolerance = 0.25) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  if (!identical(panel$meta$period, "fiscal")) {
    us_abort(c("File C outlays are reported by federal fiscal period.",
               "x" = "This panel uses {.val {panel$meta$period}} years.",
               "i" = "Rebuild with {.code us_panel(extract, period = \"fiscal\")} before attaching outlays."))
  }
  stopifnot(is.logical(fill_gaps), length(fill_gaps) == 1L,
            is.numeric(tolerance), length(tolerance) == 1L, tolerance > 0)
  p <- data.table::copy(panel$panel)
  keys <- unique(p$award_key)

  if (is.null(funding)) {
    funding <- us_fetch_outlays(keys)
  } else {
    stopifnot(is.data.frame(funding))
  }
  failed <- attr(funding, "usaspend_failed") %||% character(0)
  ann <- us_outlays_by_year(funding)
  ann <- ann[award_key %in% keys]

  ## ---- per-award coverage grade -------------------------------------------
  life <- p[, .(oblig = sum(obligation_net), first_year = min(year)), by = award_key]
  fc <- ann[, .(filec = sum(filec_obligation),
                has_outlay_rows = any(!is.na(outlay))), by = award_key]
  cov <- merge(life, fc, by = "award_key", all.x = TRUE)
  cov[is.na(has_outlay_rows), "has_outlay_rows" := FALSE]
  cov[, "outlay_coverage" := data.table::fcase(
        award_key %in% failed,                          "fetch_failed",
        is.na(filec),                                   "no_file_c",
        !has_outlay_rows,                               "no_outlay_rows",
        abs(filec - oblig) > pmax(tolerance * abs(oblig), 1000), "unlinked",
        first_year < 2022L,                             "truncated_pre_FY2022",
        default = "complete")]

  ## ---- join measured outlays ----------------------------------------------
  p <- merge(p, ann[!is.na(outlay),
                    .(award_key, year = fiscal_year, outlay_amount = outlay)],
             by = c("award_key", "year"), all.x = TRUE)

  ## a multi-recipient award-year would receive the same outlay on every org
  ## row; keep it on the row with the dominant activity, as us_panel() does
  ## for subawards, so sum(outlay_amount) equals the dollars fetched
  p[, "n_org_rows" := .N, by = .(award_key, year)]
  if (any(p$n_org_rows > 1L & !is.na(p$outlay_amount))) {
    data.table::setorderv(p, c("award_key", "year"))
    p[n_org_rows > 1L & !is.na(outlay_amount), "outlay_amount" := {
        keep <- which.max(abs(obligation_net) + n_transactions / 1e9)
        outlay_amount * (seq_len(.N) == keep)
      }, by = .(award_key, year)]
  }
  p[, "n_org_rows" := NULL]

  p <- merge(p, cov[, c("award_key", "outlay_coverage")], by = "award_key", all.x = TRUE)

  ## measured zeros only inside the award's reporting window
  reporting <- p$outlay_coverage %in% c("complete", "truncated_pre_FY2022", "unlinked")
  p[reporting & is.na(outlay_amount) & year >= 2022L, "outlay_amount" := 0]

  ## ---- trailing cash years the panel has no row for -----------------------
  orphan <- ann[!is.na(outlay)][!p, on = c("award_key", fiscal_year = "year")]
  orphan_dollars <- sum(orphan$outlay)
  if (nrow(orphan) && fill_gaps) {
    ## attribute to the award's dominant organization: its most active panel
    ## row supplies the org and the award attributes, the orphan supplies the
    ## year and the outlay, everything else is zero
    dom <- p[order(-abs(obligation_net), -n_transactions), .SD[1L], by = award_key]
    dom[, c("year", "outlay_amount") := NULL]
    add <- merge(orphan[, .(award_key, year = fiscal_year, outlay_amount = outlay)],
                 dom, by = "award_key")
    zero_num <- c("n_actions_positive", "n_actions_negative",
                  "obligation_positive", "obligation_negative", "obligation_net",
                  "deobligation_prior_year", "loan_face_value", "loan_subsidy_cost",
                  "subaward_out_amount", "subaward_in_amount", "net_revenue")
    zero_int <- c("n_transactions", "n_subawards_out", "n_subawards_in")
    for (cc in intersect(zero_num, names(add))) add[, (cc) := 0]
    for (cc in intersect(zero_int, names(add))) add[, (cc) := 0L]
    add[, "flags" := "outlay_only_year"]
    add <- add[, names(p), with = FALSE]
    p <- data.table::rbindlist(list(p, add), use.names = TRUE)
    us_msg("Added {nrow(add)} outlay-only year{?s} (${prettyNum(round(orphan_dollars / 1e6, 1), big.mark = ',')}M of trailing cash).")
  } else if (nrow(orphan)) {
    us_msg("Dropping {nrow(orphan)} outlay-year{?s} outside the panel (${prettyNum(round(orphan_dollars / 1e6, 1), big.mark = ',')}M); use {.code fill_gaps = TRUE} to keep them.")
  }

  data.table::setorderv(p, c("org_id", "award_key", "year"))
  tally <- table(cov$outlay_coverage)
  us_msg(c("Outlay coverage across {nrow(cov)} award{?s}:",
           "*" = "{paste0(names(tally), '=', as.integer(tally), collapse = ' ')}"))

  panel$panel <- p[]
  panel$outlays <- ann
  panel$meta$outlays <- list(fetched_at = Sys.time(),
                             coverage = tally,
                             fill_gaps = fill_gaps,
                             tolerance = tolerance)
  panel
}
