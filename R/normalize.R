## Normalization: raw canonical transactions -> a clean ledger.
##
## Every rule here was validated against the 50-nonprofit pilot extract
## (302,025 prime transactions, 39,243 subaward rows, pulled 2026-08-27).
## Where the pilot settled a question, the measured number is in the comment.

#' Normalize a raw transaction ledger
#'
#' Turns harmonized-but-raw transactions into a clean ledger, one row per real
#' award action, ready for aggregation.
#'
#' @section What it does:
#' \enumerate{
#'   \item **De-duplicates on `transaction_key`.** Overlapping download batches
#'     produce exact duplicates. In the pilot, 19,445 of 241,118 assistance rows
#'     (8.1%) and 1,383 of 60,907 contract rows (2.3%) were duplicates, and
#'     every single one was a byte-identical copy -- same amount, same
#'     `last_modified_date`. De-duplicating recovered 5,754 awards that had
#'     previously failed the lifetime reconciliation check.
#'   \item **Drops deleted records.** `correction_delete_code == "D"` means the
#'     record was withdrawn. Note that `"C"` does *not* mean "superseded by
#'     something else" -- it means this row is itself the correction, and it is
#'     the current version, so it is kept. 37.6% of pilot assistance rows carry
#'     `"C"`. A pipeline that drops them would discard a third of the data.
#'     `"L"` is an undocumented legacy value; in the pilot all 1,719 instances
#'     are Department of Energy records dated 2008-2017. They are kept and
#'     flagged.
#'   \item **Drops aggregate records** (`record_type_code == 1`), which are
#'     county-level rollups with no identified recipient and would double-count.
#'   \item **Keeps zero-dollar actions, flagged.** They are 20% of pilot
#'     assistance transactions and 30% of contract transactions. They carry
#'     period-of-performance changes and are how activity is counted.
#'   \item **Flags anomalies** rather than silently repairing them.
#' }
#'
#' @param transactions A `data.table` matching `us_schema("transactions")`.
#' @param requested_uei Optional character vector of the UEIs actually asked
#'   for, used to flag strays returned by the API's text matching.
#' @param drop_aggregates Drop assistance `record_type_code` 1.
#' @return A `data.table` matching `us_schema("transactions")` plus
#'   `is_zero_dollar`, `is_deobligation`, `is_stray_uei`, `is_legacy_cdi` and a
#'   character `flags` column. Carries a `usaspend_dropped` attribute recording
#'   what was removed and why.
#' @export
#' @examples
#' tx <- us_normalize_transactions(us_sample_extract()$transactions)
#' attr(tx, "usaspend_dropped")
us_normalize_transactions <- function(transactions,
                                      requested_uei = NULL,
                                      drop_aggregates = TRUE) {
  stopifnot(is.data.frame(transactions))
  missing <- setdiff(us_schema("transactions")$field, names(transactions))
  if (length(missing)) {
    us_abort(c("{.arg transactions} is missing {length(missing)} canonical column{?s}.",
               "x" = "{.val {utils::head(missing, 8)}}",
               "i" = "Pass the output of {.fn us_harmonize_transactions}."))
  }
  if (!is.null(requested_uei)) requested_uei <- us_validate_uei(requested_uei)
  stopifnot(is.logical(drop_aggregates), length(drop_aggregates) == 1L)

  x <- data.table::copy(data.table::as.data.table(transactions))
  n0 <- nrow(x)
  dropped <- list()

  ## -- 1. deleted records ----------------------------------------------------
  n_del <- sum(!is.na(x$correction_delete_code) & x$correction_delete_code == "D")
  if (n_del) x <- x[is.na(correction_delete_code) | correction_delete_code != "D"]
  dropped$deleted <- n_del

  ## -- 2. aggregate records --------------------------------------------------
  n_agg <- sum(!is.na(x$record_type_code) & x$record_type_code == "1")
  if (drop_aggregates && n_agg) x <- x[is.na(record_type_code) | record_type_code != "1"]
  dropped$aggregate <- if (drop_aggregates) n_agg else 0L

  ## -- 3. de-duplicate -------------------------------------------------------
  ## Order by last_modified_date descending so the surviving row is the most
  ## recently revised one. Rows with no transaction key cannot be de-duplicated
  ## and are kept as-is rather than collapsed to a single NA row.
  keyed <- !is.na(x$transaction_key)
  dk <- x[keyed]
  du <- x[!keyed]
  n_before <- nrow(dk)
  if (n_before) {
    data.table::setorderv(dk, c("transaction_key", "last_modified_date"),
                          order = c(1L, -1L), na.last = TRUE)
    dk <- unique(dk, by = "transaction_key")
  }
  dropped$duplicate <- n_before - nrow(dk)
  x <- data.table::rbindlist(list(dk, du), use.names = TRUE)

  ## -- 4. flags --------------------------------------------------------------
  x[, "is_zero_dollar"  := !is.na(federal_action_obligation) & federal_action_obligation == 0]
  x[, "is_deobligation" := !is.na(federal_action_obligation) & federal_action_obligation < 0]
  x[, "is_legacy_cdi"   := !is.na(correction_delete_code) &
                            !correction_delete_code %in% c("C", "D")]
  x[, "is_stray_uei"    := if (is.null(requested_uei)) FALSE
                           else !recipient_uei %in% requested_uei]

  flag <- function(cond, label) {
    cond[is.na(cond)] <- FALSE
    data.table::fifelse(cond, label, "")
  }
  x[, "flags" := trimws(paste(
      flag(x$is_stray_uei, "stray_uei"),
      flag(x$is_legacy_cdi, "legacy_cdi"),
      ## a purely administrative action should not move money
      flag(x$action_class == "administrative" & x$federal_action_obligation != 0,
           "money_on_admin_action"),
      ## an action dated outside its own award's period of performance
      flag(!is.na(x$pop_end_date) & !is.na(x$action_date) &
             x$action_date > x$pop_end_date + 365, "action_after_pop"),
      ## impossible given the award-search floor
      flag(!is.na(x$action_date) & x$action_date < as.Date("2007-10-01"),
           "before_search_floor"),
      flag(is.na(x$action_date), "no_action_date"),
      flag(is.na(x$award_key), "no_award_key")))]
  x[, "flags" := gsub("\\s+", ";", flags)]

  dropped$kept <- nrow(x)
  dropped$input <- n0
  data.table::setattr(x, "usaspend_dropped", dropped)
  us_msg(c("Normalized {n0} -> {nrow(x)} transaction{?s}.",
           "*" = "{dropped$duplicate} duplicate{?s}, {dropped$deleted} deleted, {dropped$aggregate} aggregate record{?s}",
           "*" = "{sum(x$flags != '')} row{?s} flagged"))
  x[]
}

