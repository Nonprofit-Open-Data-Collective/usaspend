# Annual outlays from File C: the cumulative-within-year aggregation rule and
# the panel attachment, tested on constructed funding tables (no network).

fiscal_panel <- function(...) {
  suppressMessages(us_panel(us_sample_extract(), period = "fiscal", ...))
}

## A synthetic funding table for one award: two account cells, monthly
## cumulative outlays across two fiscal years, plus incremental obligations.
make_funding <- function(key) {
  f <- us_empty("funding")
  add <- function(fy, month, account, oblig = NA_real_, outlay = NA_real_) {
    data.table::data.table(
      award_key = key, reporting_fiscal_year = as.integer(fy),
      reporting_fiscal_quarter = as.integer(ceiling(month / 3)),
      reporting_fiscal_month = as.integer(month),
      is_quarterly_submission = FALSE,
      federal_account = account, account_title = NA_character_,
      disaster_emergency_fund_code = NA_character_,
      object_class = "41.0", object_class_name = NA_character_,
      program_activity_code = "1", program_activity_name = NA_character_,
      funding_agency_id = "806", funding_agency_name = NA_character_,
      transaction_obligated_amount = oblig, gross_outlay_amount = outlay)
  }
  data.table::rbindlist(list(
    f,
    ## FY2023: account A obligates 100, outlays climb 10 -> 60 (cumulative);
    ## account B obligates 40, outlays flat at 15
    add(2023, 2, "019-1031", oblig = 100),
    add(2023, 4, "019-1031", outlay = 10),
    add(2023, 8, "019-1031", outlay = 45),
    add(2023, 12, "019-1031", outlay = 60),
    add(2023, 6, "075-0943", oblig = 40),
    add(2023, 9, "075-0943", outlay = 15),
    add(2023, 12, "075-0943", outlay = 15),
    ## FY2024: cumulative RESETS; only account A keeps paying
    add(2024, 3, "019-1031", outlay = 20),
    add(2024, 9, "019-1031", outlay = 35)
  ), use.names = TRUE)
}

test_that("us_outlays_by_year applies last-cumulative-per-cell, then sums cells", {
  ann <- us_outlays_by_year(make_funding("A1"))
  # FY2023 = 60 (last of cell A) + 15 (last of cell B), never the period sum
  expect_equal(ann[fiscal_year == 2023, outlay], 75)
  # FY2024 resets: 35, not 60 + 35
  expect_equal(ann[fiscal_year == 2024, outlay], 35)
  # File C obligations are incremental and sum directly
  expect_equal(ann[fiscal_year == 2023, filec_obligation], 140)
  expect_equal(ann[fiscal_year == 2024, filec_obligation], 0)
})

test_that("us_outlays_by_year handles empty input and missing columns", {
  ann <- us_outlays_by_year(us_empty("funding"))
  expect_equal(nrow(ann), 0L)
  expect_true(all(c("award_key", "fiscal_year", "outlay", "filec_obligation")
                  %in% names(ann)))
  expect_error(us_outlays_by_year(data.table::data.table(x = 1)), "missing")
})

test_that("a calendar panel refuses outlays", {
  p <- suppressMessages(us_panel(us_sample_extract()))
  expect_error(us_add_outlays(p, funding = us_empty("funding")), "fiscal")
})

test_that("us_add_outlays grades coverage and never fakes a zero", {
  p <- fiscal_panel()
  keys <- unique(p$panel$award_key)
  # pick a post-2022 award for the linked case if one exists, else any award
  first <- p$panel[, .(fy = min(year)), by = award_key]
  key <- first[order(-fy)][1, award_key]
  fnd <- make_funding(key)
  # make File C obligations reconcile with the award's own ledger
  real <- p$panel[award_key == key, sum(obligation_net)]
  fnd[!is.na(transaction_obligated_amount) & federal_account == "019-1031",
      transaction_obligated_amount := real - 40]

  p2 <- suppressMessages(us_add_outlays(p, funding = fnd))
  pp <- p2$panel

  # untouched money measures
  expect_equal(pp[flags != "outlay_only_year", sum(obligation_net)],
               p$panel[, sum(obligation_net)])
  expect_true(all(c("outlay_amount", "outlay_coverage") %in% names(pp)))

  # the funded award is graded by linkage + era, everything else has no File C
  grade <- unique(pp[award_key == key, outlay_coverage])
  expect_true(grade %in% c("complete", "truncated_pre_FY2022"))
  expect_true(all(pp[award_key != key, outlay_coverage] == "no_file_c"))
  # awards without File C stay NA -- never zero-filled
  expect_true(all(is.na(pp[award_key != key, outlay_amount])))
})

test_that("trailing cash years become outlay_only_year rows, or are reported dropped", {
  p <- fiscal_panel()
  first <- p$panel[, .(fy = min(year)), by = award_key]
  key <- first[order(-fy)][1, award_key]
  last_year <- p$panel[award_key == key, max(year)]

  fnd <- make_funding(key)
  # shift the whole funding history past the award's last panel year
  shift <- (last_year + 2L) - min(fnd$reporting_fiscal_year, na.rm = TRUE)
  fnd[, reporting_fiscal_year := reporting_fiscal_year + shift]
  real <- p$panel[award_key == key, sum(obligation_net)]
  fnd[!is.na(transaction_obligated_amount) & federal_account == "019-1031",
      transaction_obligated_amount := real - 40]

  p2 <- suppressMessages(us_add_outlays(p, funding = fnd, fill_gaps = TRUE))
  extra <- p2$panel[flags == "outlay_only_year"]
  expect_equal(nrow(extra), 2L)                       # the two shifted FYs
  expect_equal(sum(extra$outlay_amount), 75 + 35)     # all cash kept
  expect_true(all(extra$obligation_net == 0))
  expect_true(all(extra$award_key == key))

  p3 <- suppressMessages(us_add_outlays(p, funding = fnd, fill_gaps = FALSE))
  expect_equal(nrow(p3$panel[flags == "outlay_only_year"]), 0L)
  expect_equal(nrow(p3$panel), nrow(p$panel))
})

test_that("an unlinked award is flagged, values kept", {
  p <- fiscal_panel()
  first <- p$panel[, .(fy = min(year)), by = award_key]
  key <- first[order(-fy)][1, award_key]
  fnd <- make_funding(key)
  # force File C obligations far outside the linkage tolerance
  real <- p$panel[award_key == key, sum(obligation_net)]
  fnd[!is.na(transaction_obligated_amount),
      transaction_obligated_amount := real * 10 + 1e6]
  p2 <- suppressMessages(us_add_outlays(p, funding = fnd))
  grade <- unique(p2$panel[award_key == key, outlay_coverage])
  expect_equal(grade, "unlinked")
  # measured values survive the flag
  expect_true(any(!is.na(p2$panel[award_key == key, outlay_amount])))
})

test_that("a failed fetch is never read as no data", {
  p <- fiscal_panel()
  key <- unique(p$panel$award_key)[1]
  fnd <- us_empty("funding")
  data.table::setattr(fnd, "usaspend_failed", key)
  p2 <- suppressMessages(us_add_outlays(p, funding = fnd))
  expect_equal(unique(p2$panel[award_key == key, outlay_coverage]), "fetch_failed")
  expect_true(all(p2$panel[award_key == key, is.na(outlay_amount)]))
})

test_that("us_fetch_outlays returns the canonical empty table on empty input", {
  out <- us_fetch_outlays(character(0))
  expect_equal(names(out), us_schema("funding")$field)
  expect_equal(nrow(out), 0L)
})
