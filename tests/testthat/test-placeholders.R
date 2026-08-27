# These began life as placeholder tests; the functions are now implemented.
# What survives is the contract they pinned: informative validation errors
# fire before anything else, and dangerous options warn.

test_that("input validation gives useful errors", {
  bad <- data.frame(nope = 1)
  expect_error(us_normalize_transactions(bad), "missing")
  expect_error(us_panel(list(x = 1)), "transactions")
  # direction cannot be inferred, so aggregating without it is a hard error
  expect_error(us_subaward_by_year(data.frame(subaward_amount = 1)), "direction")
  expect_error(us_org_year(data.frame()), "usaspend_panel")
  expect_error(us_reconcile(data.frame()), "usaspend_panel")
})

test_that("dropping de-obligations warns", {
  om <- us_org_map("CFFMYPABYAG3")
  lg <- us_ledger(us_normalize_transactions(us_sample_extract()$transactions))
  expect_warning(us_net_by_year(lg, om, deobligation_policy = "drop"),
                 "overstates")
})

test_that("the sample extract prints without error", {
  # cli writes headers and bullets to stderr, so capture messages, not output
  expect_message(print(us_sample_extract()))
})

test_that("batched subaward fetch validates its input offline", {
  expect_error(us_fetch_subawards_batch(data.frame(x = 1)), "award_key")
  # no ids -> empty canonical table, no network touched
  empty <- us_fetch_subawards_batch(
    data.frame(award_key = "K", award_id = NA_character_,
               recipient_uei = "CFFMYPABYAG3"))
  expect_equal(names(empty), us_schema("subawards")$field)
  expect_equal(nrow(empty), 0L)
})