#' Normalize a subaward ledger and assign direction
#'
#' @section Direction is the whole point:
#' A bulk download filtered on `recipient_search_text` returns subawards where
#' the queried UEI is the **subawardee**, not the prime. Measured on the
#' 50-nonprofit pilot: of 39,243 subaward rows, **zero** had a prime outside the
#' pilot paying a subawardee outside it, and zero had a pilot org as prime
#' paying someone outside. Every row was matched on the subawardee.
#'
#' So `direction == "in"` rows arrive for free and are *additional revenue* not
#' visible in prime data. `direction == "out"` rows -- the pass-through that must
#' be netted out of revenue -- have to be fetched separately with
#' [us_fetch_subawards_out()].
#'
#' @section Other rules:
#' \enumerate{
#'   \item De-duplicates on `subaward_key`, keeping the latest
#'     `report_last_modified`. FSRS reports are restated month to month.
#'   \item Books on `subaward_action_date` by default. Report dates lag, in the
#'     pilot sometimes across a fiscal year boundary.
#'   \item Rows where the organization is both prime and subawardee are
#'     labelled `"internal"` and excluded from both flows, so that money moving
#'     between two UEIs of the same organization is not counted as revenue or as
#'     pass-through.
#' }
#'
#' @param subawards A `data.table` matching `us_schema("subawards")`.
#' @param org_uei Character vector of UEIs belonging to the organizations of
#'   interest.
#' @param year_basis `"action"` (default) or `"report"`.
#' @return A `data.table` matching `us_schema("subawards")` with `direction`
#'   populated as `"in"`, `"out"`, `"internal"` or `"unrelated"`.
#' @export
us_normalize_subawards <- function(subawards, org_uei,
                                   year_basis = c("action", "report")) {
  stopifnot(is.data.frame(subawards))
  year_basis <- match.arg(year_basis)
  org_uei <- us_validate_uei(org_uei)
  missing <- setdiff(c("prime_uei", "subawardee_uei", "subaward_amount",
                       "subaward_action_date", "subaward_key"), names(subawards))
  if (length(missing)) {
    us_abort(c("{.arg subawards} is missing {.val {missing}}.",
               "i" = "Pass the output of {.fn us_harmonize_subawards}."))
  }
  x <- data.table::copy(data.table::as.data.table(subawards))
  n0 <- nrow(x)

  keyed <- !is.na(x$subaward_key)
  dk <- x[keyed]; du <- x[!keyed]
  if (nrow(dk)) {
    data.table::setorderv(dk, c("subaward_key", "report_last_modified"),
                          order = c(1L, -1L), na.last = TRUE)
    dk <- unique(dk, by = "subaward_key")
  }
  n_dup <- sum(keyed) - nrow(dk)
  x <- data.table::rbindlist(list(dk, du), use.names = TRUE)

  p_in <- !is.na(x$prime_uei)      & x$prime_uei      %in% org_uei
  s_in <- !is.na(x$subawardee_uei) & x$subawardee_uei %in% org_uei
  x[, "direction" := data.table::fcase(
      p_in & s_in, "internal",
      p_in,        "out",
      s_in,        "in",
      default =    "unrelated")]

  if (year_basis == "report") {
    x[, c("subaward_year", "subaward_fiscal_year") :=
        list(report_year, report_year)]
  } else {
    x[, c("subaward_year", "subaward_fiscal_year") :=
        list(calendar_year(subaward_action_date), fiscal_year(subaward_action_date))]
  }

  tally <- table(x$direction)
  us_msg(c("Normalized {n0} -> {nrow(x)} subaward row{?s} ({n_dup} duplicate{?s} removed).",
           "*" = "{paste0(names(tally), '=', as.integer(tally), collapse = ' ')}"))
  if (!"out" %in% names(tally)) {
    cli::cli_warn(c("No outbound subawards present -- pass-through cannot be netted out.",
                    "i" = "Bulk downloads match on the subawardee. Use {.fn us_fetch_subawards_out} to fetch pass-through by prime award."))
  }
  x[]
}

