#' Build the organization x award x year panel
#'
#' The end-to-end pipeline: normalize, ledger, net, join subaward flows, attach
#' award attributes.
#'
#' @section What the panel measures:
#' `obligation_net` is the net federal obligation booked to the
#' organization-award-year. It is a **commitment**, not a disbursement --
#' federal award data does not carry annual cash. `net_revenue` is
#' `obligation_net - subaward_out_amount`: what the organization commits to
#' keeping after money it is obliged to pass through. Outbound subawards are
#' present only if the extract fetched them (`subawards = "out"` or `"both"` in
#' [us_extract()]); otherwise the column is zero and `subaward_coverage` says
#' `"not_fetched"`, so a zero is never mistaken for a measured zero.
#'
#' Inbound subawards -- money received as a subrecipient, invisible in prime
#' data -- are aggregated per organization-year in the separate
#' `subawards_in` element, keyed by subawardee UEI, and also joined onto
#' matching panel rows as `subaward_in_amount` when the prime award key appears
#' in the panel (rare: it requires the org to be both prime and subawardee).
#'
#' @param extract A `usaspend_extract` from [us_extract()], or a list with
#'   `transactions` and `subawards`.
#' @param org_map Optional `uei` to `org_id` crosswalk, see [us_org_map()].
#' @param period `"calendar"` (default) or `"fiscal"`.
#' @param measure Money measure, see [us_money_column()].
#' @param deobligation_policy See [us_net_by_year()].
#' @param fill_gaps Emit zero-obligation rows so every dollar of pass-through
#'   has a row to land on. This does two things: interior years of an award's
#'   life with no actions get zero rows (via [us_net_by_year()]), and outbound
#'   subawards booked to an org-award-year with no prime activity -- common,
#'   because FSRS reports trail the obligations they draw on -- get their own
#'   zero-obligation rows instead of being silently dropped. In the pilot, 13%
#'   of outbound dollars fell in such years. With `fill_gaps = FALSE` the
#'   panel's `subaward_out_amount` total is a floor, not the total fetched.
#' @return A list of class `usaspend_panel`: `panel` (org x award x year),
#'   `awards` (the spine), `transactions` (the normalized ledger),
#'   `subawards` (normalized, with direction), `subawards_in` (org-year
#'   inbound revenue), and `meta`.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' p$panel[, .(rows = .N, net = sum(obligation_net)), by = year][order(year)]
us_panel <- function(extract,
                     org_map = NULL,
                     period = c("calendar", "fiscal"),
                     measure = c("obligation", "pragmatic"),
                     deobligation_policy = c("as_posted", "restate", "drop"),
                     fill_gaps = FALSE) {
  period <- match.arg(period)
  measure <- match.arg(measure)
  deobligation_policy <- match.arg(deobligation_policy)
  stopifnot(is.logical(fill_gaps), length(fill_gaps) == 1L)
  if (!is.list(extract) || !all(c("transactions", "subawards") %in% names(extract))) {
    us_abort(c("{.arg extract} must have {.field transactions} and {.field subawards}.",
               "i" = "Pass the result of {.fn us_extract}."))
  }

  requested <- extract$meta$uei %||% NULL
  org_uei <- requested %||% unique(extract$transactions$recipient_uei)
  om <- us_org_map(org_uei, org_map)

  ## ---- normalize -----------------------------------------------------------
  tx <- us_normalize_transactions(extract$transactions, requested_uei = requested)
  aw <- us_normalize_awards(tx)
  sb <- if (nrow(extract$subawards)) {
    us_normalize_subawards(extract$subawards, org_uei = om$uei)
  } else us_empty("subawards")

  ## ---- net -----------------------------------------------------------------
  lg <- us_ledger(tx, measure = measure)
  g  <- us_net_by_year(lg, om, period = period,
                       deobligation_policy = deobligation_policy,
                       fill_gaps = fill_gaps)

  ## ---- subaward flows ------------------------------------------------------
  fetched_out <- isTRUE(extract$meta$subawards %in% c("out", "both"))
  s_out <- us_subaward_by_year(sb, period = period, direction = "out")
  s_in  <- us_subaward_by_year(sb, period = period, direction = "in")

  so <- s_out[, .(award_key = prime_award_key, year,
                  subaward_out_amount = amount, n_subawards_out = n)]
  g <- merge(g, so, by = c("award_key", "year"), all.x = TRUE)
  g[is.na(subaward_out_amount), "subaward_out_amount" := 0]
  g[is.na(n_subawards_out), "n_subawards_out" := 0L]

  ## An award-year can carry rows for two organizations (multi-recipient
  ## awards -- NIH grants following a PI between institutions). The join above
  ## lands the same subaward on every such row, double-counting it. Keep the
  ## pass-through on the row with the dominant activity in that award-year and
  ## zero it elsewhere, so sum(subaward_out_amount) equals the dollars fetched.
  g[, "n_org_rows" := .N, by = .(award_key, year)]
  if (any(g$n_org_rows > 1L & g$subaward_out_amount > 0)) {
    data.table::setorderv(g, c("award_key", "year"))
    g[n_org_rows > 1L & subaward_out_amount > 0,
      c("subaward_out_amount", "n_subawards_out") := {
        keep <- which.max(abs(obligation_net) + n_transactions / 1e9)
        list(subaward_out_amount * (seq_len(.N) == keep),
             n_subawards_out * (seq_len(.N) == keep))
      }, by = .(award_key, year)]
  }
  g[, "n_org_rows" := NULL]

  ## With fill_gaps, outbound subawards booked to an org-award-year with no
  ## prime activity -- after the last modification, or in a year the interior
  ## fill did not cover -- get their own zero-obligation rows instead of being
  ## dropped. Without it they are dropped, understating pass-through: 13% of
  ## outbound dollars in the pilot fell in such years.
  if (fill_gaps && nrow(so)) {
    orphan <- so[!g, on = c("award_key", "year")]
    orphan <- orphan[!is.na(year)]
    if (nrow(orphan)) {
      ## resolve the organization through the award spine
      spine_org <- merge(aw[, c("award_key", "recipient_uei")], om,
                         by.x = "recipient_uei", by.y = "uei", all.x = TRUE)
      orphan <- merge(orphan, spine_org[, c("award_key", "org_id")],
                      by = "award_key", all.x = TRUE)
      n_unres <- sum(is.na(orphan$org_id))
      if (n_unres) {
        us_msg("Dropping {n_unres} orphan subaward-year{?s} whose award maps to no organization.")
        orphan <- orphan[!is.na(org_id)]
      }
      if (nrow(orphan)) {
        zero_cols <- setdiff(names(g), names(orphan))
        for (cc in zero_cols) {
          orphan[, (cc) := if (is.integer(g[[cc]])) 0L else 0]
        }
        data.table::setcolorder(orphan, names(g))
        g <- data.table::rbindlist(list(g, orphan), use.names = TRUE)
        us_msg("Added {nrow(orphan)} zero-obligation row{?s} for subaward-years without prime activity.")
      }
    }
  }

  ## s_in is keyed (prime_award_key, subawardee_uei, year); collapse the UEI
  ## dimension before joining or a multi-subawardee award-year duplicates
  ## panel rows
  s_in_ay <- if (nrow(s_in)) {
    s_in[, .(subaward_in_amount = sum(amount), n_subawards_in = sum(n)),
         by = .(award_key = prime_award_key, year)]
  } else {
    data.table::data.table(award_key = character(0), year = integer(0),
                           subaward_in_amount = numeric(0), n_subawards_in = integer(0))
  }
  g <- merge(g, s_in_ay, by = c("award_key", "year"), all.x = TRUE)
  g[is.na(subaward_in_amount), "subaward_in_amount" := 0]
  g[is.na(n_subawards_in), "n_subawards_in" := 0L]

  g[, "net_revenue" := obligation_net - subaward_out_amount]

  ## inbound subawards as org-year revenue, keyed through the subawardee UEI
  sub_in_org <- if (nrow(s_in)) {
    si <- merge(s_in, om, by.x = "subawardee_uei", by.y = "uei", all.x = TRUE)
    si[!is.na(org_id),
       .(subaward_in_amount = sum(amount), n_subawards_in = sum(n)),
       by = .(org_id, year)]
  } else {
    data.table::data.table(org_id = character(0), year = integer(0),
                           subaward_in_amount = numeric(0), n_subawards_in = integer(0))
  }

  ## ---- award attributes ----------------------------------------------------
  attrs <- aw[, c("award_key", "award_group", "award_family", "award_type_code",
                  "award_type_label", "awarding_agency_code", "awarding_agency_name",
                  "awarding_sub_agency_name", "funding_agency_name",
                  "cfda_number", "naics_code", "recipient_state")]
  g <- merge(g, attrs, by = "award_key", all.x = TRUE)
  g[, "year_basis" := period]
  g[, "flags" := ""]
  g[!fetched_out & nrow(s_out) == 0L, "flags" := "subawards_out_not_fetched"]

  data.table::setcolorder(g, intersect(us_schema("panel")$field, names(g)))
  data.table::setorderv(g, c("org_id", "award_key", "year"))

  structure(list(
    panel        = g[],
    awards       = aw,
    transactions = tx,
    subawards    = sb,
    subawards_in = sub_in_org,
    meta = list(period = period, measure = measure,
                deobligation_policy = deobligation_policy,
                subawards_out_fetched = fetched_out,
                n_orgs = data.table::uniqueN(g$org_id),
                built_at = Sys.time())
  ), class = "usaspend_panel")
}

