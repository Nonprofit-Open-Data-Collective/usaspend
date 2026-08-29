## The accounting core: signed ledger -> org x award x year.
## Validated against the 50-nonprofit pilot (302,025 prime transactions).

#' Which transaction amount counts as money
#'
#' USAspending carries several dollar columns and only some of them are revenue.
#' This returns the measure a given policy uses, so that the choice is made once
#' and visibly rather than being buried in an aggregation.
#'
#' \describe{
#'   \item{`"obligation"`}{`federal_action_obligation`. The signed amount the
#'     government committed in this action. The default, and the only column
#'     that supports an annual panel.}
#'   \item{`"pragmatic"`}{`pragmatic_obligation` -- USAspending's own derived
#'     measure, which substitutes the loan subsidy cost for loans and equals the
#'     obligation otherwise. In the pilot the two are identical on every
#'     non-loan row.}
#'   \item{`"outlay"`}{Not available. There is no transaction-level or annual
#'     outlay in the award data, and `award_total_outlayed` is lifetime-to-date,
#'     not annual. Its coverage follows the reporting mandates: account-level
#'     (File C) outlay reporting was quarterly and optional from FY2017,
#'     required for COVID-supplemental awards from April 2020, and monthly and
#'     mandatory for all agencies only from FY2022 -- so lifetime outlays
#'     undercount any award straddling those dates (91% of pilot awards
#'     starting before 2017 report no outlay at all), and coverage varies by
#'     agency and award family, not just era: post-FY2022 in the VUMC pilot,
#'     98% of HHS awards carry an outlay against 0% of VA contracts.
#'     Requesting this raises an error rather than returning something
#'     misleading. Annual outlays can be attached to a fiscal panel as a
#'     separate, coverage-graded column with [us_add_outlays()] -- they are
#'     an additional measure, never the panel measure.}
#' }
#'
#' The measures that must never be summed as revenue: `potential_value`,
#' `base_and_all_options_value`, `current_total_value_of_award`,
#' `total_funding_amount`. These are ceilings. The pilot holds $115bn of IDV
#' ceiling value against $0.75bn actually obligated on those vehicles --
#' a ceiling-based panel would overstate contract revenue by two orders of
#' magnitude.
#'
#' @param measure One of `"obligation"`, `"pragmatic"`, `"outlay"`.
#' @return The canonical column name to sum.
#' @export
#' @examples
#' us_money_column("obligation")
us_money_column <- function(measure = c("obligation", "pragmatic", "outlay")) {
  measure <- match.arg(measure)
  if (measure == "outlay") {
    us_abort(c("Annual outlays are not available from the award data.",
               "i" = "{.field award_total_outlayed} is award-lifetime and missing for 91% of pre-2017 pilot awards.",
               "i" = "Annual disbursements live in account-level File C data, complete only from FY2022 when monthly reporting became mandatory.",
               "i" = "Use {.val obligation} and describe the panel as obligations, not payments; attach cash as a separate column with {.fn us_add_outlays}."))
  }
  switch(measure, obligation = "federal_action_obligation",
                  pragmatic  = "pragmatic_obligation")
}

#' Build a signed accounting ledger
#'
#' Adds the accounting interpretation to a normalized transaction ledger:
#' each row's bookable amount, its sign class, and whether it belongs in the
#' revenue measure at all.
#'
#' @section Rules, as measured on the pilot:
#' \itemize{
#'   \item **The sign is the truth.** 25,993 pilot transactions (8.6%) carry a
#'     negative obligation, and they arrive under every action class --
#'     6,344 assistance CONTINUATIONs are negative, as are 3,276 contract
#'     FUNDING ONLY actions. The action class describes intent; the sign
#'     describes money.
#'   \item **Loans are excluded from revenue.** Direct loans (type 07) carry
#'     `federal_action_obligation = 0` on all 6,496 pilot rows while
#'     `face_value_of_loan` sums to $626bn. Face value is a liability, not
#'     income; the obligation column already handles this correctly by being
#'     zero, and the face value and subsidy cost travel in their own columns.
#'   \item **Direct payments (06, 10) are includable but separable.** In the
#'     pilot these are real entity-level payments (e.g. campus-based student
#'     aid). They stay in the ledger with `in_revenue = TRUE` but keep their
#'     family so [us_panel()] output can be filtered.
#' }
#'
#' @param transactions A normalized ledger from [us_normalize_transactions()].
#' @param measure Money measure, see [us_money_column()].
#' @return The ledger with `amount` (the bookable amount under `measure`),
#'   `amount_sign` (`"positive"`, `"negative"`, `"zero"`), and `in_revenue`.
#' @export
#' @examples
#' tx <- us_normalize_transactions(us_sample_extract()$transactions)
#' lg <- us_ledger(tx)
#' lg[, .(n = .N, total = sum(amount)), by = amount_sign]
us_ledger <- function(transactions, measure = c("obligation", "pragmatic")) {
  stopifnot(is.data.frame(transactions))
  measure <- match.arg(measure)
  col <- us_money_column(measure)
  if (!col %in% names(transactions)) {
    us_abort("{.arg transactions} has no {.field {col}} column.")
  }
  x <- data.table::copy(data.table::as.data.table(transactions))
  x[, "amount" := data.table::fifelse(is.na(x[[col]]), 0, x[[col]])]
  x[, "amount_sign" := data.table::fcase(amount > 0, "positive",
                                         amount < 0, "negative",
                                         default = "zero")]
  ## everything with a real obligation is revenue; loans contribute through
  ## their (zero) obligation, never their face value
  x[, "in_revenue" := TRUE]
  x[]
}