#' Build the prime award spine
#'
#' Collapses the transaction ledger to one row per award, taking each
#' award-level field from the latest action that actually reports one.
#'
#' @section Why "latest non-missing" and not "any row":
#' Award-level columns are sparse across transactions. In the pilot,
#' `total_dollars_obligated` and `current_total_value_of_award` are blank on
#' most contract modification rows and populated on others; taking an arbitrary
#' row gives an arbitrary answer.
#'
#' @section An award is not owned by one organization:
#' Award keys are shared. NIH research grants follow the principal investigator
#' between institutions, so a single `award_key` can carry transactions for
#' several recipients over its life. In a 28-award pilot audit, 11 awards
#' present in the extract had a *current* recipient that was not a pilot
#' organization at all -- the pilot org held only part of the award's history.
#' This is why the panel grain is organization x award x year and not award x
#' year, and why `n_recipients > 1` is worth inspecting.
#'
#' @param transactions A normalized ledger from [us_normalize_transactions()].
#' @param enrich Call [us_fetch_award()] per award to add `subaward_count` and
#'   `subaward_total`. Costs one API request per award.
#' @param rollup_idv Attribute delivery-order obligations to the parent IDV.
#' @return A `data.table` matching `us_schema("awards")`, plus `n_recipients`.
#' @export
us_normalize_awards <- function(transactions, enrich = FALSE, rollup_idv = FALSE) {
  stopifnot(is.data.frame(transactions))
  stopifnot(is.logical(enrich), is.logical(rollup_idv))
  x <- data.table::as.data.table(transactions)
  if (!nrow(x)) return(us_empty("awards"))

  ## rows are ordered by action_date within award, so "latest non-missing"
  ## is simply the last non-NA value in each group
  data.table::setorderv(x, c("award_key", "action_date"), na.last = TRUE)
  lastval <- function(v) {
    ok <- which(!is.na(v))
    ## v[NA_integer_] keeps the column's own type; a bare NA is logical and
    ## makes data.table refuse to combine groups
    if (!length(ok)) v[NA_integer_] else v[ok[length(ok)]]
  }

  aw <- x[, .(
    award_group              = lastval(award_group),
    award_family             = lastval(award_family),
    award_type_code          = lastval(award_type_code),
    award_type_label         = lastval(award_type_label),
    award_id                 = lastval(award_id),
    parent_award_id          = lastval(parent_award_id),
    recipient_uei            = lastval(recipient_uei),
    recipient_name           = lastval(recipient_name),
    recipient_parent_uei     = lastval(recipient_parent_uei),
    recipient_state          = lastval(recipient_state),
    awarding_agency_code     = lastval(awarding_agency_code),
    awarding_agency_name     = lastval(awarding_agency_name),
    awarding_sub_agency_name = lastval(awarding_sub_agency_name),
    funding_agency_name      = lastval(funding_agency_name),
    cfda_number              = lastval(cfda_number),
    cfda_title               = lastval(cfda_title),
    naics_code               = lastval(naics_code),
    psc_code                 = lastval(psc_code),
    base_action_date         = suppressWarnings(min(action_date, na.rm = TRUE)),
    latest_action_date       = suppressWarnings(max(action_date, na.rm = TRUE)),
    pop_start_date           = lastval(pop_start_date),
    pop_end_date             = lastval(pop_end_date),
    total_obligated          = lastval(award_total_obligated),
    total_outlayed           = lastval(award_total_outlayed),
    potential_value          = NA_real_,
    subaward_count           = NA_real_,
    subaward_total           = NA_real_,
    n_transactions           = .N,
    n_years                  = data.table::uniqueN(action_year),
    n_recipients             = data.table::uniqueN(recipient_uei),
    obligated_in_extract     = sum(federal_action_obligation, na.rm = TRUE)
  ), by = award_key]

  aw[is.infinite(base_action_date),   "base_action_date"   := NA]
  aw[is.infinite(latest_action_date), "latest_action_date" := NA]

  if (enrich) {
    us_msg("Enriching {nrow(aw)} award{?s} via the award overview endpoint.")
    ov <- data.table::rbindlist(lapply(aw$award_key, us_fetch_award), fill = TRUE)
    ov <- ov[error == FALSE, c("award_key", "subaward_count", "subaward_total")]
    aw[ov, c("subaward_count", "subaward_total") :=
         list(i.subaward_count, i.subaward_total), on = "award_key"]
  }
  if (rollup_idv) {
    cli::cli_warn("IDV rollup is not implemented; delivery orders are left as separate awards.")
  }
  data.table::setcolorder(aw, c(us_schema("awards")$field))
  aw[]
}

