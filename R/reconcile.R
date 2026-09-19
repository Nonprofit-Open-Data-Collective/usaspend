## Reconciliation and audit. USAspending's award-lifetime totals are computed
## by a different system from the transactions, which makes them a genuine
## external check on the netting.
##
## Measured on the 50-nonprofit pilot (after de-duplication): 36,165 of 47,423
## assistance awards reconcile to the dollar. Of the rest, an API audit of a
## random sample of the breaks showed roughly 60% explained by window
## truncation (actions before/after the pull window -- including corrections
## filed after the pull that the extract could not contain) and the remainder
## by transactions attributed to another recipient's UEI: NIH-style awards
## follow the PI between institutions, so part of the award's history belongs
## to a different organization and legitimately is not in a UEI-filtered
## extract. The award-search floor (2007-10-01) explains the elevated break
## rate for awards first seen 2008-2009; recent years break because
## corrections arrive for years after the window closes.

#' Reconcile netted transactions against award lifetime totals
#'
#' The invariant: for an award whose whole history is inside the extract, the
#' sum of `federal_action_obligation` across its transactions equals the
#' award's reported lifetime total. A break is classified, not just counted --
#' most breaks are structural (truncation, recipient changes), not bugs.
#'
#' An award is `window_edge` when its history evidently begins before the pull
#' window: its earliest reported period-of-performance start (on the award
#' record or any of its transactions) precedes the first action date in the
#' extract, or its first in-extract action falls within a year of the window
#' opening. The second test alone misses awards made before the window whose
#' first in-window action is a later modification: `base_action_date` is the
#' earliest action *in the extract*, so it can never precede the window. The
#' period-of-performance test is added to it rather than replacing it, because
#' a later modification can move an award's reported start date forward past
#' its first obligation.
#'
#' @param panel A `usaspend_panel` from [us_panel()].
#' @param tolerance Absolute dollar tolerance for the identity.
#' @return A `data.table`, one row per award: `tx_sum`, `reported`, `gap`,
#'   `status` (`"out_of_sample"`, `"no_reported_total"`, `"ok"`,
#'   `"multi_recipient"`, `"window_edge"`, `"recent_open"`, `"break"`, tested
#'   in that order), the outlay ratio, and `in_sample`.
#'
#' @section Out-of-sample awards:
#' An award is `"out_of_sample"` when none of its transactions carry a
#' recipient UEI in the panel's organization map -- the UEIs whose own
#' histories [us_extract()] pulled. The bulk download filters on
#' `recipient_search_text`, which also matches a transaction's *parent* UEI
#' (see [us_download_submit()]), so querying a parent returns its
#' subsidiaries' transactions -- but only those filed while the parent was
#' recorded as parent. Querying RTI (`JJHCMK4NT5N3`) returned transactions of
#' its subsidiary International Resources Group from 2017 on, after the
#' acquisition; the same awards' earlier actions, filed under the previous
#' parents, were not returned. Such a history is truncated by construction, so
#' the identity fails for reasons that say nothing about the netting.
#'
#' The test runs first, ahead of every other label: an out-of-sample award is
#' not part of the organization's panel whether or not it happens to
#' reconcile. [us_panel()] already leaves these transactions out of `panel`;
#' they stay in `awards` and `transactions`, flagged `in_sample = FALSE`, so
#' the leak stays visible. To count subsidiaries as part of their parents,
#' extract their full histories with `us_extract(subsidiaries = TRUE)` or
#' [us_add_subsidiaries()]; see `vignette("org-map")`. Panels built before
#' [us_panel()] recorded its organization map fall back to the transactions'
#' `is_stray_uei` flag.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' r <- us_reconcile(p)
#' r[, .N, by = status]
us_reconcile <- function(panel, tolerance = 1) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  stopifnot(is.numeric(tolerance), length(tolerance) == 1L, tolerance >= 0)
  aw <- panel$awards
  tx <- panel$transactions

  sums <- tx[, .(tx_sum = sum(federal_action_obligation, na.rm = TRUE)),
             by = award_key]
  r <- merge(aw[, c("award_key", "total_obligated", "total_outlayed",
                    "base_action_date", "latest_action_date", "n_recipients",
                    "pop_start_date")],
             sums, by = "award_key", all.x = TRUE)
  r[is.na(tx_sum), "tx_sum" := 0]

  ## earliest period-of-performance start on record. The award row carries the
  ## latest-reported value, which later modifications can move forward, so the
  ## transactions' own values are consulted too.
  pop <- tx[!is.na(pop_start_date), .(pop_tx = min(pop_start_date)),
            by = award_key]
  r[pop, "pop_start_date" := pmin(pop_start_date, i.pop_tx, na.rm = TRUE),
    on = "award_key"]
  r[, "gap" := total_obligated - tx_sum]
  r[, "outlay_ratio" := data.table::fifelse(
      !is.na(total_outlayed) & !is.na(total_obligated) & total_obligated != 0,
      total_outlayed / total_obligated, NA_real_)]

  ## the pull window, inferred from the data itself
  win_lo <- suppressWarnings(min(tx$action_date, na.rm = TRUE))
  win_hi <- suppressWarnings(max(tx$action_date, na.rm = TRUE))

  ## awards held entirely by UEIs outside the organization map -- chiefly
  ## subsidiaries matched through their parent UEI -- are not the sample's
  r[, "in_sample" := award_key %in% in_sample_awards(panel)]

  r[, "status" := data.table::fcase(
      !in_sample,                                   "out_of_sample",
      is.na(total_obligated),                      "no_reported_total",
      abs(gap) <= tolerance,                        "ok",
      n_recipients > 1L,                            "multi_recipient",
      !is.na(pop_start_date) & pop_start_date < win_lo, "window_edge",
      base_action_date <= win_lo + 370,             "window_edge",
      latest_action_date >= win_hi - 370,           "recent_open",
      default = "break")]
  r[, "pop_start_date" := NULL]

  tally <- r[, .N, by = status][order(-N)]
  us_msg(c("Reconciled {nrow(r)} award{?s}: {r[status == 'ok', .N]} exact ({round(100 * r[status == 'ok', .N] / max(nrow(r), 1))}%).",
           "*" = "{paste0(tally$status, '=', tally$N, collapse = ' ')}"))
  n_out <- r[status == "out_of_sample", .N]
  if (n_out) {
    us_msg("{n_out} award{?s} held only by UEIs outside the organization map: {.val out_of_sample} (typically subsidiaries matched through a parent UEI, histories truncated).")
  }
  n_hard <- r[status == "break", .N]
  if (n_hard) {
    cli::cli_warn("{n_hard} award{?s} break the lifetime identity with no structural explanation -- inspect before publishing.")
  }
  data.table::setorderv(r, "gap", order = -1L)
  r[]
}

