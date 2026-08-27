## Roll-ups over the org x award x year panel, and inflation adjustment.

MONEY_COLS <- c("obligation_positive", "obligation_negative", "obligation_net",
                "deobligation_prior_year", "loan_face_value", "loan_subsidy_cost",
                "subaward_out_amount", "subaward_in_amount", "net_revenue",
                "total_net")

#' Roll the panel up across grouping dimensions
#'
#' Aggregates every award in the panel to the chosen grain, carrying both
#' directions of money: prime obligations, outflows (pass-through subawards
#' paid), and inflows (subawards received, which never appear in prime data).
#'
#' Each dimension is a toggle: `TRUE` groups by it, `NULL` (or `FALSE`)
#' aggregates over it.
#' \describe{
#'   \item{`org_id = TRUE, year = NULL`}{(default) one row per organization,
#'     totalled across all years.}
#'   \item{`year = TRUE`}{a trend tabulation -- org x year, or year alone if
#'     `org_id = FALSE`.}
#'   \item{`state = TRUE`}{groups prime flows by the award's registered
#'     recipient state. Inbound subawards are organization-level, so they are
#'     assigned to the organization's dominant state (largest share of absolute
#'     net obligations).}
#' }
#' All three `FALSE`/`NULL` returns a single grand-total row.
#'
#' @section Columns:
#' Counts (`n_awards`, `n_transactions`, `n_subawards_out`, `n_subawards_in`)
#' and dollars: gross positive / negative / net obligations, loan face value,
#' `subaward_out_amount`, `subaward_in_amount`, `net_revenue`
#' (`obligation_net - subaward_out_amount`) and `total_net`
#' (`obligation_net + subaward_in_amount - subaward_out_amount`) -- the fullest
#' single measure of net federal dollars flowing to the group.
#'
#' Inflows come from the panel's organization-level `subawards_in` table, not
#' from the panel rows (panel rows carry inbound amounts only in the rare case
#' where an organization is prime and subawardee on the same award).
#'
#' @param panel A `usaspend_panel` from [us_panel()].
#' @param org_id Group by organization. Default `TRUE`.
#' @param year Group by year. Default `NULL` (aggregate across years);
#'   `TRUE` produces a trend tabulation.
#' @param state Group by recipient state. Default `NULL`.
#' @return A `data.table` at the requested grain, sorted by the grouping keys.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' us_rollup(p)                             # one row per org, all years
#' us_rollup(p, year = TRUE)                # org x year trend
#' us_rollup(p, org_id = FALSE, year = TRUE)  # sector-wide trend
#' us_rollup(p, state = TRUE, org_id = FALSE) # state totals
us_rollup <- function(panel, org_id = TRUE, year = NULL, state = NULL) {
  if (!inherits(panel, "usaspend_panel")) {
    us_abort("{.arg panel} must be a {.cls usaspend_panel} from {.fn us_panel}.")
  }
  use <- function(x) isTRUE(x)
  keys <- c(if (use(org_id)) "org_id", if (use(year)) "year",
            if (use(state)) "state")

  g <- data.table::copy(panel$panel)
  if (use(state) && !"recipient_state" %in% names(g)) {
    us_abort(c("The panel has no {.field recipient_state} column.",
               "i" = "Rebuild it with usaspend >= this version; older panels predate the state field."))
  }

  ## the organization's dominant state, for assigning org-level inflows
  org_state <- if ("recipient_state" %in% names(g)) {
    w <- g[, .(w = sum(abs(obligation_net)) + .N), by = .(org_id, recipient_state)]
    w[order(-w), .SD[1L], by = org_id][, .(org_id, org_state = recipient_state)]
  } else {
    data.table::data.table(org_id = unique(g$org_id), org_state = NA_character_)
  }

  if (use(state)) g[, "state" := recipient_state]

  ## ---- prime flows + outflows, from panel rows -----------------------------
  prime <- g[, .(
    n_awards            = data.table::uniqueN(award_key),
    n_transactions      = sum(n_transactions),
    obligation_positive = sum(obligation_positive),
    obligation_negative = sum(obligation_negative),
    obligation_net      = sum(obligation_net),
    loan_face_value     = sum(loan_face_value),
    subaward_out_amount = sum(subaward_out_amount),
    n_subawards_out     = sum(n_subawards_out)
  ), by = keys]

  ## ---- inflows, from the org-level inbound table ---------------------------
  si <- data.table::copy(panel$subawards_in)
  if (nrow(si)) {
    si <- merge(si, org_state, by = "org_id", all.x = TRUE)
    if (use(state)) si[, "state" := org_state]
    ikeys <- intersect(keys, names(si))
    inflow <- if (length(ikeys)) {
      si[, .(subaward_in_amount = sum(subaward_in_amount),
             n_subawards_in = sum(n_subawards_in)), by = ikeys]
    } else {
      si[, .(subaward_in_amount = sum(subaward_in_amount),
             n_subawards_in = sum(n_subawards_in))]
    }
  } else {
    inflow <- NULL
  }

  out <- if (is.null(inflow)) {
    prime[, c("subaward_in_amount", "n_subawards_in") := list(0, 0L)]
    prime
  } else if (length(keys)) {
    m <- merge(prime, inflow, by = intersect(keys, names(inflow)), all = TRUE)
    ## an org-year can have inflows with no prime activity at all
    for (cc in setdiff(names(m), keys)) {
      v <- m[[cc]]; v[is.na(v)] <- if (is.integer(v)) 0L else 0; m[, (cc) := v]
    }
    m
  } else {
    cbind(prime, inflow)
  }

  out[, "net_revenue" := obligation_net - subaward_out_amount]
  out[, "total_net"   := obligation_net + subaward_in_amount - subaward_out_amount]
  if (length(keys)) data.table::setorderv(out, keys)
  out[]
}

