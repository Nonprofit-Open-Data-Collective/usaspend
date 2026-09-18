test_that("termination, reduction, delay and transfer flags fire on the right rows", {
  x <- data.table::data.table(
    award_key = "A", award_group = "contract",
    modification_number = c("0", "P1", "P2", "P3", "P4"),
    action_date = as.Date(c("2023-01-01", "2024-01-01", "2025-02-10", "2025-03-01", "2025-06-01")),
    federal_action_obligation = c(100, 50, 0, -40, 0),
    pop_end_date = as.Date(c("2027-12-31", "2027-12-31", "2027-12-31", "2025-03-31", "2025-03-31")),
    action_type_code = c(NA, "C", "F", "C", "T"),
    action_class = c(NA, NA, "termination", NA, "administrative"),
    transaction_description = c("BASE", "INCREMENTAL FUNDING", "NOTICE OF TERMINATION FOR CONVENIENCE",
                                "DE-OBLIGATE", "TRANSFER"),
    base_and_all_options_value = c(1000, 0, 0, -500, 0),
    awarding_agency_name = c("USAID", "USAID", "USAID", "USAID", "State"),
    recipient_uei = "U1")
  f <- us_disruption_flags(x)
  expect_equal(f$dsr_term_code, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(f$dsr_term_text, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_equal(f$dsr_end_cut,   c(FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_equal(f$dsr_early_deob, c(FALSE, FALSE, FALSE, TRUE, FALSE))  # before the 2027 end in force
  expect_equal(f$dsr_ceiling_cut, c(FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_equal(f$dsr_transfer, c(FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_equal(f$dsr_agency_change, c(FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_equal(f$sched_end[4], as.Date("2027-12-31"))
})

test_that("'determination' is not a termination and rescissions are caught", {
  x <- data.table::data.table(
    award_key = c("A", "A"), award_group = "assistance", modification_number = c("0", "1"),
    action_date = as.Date(c("2025-01-01", "2025-06-01")), federal_action_obligation = 0,
    pop_end_date = as.Date("2026-01-01"), action_type_code = "C",
    transaction_description = c("DETERMINATION OF ALLOWABLE COSTS",
                                "TO RESCIND THE TERMINATION NOTICE AND REINSTATE THE AWARD"))
  f <- us_disruption_flags(x)
  expect_false(f$dsr_term_text[1])
  expect_true(f$dsr_rescinded[2])
  expect_false(any(f$dsr_term_code))          # assistance has no termination code
})

test_that("routine closeout de-obligations and extensions are distinguished", {
  x <- data.table::data.table(
    award_key = "B", award_group = "assistance", modification_number = c("0", "1", "2"),
    action_date = as.Date(c("2020-01-01", "2022-06-01", "2024-03-01")),
    federal_action_obligation = c(100, 0, -5),
    pop_end_date = as.Date(c("2022-12-31", "2023-12-31", "2023-12-31")),
    action_type_code = c("A", "C", "D"))
  f <- us_disruption_flags(x)
  expect_equal(f$dsr_extension, c(FALSE, TRUE, FALSE))
  expect_false(f$dsr_early_deob[3])           # after the scheduled end: closeout
  expect_true(all(!f$dsr_ceiling_cut))        # no ceiling on assistance
})

test_that("works on the bundled sample and on pre-disruption-field extracts", {
  tx <- suppressMessages(us_normalize_transactions(us_sample_extract()$transactions))
  f <- us_disruption_flags(tx)
  expect_equal(nrow(f), nrow(tx))
  expect_true(all(grepl("^dsr_", grep("^dsr_", names(f), value = TRUE))))
  expect_length(grep("^dsr_", names(f)), 14L)
  old <- suppressMessages(us_normalize_transactions(vumc_transactions))
  expect_silent(us_disruption_flags(old))
})