#' Net an award ledger into organization x award x year records
#'
#' The central aggregation: collapses signed transactions into one row per
#' organization, award and year, under an explicit de-obligation policy.
#'
#' @section The de-obligation policy:
#' A claw-back recorded in 2024 against money obligated in 2021 can be booked
#' two ways, and neither is wrong:
#' \describe{
#'   \item{`"as_posted"` (default)}{Book every action in the year it happened.
#'     Cash-basis-like; matches USAspending's presentation; each year is
#'     reproducible from that year's transactions. A large reversal can drive a
#'     year negative.}
#'   \item{`"restate"`}{Push each award's negative amounts back against that
#'     award's positive years, latest-first (LIFO). Accrual-like; cleaner
#'     "what was this year's cohort ultimately worth"; but last year's figure
#'     changes when this year's data arrives. Transactions do not identify what
#'     they reverse, so LIFO within the award is the matching rule, applied
#'     uniformly.}
#'   \item{`"drop"`}{Discard negatives. Overstates every affected year; exists
#'     only so the overstatement can be measured, and warns.}
#' }
#'
#' @param ledger Output of [us_ledger()].
#' @param org_map Output of [us_org_map()]. Transactions whose `recipient_uei`
#'   is not in the map are dropped (with a message) -- text matching on the API
#'   returns stray recipients, and an award's history can include years when it
#'   belonged to a different organization.
#' @param period `"calendar"` (default) or `"fiscal"`.
#' @param deobligation_policy `"as_posted"`, `"restate"`, or `"drop"`.
#' @param fill_gaps Emit zero rows for org-award-years with no activity between
#'   an award's first and last year.
#' @return A `data.table` at organization x award x year grain with gross
#'   positive, gross negative and net obligations, loan columns, and counts.
#' @export
us_net_by_year <- function(ledger, org_map,
                           period = c("calendar", "fiscal"),
                           deobligation_policy = c("as_posted", "restate", "drop"),
                           fill_gaps = FALSE) {
  stopifnot(is.data.frame(ledger), is.data.frame(org_map))
  period <- match.arg(period)
  deobligation_policy <- match.arg(deobligation_policy)
  if (deobligation_policy == "drop") {
    cli::cli_warn(c("{.val drop} discards de-obligations and overstates every affected year.",
                    "i" = "Use it to measure that overstatement, not to publish."))
  }
  for (need in c("amount", "recipient_uei", "award_key")) {
    if (!need %in% names(ledger)) {
      us_abort("{.arg ledger} has no {.field {need}} column; pass the output of {.fn us_ledger}.")
    }
  }

  x <- data.table::as.data.table(ledger)
  om <- data.table::as.data.table(org_map)

  x <- merge(x, om, by.x = "recipient_uei", by.y = "uei", all.x = TRUE)
  n_unmapped <- sum(is.na(x$org_id))
  if (n_unmapped) {
    us_msg("Dropping {n_unmapped} transaction{?s} on {data.table::uniqueN(x[is.na(org_id)]$recipient_uei)} UEI{?s} outside the organization map.")
    x <- x[!is.na(org_id)]
  }
  x[, "year" := if (period == "calendar") action_year else action_fiscal_year]
  x <- x[!is.na(year) & !is.na(award_key)]

  if (deobligation_policy == "drop") x <- x[amount >= 0]

  g <- x[, .(
    n_transactions      = .N,
    n_actions_positive  = sum(amount > 0),
    n_actions_negative  = sum(amount < 0),
    obligation_positive = sum(amount[amount > 0]),
    obligation_negative = sum(amount[amount < 0]),
    obligation_net      = sum(amount),
    loan_face_value     = sum(loan_face_value, na.rm = TRUE),
    loan_subsidy_cost   = sum(loan_subsidy_cost, na.rm = TRUE)
  ), by = .(org_id, award_key, year)]

  if (deobligation_policy == "restate") {
    g <- restate_negatives(g)
  } else {
    g[, "deobligation_prior_year" := 0]
  }

  if (fill_gaps) {
    grid <- g[, .(year = seq(min(year), max(year))), by = .(org_id, award_key)]
    g <- merge(grid, g, by = c("org_id", "award_key", "year"), all.x = TRUE)
    for (cc in setdiff(names(g), c("org_id", "award_key", "year"))) {
      v <- g[[cc]]
      v[is.na(v)] <- 0
      g[, (cc) := v]
    }
  }
  data.table::setorderv(g, c("org_id", "award_key", "year"))
  g[]
}