#' Annual price index bundled with the package
#'
#' CPI-U, U.S. city average, all items, annual averages (1982-84 = 100),
#' from the Bureau of Labor Statistics. The 2025 value is the provisional
#' annual average; check BLS for revisions before publication-grade work, or
#' supply your own series via the `index` argument of
#' [us_adjust_inflation()] -- a two-column `data.frame` of `year` and `index`
#' (any consistent base year works, since only ratios are used).
#'
#' @return A `data.table` of `year`, `index`.
#' @export
#' @examples
#' us_price_index()
us_price_index <- function() {
  data.table::data.table(
    year = 2007:2025,
    index = c(207.342, 215.303, 214.537, 218.056, 224.939, 229.594, 232.957,
              236.736, 237.017, 240.007, 245.120, 251.107, 255.657, 258.811,
              270.970, 292.655, 304.702, 313.689, 322.561)
  )
}

#' Adjust panel dollars for inflation
#'
#' Restates every dollar column into constant dollars of a target year using an
#' annual price index: `amount * index[target] / index[year]`.
#'
#' @param x A `usaspend_panel` (its `panel` and `subawards_in` tables are both
#'   adjusted), or any `data.frame` with a `year` column -- including
#'   [us_rollup()] output, provided it was built with `year = TRUE` (a rollup
#'   collapsed across years mixes vintages and cannot be deflated; adjust
#'   first, then roll up).
#' @param target_year Year whose dollars to state everything in. Default: the
#'   latest year in the data that the index covers (a message says which).
#' @param index `NULL` for the bundled CPI-U series ([us_price_index()]), or a
#'   `data.frame` of `year` and `index`.
#' @param cols Columns to adjust. Default: the package's known dollar columns
#'   present in the data.
#' @param strict If `TRUE` (default), a data year missing from the index is an
#'   error. If `FALSE`, those rows' dollar columns become `NA` with a warning --
#'   visible, never silently unadjusted.
#' @return The same structure with dollar columns restated, and an
#'   `usaspend_inflation` attribute (on the data.frame, or in `meta` for a
#'   panel) recording the target year and index range used.
#' @export
#' @examples
#' p <- us_panel(us_sample_extract())
#' oy <- us_rollup(p, year = TRUE)
#' oy25 <- us_adjust_inflation(oy, target_year = 2025)
#' attr(oy25, "usaspend_inflation")
us_adjust_inflation <- function(x, target_year = NULL, index = NULL,
                                cols = NULL, strict = TRUE) {
  idx <- data.table::as.data.table(index %||% us_price_index())
  if (!all(c("year", "index") %in% names(idx))) {
    us_abort("{.arg index} must have columns {.val year} and {.val index}.")
  }
  idx <- idx[!is.na(year) & !is.na(index)]

  if (inherits(x, "usaspend_panel")) {
    x$panel <- us_adjust_inflation(x$panel, target_year, idx, cols, strict)
    x$subawards_in <- us_adjust_inflation(x$subawards_in, target_year, idx,
                                          cols, strict)
    x$meta$inflation <- attr(x$panel, "usaspend_inflation")
    return(x)
  }

  x <- data.table::as.data.table(x)
  if (!"year" %in% names(x)) {
    us_abort(c("{.arg x} has no {.field year} column.",
               "i" = "A rollup collapsed across years mixes dollar vintages -- adjust the panel first, then roll up."))
  }
  if (!nrow(x)) return(x)

  target_year <- target_year %||% max(intersect(x$year, idx$year))
  if (!length(target_year) || is.infinite(target_year)) {
    us_abort("No year in the data is covered by the index.")
  }
  tgt <- idx[year == target_year]$index
  if (length(tgt) != 1L) {
    us_abort(c("Target year {target_year} is not in the price index.",
               "i" = "Index covers {min(idx$year)}-{max(idx$year)}. Pass {.arg index} to extend it."))
  }

  missing_years <- sort(setdiff(unique(x$year), idx$year))
  if (length(missing_years)) {
    if (strict) {
      us_abort(c("{length(missing_years)} data year{?s} {?is/are} not in the price index: {.val {missing_years}}.",
                 "i" = "Pass {.arg index} with those years, or {.code strict = FALSE} to set them NA."))
    }
    cli::cli_warn("{length(missing_years)} data year{?s} not in the index ({.val {missing_years}}); their dollar columns are set to NA.")
  }

  cols <- cols %||% intersect(MONEY_COLS, names(x))
  if (!length(cols)) us_abort("No dollar columns found to adjust.")

  factor <- tgt / idx$index[match(x$year, idx$year)]   # NA for missing years
  for (cc in cols) x[, (cc) := x[[cc]] * factor]
  data.table::setattr(x, "usaspend_inflation",
    list(target_year = as.integer(target_year), cols = cols,
         index_years = range(idx$year),
         source = if (is.null(index)) "bundled CPI-U annual averages (BLS)"
                  else "user-supplied"))
  us_msg("Restated {length(cols)} column{?s} in {target_year} dollars.")
  x[]
}