#' Roll the award panel up to organization x year
#'
#' Convenience aggregation over [us_panel()] output for analyses that do not
#' need award detail. Includes inbound subaward revenue, which exists only at
#' organization level.
#'
#' @param panel A `usaspend_panel`.
#' @param by Extra grouping columns from the panel, e.g. `"award_family"` or
#'   `"awarding_agency_name"`.
#' @return A `data.table` at organization x year (x `by`) grain.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' us_org_year(p)
#' us_org_year(p, by = "award_family")
us_org_year <- function(panel, by = NULL) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  p <- panel$panel
  if (!is.null(by) && !all(by %in% names(p))) {
    us_abort("{.arg by} names columns absent from the panel: {.val {setdiff(by, names(p))}}.")
  }
  keys <- c("org_id", "year", by)
  out <- p[, .(
    n_awards            = data.table::uniqueN(award_key),
    n_transactions      = sum(n_transactions),
    obligation_positive = sum(obligation_positive),
    obligation_negative = sum(obligation_negative),
    obligation_net      = sum(obligation_net),
    loan_face_value     = sum(loan_face_value),
    subaward_out_amount = sum(subaward_out_amount),
    net_revenue         = sum(net_revenue)
  ), by = keys]
  if (is.null(by) && nrow(panel$subawards_in)) {
    out <- merge(out, panel$subawards_in, by = c("org_id", "year"), all = TRUE)
    for (cc in setdiff(names(out), c("org_id", "year"))) {
      v <- out[[cc]]; v[is.na(v)] <- 0; out[, (cc) := v]
    }
  }
  data.table::setorderv(out, keys)
  out[]
}

#' @export
print.usaspend_panel <- function(x, ...) {
  p <- x$panel
  cli::cli_h1("usaspend panel")
  cli::cli_bullets(c(
    "*" = "{nrow(p)} org-award-year row{?s}",
    "*" = "{data.table::uniqueN(p$org_id)} organization{?s}, {data.table::uniqueN(p$award_key)} award{?s}",
    "*" = "{min(p$year)}-{max(p$year)} ({x$meta$period} year, {x$meta$deobligation_policy})",
    "*" = "net obligations ${prettyNum(round(sum(p$obligation_net) / 1e6), big.mark = ',')}M",
    "*" = if (x$meta$subawards_out_fetched) "outbound subawards netted" else "outbound subawards NOT fetched -- net_revenue equals obligation_net"))
  invisible(x)
}
