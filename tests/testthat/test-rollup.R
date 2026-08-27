# Roll-ups and inflation adjustment, on the bundled sample.

rp <- function(...) suppressMessages(us_panel(us_sample_extract(), ...))

test_that("default rollup is one row per org, totals conserved", {
  p <- rp()
  r <- us_rollup(p)
  expect_equal(nrow(r), data.table::uniqueN(p$panel$org_id))
  expect_equal(sum(r$obligation_net), sum(p$panel$obligation_net))
  expect_equal(sum(r$subaward_in_amount), sum(p$subawards_in$subaward_in_amount))
  expect_equal(r$total_net,
               r$obligation_net + r$subaward_in_amount - r$subaward_out_amount)
})

test_that("year = TRUE gives a trend; org_id = FALSE collapses orgs", {
  p <- rp()
  tr <- us_rollup(p, year = TRUE)
  expect_true(all(c("org_id", "year") %in% names(tr)))
  yr <- us_rollup(p, org_id = FALSE, year = TRUE)
  expect_false("org_id" %in% names(yr))
  expect_equal(sum(yr$obligation_net), sum(p$panel$obligation_net))
  # grand total: no keys at all
  tot <- us_rollup(p, org_id = FALSE)
  expect_equal(nrow(tot), 1L)
  expect_equal(tot$obligation_net, sum(p$panel$obligation_net))
})

test_that("state rollup uses the award state and conserves totals", {
  p <- rp()
  st <- us_rollup(p, org_id = FALSE, state = TRUE)
  expect_true("state" %in% names(st))
  expect_equal(sum(st$obligation_net), sum(p$panel$obligation_net))
  expect_equal(sum(st$subaward_in_amount), sum(p$subawards_in$subaward_in_amount))
})

test_that("inflow-only org-years survive an org x year rollup", {
  p <- rp()
  tr <- us_rollup(p, year = TRUE)
  # the sample's inbound subawards include years with no prime activity rows
  # for that org; those must appear with zero obligations, not vanish
  expect_equal(sum(tr$subaward_in_amount), sum(p$subawards_in$subaward_in_amount))
})

test_that("inflation adjustment rescales by index ratio and tags the result", {
  p <- rp()
  tr <- us_rollup(p, year = TRUE)
  adj <- suppressMessages(us_adjust_inflation(tr, target_year = 2025))
  idx <- us_price_index()
  i25 <- idx[year == 2025]$index
  for (yy in unique(tr$year)) {
    f <- i25 / idx[year == yy]$index
    expect_equal(adj[year == yy]$obligation_net,
                 tr[year == yy]$obligation_net * f)
  }
  # target-year dollars are unchanged
  expect_equal(adj[year == 2025]$obligation_net, tr[year == 2025]$obligation_net)
  a <- attr(adj, "usaspend_inflation")
  expect_equal(a$target_year, 2025L)
  # counts are not money and must not be scaled
  expect_equal(adj$n_transactions, tr$n_transactions)
})

test_that("default target is the last indexed year in the data", {
  p <- rp()
  tr <- us_rollup(p, year = TRUE)
  adj <- suppressMessages(us_adjust_inflation(tr))
  expect_equal(attr(adj, "usaspend_inflation")$target_year,
               max(intersect(tr$year, us_price_index()$year)))
})

test_that("years outside the index error, or go NA under strict = FALSE", {
  x <- data.table::data.table(year = c(2024L, 2030L), obligation_net = c(1, 1))
  expect_error(us_adjust_inflation(x, target_year = 2024), "not in the price index")
  expect_warning(y <- us_adjust_inflation(x, target_year = 2024, strict = FALSE))
  expect_equal(y[year == 2024]$obligation_net, 1)
  expect_true(is.na(y[year == 2030]$obligation_net))
})

test_that("a year-collapsed rollup refuses to deflate", {
  p <- rp()
  r <- us_rollup(p)   # no year column
  expect_error(us_adjust_inflation(r), "year")
})

test_that("adjusting a whole panel touches panel and subawards_in", {
  p <- rp()
  p25 <- suppressMessages(us_adjust_inflation(p, target_year = 2020))
  expect_s3_class(p25, "usaspend_panel")
  expect_equal(p25$meta$inflation$target_year, 2020L)
  idx <- us_price_index()
  f <- idx[year == 2020]$index / idx[year == 2024]$index
  raw <- rp()
  expect_equal(p25$panel[year == 2024]$obligation_net,
               raw$panel[year == 2024]$obligation_net * f)
})

test_that("recipient_state flows through to the panel", {
  p <- rp()
  expect_true("recipient_state" %in% names(p$panel))
  expect_true(any(!is.na(p$panel$recipient_state)))
})