## Award keys with at least one transaction on a UEI in the panel's
## organization map. Panels built before us_panel() stored the map fall back
## to the requested-UEI flag set by us_normalize_transactions().
in_sample_awards <- function(panel) {
  tx <- panel$transactions
  if (!nrow(tx)) return(character(0))
  om <- panel$org_map
  uei <- if (is.null(om)) NULL else if ("in_sample" %in% names(om)) {
    om$uei[om$in_sample]
  } else om$uei
  keep <- if (!is.null(uei)) {
    !is.na(tx$recipient_uei) & tx$recipient_uei %in% uei
  } else if ("is_stray_uei" %in% names(tx)) {
    !tx$is_stray_uei
  } else {
    rep(TRUE, nrow(tx))
  }
  unique(tx$award_key[keep])
}

#' Audit a finished panel
#'
#' Structural checks needing no external reference. Run on every rebuild and
#' diff against the previous run, so a change in the data or a rule shows up as
#' a change in the audit rather than as a quietly different number.
#'
#' @param panel A `usaspend_panel` from [us_panel()].
#' @return A `data.table` of `check`, `value`, `status` (`"ok"` / `"info"` /
#'   `"warn"`).
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' us_audit(p)
us_audit <- function(panel) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  p <- panel$panel; tx <- panel$transactions
  add <- function(check, value, status) {
    data.table::data.table(check = check, value = as.character(value), status = status)
  }
  dup_grain <- nrow(p) - data.table::uniqueN(p[, c("org_id", "award_key", "year")])
  multi_org <- p[, data.table::uniqueN(org_id), by = award_key][V1 > 1L, .N]
  dup_tx <- sum(duplicated(tx$transaction_key[!is.na(tx$transaction_key)]))
  neg_years <- p[obligation_net < 0, .N]
  neg_rev <- p[net_revenue < 0 & obligation_net >= 0, .N]
  zero_share <- if (nrow(tx)) round(100 * mean(tx$is_zero_dollar), 1) else 0
  flagged <- if (nrow(tx)) sum(tx$flags != "") else 0L

  out <- data.table::rbindlist(list(
    add("rows at org x award x year grain", nrow(p), "info"),
    add("duplicate grain rows", dup_grain, if (dup_grain) "warn" else "ok"),
    add("awards attributed to >1 organization", multi_org,
        if (multi_org) "warn" else "ok"),
    add("duplicate transaction keys after normalization", dup_tx,
        if (dup_tx) "warn" else "ok"),
    add("org-award-years with negative net obligation", neg_years, "info"),
    add("rows where pass-through pushes net_revenue below zero", neg_rev, "info"),
    add("share of zero-dollar transactions (%)", zero_share, "info"),
    add("transactions carrying anomaly flags", flagged,
        if (flagged) "info" else "ok"),
    add("years covered", paste(range(p$year), collapse = "-"), "info"),
    add("outbound subawards fetched", panel$meta$subawards_out_fetched,
        if (panel$meta$subawards_out_fetched) "ok" else "warn")
  ))
  out[]
}
