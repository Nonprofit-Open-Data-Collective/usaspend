## Disruption signals on the transaction ledger.
##
## Measured on a 1,000-nonprofit test pull (FY2008-FY2026, 64,255 in-sample
## transactions, data to 2026-09-15), comparing Feb-Aug 2025 with Feb-Aug of
## 2023-2024: formal contract terminations rose from ~1 to 86, but 85% of
## termination notices were $0 actions and most terminated awards were never
## de-obligated inside the window. The observable footprint of disruption is in
## the *non-monetary* fields -- action codes, end-date cuts, ceiling cuts,
## description text -- which is why this layer reads them. See
## vignette("disruption").

## Termination language, and the phrases that merely contain it
DISRUPT_TERM_RX   <- "\\bTERMINAT|\\bT4C\\b|\\bCANCELL?(ED|ATION)\\b"
DISRUPT_TERM_NOT  <- "DETERMINAT|NOT TERMINAT|TERMINATION CLAUSE|FAR 52\\.249"
DISRUPT_RESCIND   <- "RESCIND|REINSTAT|WITHDRAW.{0,20}TERMINAT"
DISRUPT_STOPWORK  <- "STOP[ -]?WORK|SUSPENSION OF WORK|\\bSUSPEND"

#' Flag disruption signals on a transaction ledger
#'
#' Adds one logical column per disruption signal to a canonical transaction
#' table, organized by the four-part taxonomy of `vignette("disruption")`.
#' Flags are per *action*; aggregate them by award, agency, or period to
#' measure disruption. Nothing is dropped or netted.
#'
#' The flags are deliberately literal -- each is one observable property of a
#' single action -- so they can be combined, audited against the description
#' text, and compared against a pre-period baseline. None of them is proof of
#' a policy decision on its own: an end-date cut is routine on a supply order,
#' and closeouts happen every year. Disruption is a *change in the rate* of
#' these actions, which is how the vignette uses them.
#'
#' @section Termination signals:
#' \describe{
#'   \item{`dsr_term_code`}{Contract action type `E` (terminate for default),
#'     `F` (terminate for convenience) or `N` (legal contract cancellation).
#'     Assistance has no termination code.}
#'   \item{`dsr_term_text`}{Termination or cancellation language in
#'     `transaction_description` (excluding "determination" and clause
#'     citations). The only formal termination signal for grants.}
#'   \item{`dsr_rescinded`}{Language rescinding or reinstating a termination.}
#'   \item{`dsr_closeout`}{Contract action type `K` (close out).}
#' }
#' @section Reduction signals:
#' \describe{
#'   \item{`dsr_early_deob`}{Negative obligation dated more than
#'     `early_days` before the scheduled end the action interrupts -- money
#'     withdrawn from a live award, not a post-performance closeout.}
#'   \item{`dsr_end_cut`}{The period-of-performance end moved *earlier* by more
#'     than `cut_days` and by at least a quarter of the remaining schedule.}
#'   \item{`dsr_ceiling_cut`}{Negative `base_and_all_options_value`: the
#'     contract's potential value reduced (contracts only).}
#' }
#' @section Delay signals:
#' \describe{
#'   \item{`dsr_extension`}{End date moved *later* by more than `cut_days`.}
#'   \item{`dsr_stop_work`}{Stop-work or suspension language in the description.}
#'   \item{`dsr_admin`}{A zero-dollar action classed administrative -- the
#'     category stop-work orders and notices are usually filed under.}
#' }
#' Missed or late payments are properties of the *gaps between* actions and of
#' File C outlays, not of any single row; the vignette measures them at the
#' award level.
#' @section Transfer signals:
#' \describe{
#'   \item{`dsr_novation`}{Contract action type `J`: same contract, new vendor.}
#'   \item{`dsr_transfer`}{Contract action type `T` (transfer action), used to
#'     move an award's funds between agencies.}
#'   \item{`dsr_agency_change`}{Awarding agency differs from the award's
#'     previous action -- how an agency closure appears (USAID -> State).}
#'   \item{`dsr_recipient_change`}{Recipient UEI differs from the award's
#'     previous action.}
#' }
#' @section Helper columns:
#' `sched_end` (the end date in force before this action), `end_shift_days`
#' (this action's end date minus that), and `ceiling_change` (the numeric
#' ceiling delta, `NA` for assistance).
#'
#' @param transactions A `data.table` matching `us_schema("transactions")`,
#'   ideally from [us_normalize_transactions()]. The description and ceiling
#'   fields must be present for the text and ceiling flags; extracts
#'   harmonized before those fields existed get `FALSE` there.
#' @param early_days Days before the scheduled end within which a
#'   de-obligation still counts as routine.
#' @param cut_days Minimum end-date move, in days, for a cut or extension.
#' @return The input, ordered by award and action date, with the `dsr_*`
#'   logical columns and the helper columns added.
#' @export
#' @examples
#' tx <- us_normalize_transactions(us_sample_extract()$transactions)
#' f <- us_disruption_flags(tx)
#' f[, lapply(.SD, sum), .SDcols = patterns("^dsr_")]
us_disruption_flags <- function(transactions, early_days = 60L, cut_days = 30L) {
  stopifnot(is.data.frame(transactions))
  need <- c("award_key", "action_date", "federal_action_obligation",
            "pop_end_date", "action_type_code", "award_group")
  miss <- setdiff(need, names(transactions))
  if (length(miss)) us_abort("{.arg transactions} is missing {.val {miss}}.")
  x <- data.table::copy(data.table::as.data.table(transactions))
  for (f in c("transaction_description", "awarding_agency_name", "recipient_uei",
              "action_class")) {
    if (!f %in% names(x)) x[, (f) := NA_character_]
  }
  if (!"base_and_all_options_value" %in% names(x)) x[, "base_and_all_options_value" := NA_real_]
  if (!"modification_number" %in% names(x)) x[, "modification_number" := NA_character_]
  data.table::setorderv(x, c("award_key", "action_date", "modification_number"), na.last = TRUE)

  lg <- function(v) { v[is.na(v)] <- FALSE; v }
  prev <- function(v) data.table::shift(v)
  x[, "sched_end" := data.table::fcoalesce(prev(pop_end_date), pop_end_date), by = award_key]
  x[, "end_shift_days" := as.integer(pop_end_date - prev(pop_end_date)), by = award_key]
  x[, "ceiling_change" := base_and_all_options_value]
  d <- toupper(data.table::fcoalesce(x$transaction_description, ""))
  ct <- x$award_group == "contract"
  code <- x$action_type_code
  amt <- x$federal_action_obligation
  remaining <- pmax(as.numeric(x$sched_end - x$action_date), 0)

  ## 1. termination
  x[, "dsr_term_code" := lg(ct & code %in% c("E", "F", "N"))]
  x[, "dsr_term_text" := grepl(DISRUPT_TERM_RX, d) & !grepl(DISRUPT_TERM_NOT, d)]
  x[, "dsr_rescinded" := grepl(DISRUPT_RESCIND, d)]
  x[, "dsr_closeout"  := lg(ct & code == "K")]
  ## 2. reduction
  x[, "dsr_early_deob"  := lg(amt < 0 & action_date < sched_end - early_days)]
  x[, "dsr_end_cut"     := lg(end_shift_days < -cut_days & -end_shift_days >= 0.25 * remaining)]
  x[, "dsr_ceiling_cut" := lg(ceiling_change < 0)]
  ## 3. delay
  x[, "dsr_extension" := lg(end_shift_days > cut_days)]
  x[, "dsr_stop_work" := grepl(DISRUPT_STOPWORK, d)]
  x[, "dsr_admin"     := lg(amt == 0 & action_class == "administrative")]
  ## 4. transfer
  x[, "dsr_novation" := lg(ct & code == "J")]
  x[, "dsr_transfer" := lg(ct & code == "T")]
  x[, "dsr_agency_change" := lg(awarding_agency_name != prev(awarding_agency_name)), by = award_key]
  x[, "dsr_recipient_change" := lg(recipient_uei != prev(recipient_uei)), by = award_key]
  x[]
}
