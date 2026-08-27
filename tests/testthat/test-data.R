# The packaged VUMC example data: schema conformance and internal consistency.

test_that("vumc_transactions matches the canonical schema", {
  expect_identical(names(vumc_transactions), us_schema("transactions")$field)
  expect_equal(nrow(vumc_transactions), 12085L)
  expect_equal(unique(vumc_transactions$recipient_uei), "GYLUH9UXHDX5")
  # the claw-back featured in the accounting vignette is present
  a <- vumc_transactions[award_key == "ASST_NON_U54CA280915_075"]
  expect_true(any(a$federal_action_obligation < -3e6))
  # and reconciles to the reported lifetime total
  expect_equal(sum(a$federal_action_obligation),
               unique(a$award_total_obligated))
})

test_that("vumc_subawards matches the canonical schema", {
  expect_identical(names(vumc_subawards), us_schema("subawards")$field)
  expect_true(all(is.na(vumc_subawards$direction)))   # assigned by normalize
  sb <- suppressMessages(
    us_normalize_subawards(vumc_subawards, org_uei = "GYLUH9UXHDX5"))
  # in and out both present; a handful of rows are VUMC subawarding to its
  # own UEI, correctly classified internal and excluded from both flows
  expect_true(all(c("in", "out") %in% sb$direction))
  expect_false("unrelated" %in% sb$direction)
})

test_that("vumc_panel matches the panel schema and its identities hold", {
  expect_identical(names(vumc_panel), us_schema("panel")$field)
  g <- vumc_panel
  expect_equal(nrow(g), data.table::uniqueN(g[, .(org_id, award_key, year)]))
  expect_equal(g$net_revenue, g$obligation_net - g$subaward_out_amount)
  expect_equal(unique(g$org_id), "35-2528741")
  # fill-gaps placeholders exist and carry pass-through
  expect_gt(g[n_transactions == 0 & subaward_out_amount > 0, .N], 0)
})

test_that("the packaged panel is reproducible from the packaged inputs", {
  ueis <- unique(vumc_transactions$recipient_uei)
  ex <- structure(
    list(transactions = vumc_transactions, subawards = vumc_subawards,
         jobs = NULL,
         meta = list(uei = ueis, years = 2008:2025, source = "api",
                     subawards = "both", extracted_at = Sys.time())),
    class = "usaspend_extract")
  p <- suppressWarnings(suppressMessages(
    us_panel(ex, org_map = data.frame(uei = ueis, org_id = "35-2528741"),
             fill_gaps = TRUE)))
  expect_equal(nrow(p$panel), nrow(vumc_panel))
  expect_equal(sum(p$panel$obligation_net), sum(vumc_panel$obligation_net))
  expect_equal(sum(p$panel$subaward_out_amount),
               sum(vumc_panel$subaward_out_amount))
})