#' Map UEIs to organizations
#'
#' Large nonprofits hold several SAM registrations and USAspending splits their
#' awards across them, so the organization -- not the UEI -- is the unit of
#' analysis. Supply a crosswalk and every downstream table is keyed on
#' `org_id`. Without one, each UEI is its own organization.
#'
#' @param uei Character vector of UEIs.
#' @param org_map Optional two-column `data.frame` of `uei` and `org_id`
#'   (an EIN, for instance).
#' @return A `data.table` of `uei`, `org_id`.
#' @export
#' @examples
#' us_org_map(c("CFFMYPABYAG3", "H7LMD1ANJNN4"))
us_org_map <- function(uei, org_map = NULL) {
  uei <- us_validate_uei(uei)
  if (is.null(org_map)) {
    return(unique(data.table::data.table(uei = uei, org_id = uei)))
  }
  om <- data.table::as.data.table(org_map)
  if (!all(c("uei", "org_id") %in% names(om))) {
    us_abort("{.arg org_map} must have columns {.val uei} and {.val org_id}.")
  }
  om[, "uei" := us_validate_uei(uei)]
  om <- unique(om[, c("uei", "org_id")])
  ## the key has to be built outside the subset call: data.table evaluates `i`
  ## with the table's own columns in scope, so `data.table(uei = uei)` written
  ## inline would silently pick up om$uei instead of the argument
  key <- data.table::data.table(uei = unique(uei))
  out <- om[key, on = "uei"]
  n_orphan <- sum(is.na(out$org_id))
  if (n_orphan) {
    cli::cli_warn("{n_orphan} UEI{?s} absent from {.arg org_map}; each becomes its own organization.")
    out[is.na(org_id), "org_id" := uei]
  }
  unique(out[, c("uei", "org_id")])[]
}