## Reallocate each award-year's negative obligations back against that award's
## positive years, latest-first. Never crosses an award boundary and never
## crosses organizations. Residual negatives that exceed all prior positives
## stay in the year they were posted (there is nothing left to restate against).
restate_negatives <- function(g) {
  g <- data.table::copy(g)
  g[, "deobligation_prior_year" := 0]
  data.table::setorderv(g, c("org_id", "award_key", "year"))
  parts <- split(g, by = c("org_id", "award_key"), drop = TRUE)
  out <- lapply(parts, function(a) {
    if (nrow(a) < 2L || all(a$obligation_negative >= 0)) {
      a[, "obligation_net" := obligation_positive + obligation_negative]
      return(a)
    }
    pos <- a$obligation_positive
    for (i in seq_len(nrow(a))) {
      neg <- -a$obligation_negative[i]      # positive magnitude to place
      if (neg <= 0) next
      ## absorb into earlier (or same) years, latest first
      for (j in rev(seq_len(i))) {
        if (neg <= 0) break
        take <- min(neg, pos[j])
        if (take > 0) {
          pos[j] <- pos[j] - take
          neg <- neg - take
          if (j < i) {
            a$deobligation_prior_year[j] <- a$deobligation_prior_year[j] - take
            a$obligation_negative[i] <- a$obligation_negative[i] + take
          }
        }
      }
    }
    a[, "obligation_net" := obligation_positive + obligation_negative +
                            deobligation_prior_year]
    a
  })
  data.table::rbindlist(out, use.names = TRUE)
}

#' Aggregate subawards by year
#'
#' @param subawards Normalized subawards from [us_normalize_subawards()].
#' @param period `"calendar"` or `"fiscal"`.
#' @param direction Which flow to aggregate: `"out"` (pass-through paid by the
#'   organization as prime) or `"in"` (subawards received).
#' @return A `data.table` of `prime_award_key`, `year`, amount and count.
#'   For `direction = "in"` the key is the *prime's* award; join to the panel
#'   through the subawardee UEI instead.
#' @export
us_subaward_by_year <- function(subawards, period = c("calendar", "fiscal"),
                                direction = c("out", "in")) {
  stopifnot(is.data.frame(subawards))
  period <- match.arg(period)
  direction <- match.arg(direction)
  if (!"direction" %in% names(subawards)) {
    us_abort(c("{.arg subawards} has no {.field direction} column.",
               "i" = "Run {.fn us_normalize_subawards} first -- direction cannot be inferred without the organization's UEI set."))
  }
  want <- direction
  x <- data.table::as.data.table(subawards)
  x <- x[!is.na(direction) & direction == want]
  if (!nrow(x)) {
    return(data.table::data.table(prime_award_key = character(0), year = integer(0),
                                  amount = numeric(0), n = integer(0),
                                  subawardee_uei = character(0)))
  }
  x[, "year" := if (period == "calendar") subaward_year else subaward_fiscal_year]
  by <- if (direction == "in") c("prime_award_key", "subawardee_uei", "year")
        else c("prime_award_key", "year")
  out <- x[!is.na(year), .(amount = sum(subaward_amount, na.rm = TRUE), n = .N), by = by]
  data.table::setorderv(out, by)
  out[]
}
