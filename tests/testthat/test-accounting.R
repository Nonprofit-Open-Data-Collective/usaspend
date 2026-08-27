# Accounting rules, tested on the bundled sample (a real 3-UEI extract) plus
# constructed ledgers where the sample lacks the shape.

sample_panel <- function(...) {
  suppressMessages(us_panel(us_sample_extract(), ...))
}

test_that("normalization dedupes and reports what it dropped", {
  tx0 <- us_sample_extract()$transactions
  # duplicate the whole table: everything should collapse back
  tx <- suppressMessages(
    us_normalize_transactions(data.table::rbindlist(list(tx0, tx0))))
  expect_equal(nrow(tx), nrow(tx0))
  d <- attr(tx, "usaspend_dropped")
  expect_equal(d$duplicate, nrow(tx0))
  expect_false(any(duplicated(tx$transaction_key[!is.na(tx$transaction_key)])))
})

test_that("correction records are kept, deletes are dropped", {
  tx0 <- us_sample_extract()$transactions[1:4]
  tx0[, correction_delete_code := c("C", "D", NA, "L")]
  # make keys unique so dedup does not interfere
  tx0[, transaction_key := paste0("K", 1:4)]
  tx <- suppressMessages(us_normalize_transactions(tx0))
  expect_equal(nrow(tx), 3L)                       # only the D row dropped
  expect_false("K2" %in% tx$transaction_key)
  expect_true(tx[transaction_key == "K4", is_legacy_cdi])
})

test_that("the ledger books on sign, not action class", {
  lg <- us_ledger(suppressMessages(
    us_normalize_transactions(us_sample_extract()$transactions)))
  # the sample's -310,999 REVISION must be negative in the ledger
  expect_true(lg[action_class == "revision" & amount < -300000, .N] >= 1)
  expect_setequal(unique(lg$amount_sign), c("positive", "negative", "zero"))
})

test_that("as_posted books the claw-back in the year it happened", {
  p <- sample_panel()
  g <- p$panel[award_key == "ASST_NON_D8732143_075"]
  expect_equal(g[year == 2024, obligation_negative], -310999)
})

test_that("restate pushes reversals onto earlier positive years", {
  g <- data.table::data.table(
    org_id = "X", award_key = "A", year = c(2021L, 2022L, 2024L),
    n_transactions = 1L, n_actions_positive = c(1L, 1L, 0L),
    n_actions_negative = c(0L, 0L, 1L),
    obligation_positive = c(100, 50, 0),
    obligation_negative = c(0, 0, -120),
    obligation_net = c(100, 50, -120),
    loan_face_value = 0, loan_subsidy_cost = 0)
  r <- usaspend:::restate_negatives(g)
  # LIFO: -120 eats all of 2022's 50, then 70 of 2021's 100
  expect_equal(r[year == 2022, deobligation_prior_year], -50)
  expect_equal(r[year == 2021, deobligation_prior_year], -70)
  expect_equal(r[year == 2024, obligation_net], 0)
  # total is conserved
  expect_equal(sum(r$obligation_net), sum(g$obligation_net))
})

test_that("restate leaves an unabsorbable residual where it was posted", {
  g <- data.table::data.table(
    org_id = "X", award_key = "A", year = c(2021L, 2022L),
    n_transactions = 1L, n_actions_positive = c(1L, 0L),
    n_actions_negative = c(0L, 1L),
    obligation_positive = c(30, 0), obligation_negative = c(0, -100),
    obligation_net = c(30, -100),
    loan_face_value = 0, loan_subsidy_cost = 0)
  r <- usaspend:::restate_negatives(g)
  expect_equal(r[year == 2021, obligation_net], 0)
  expect_equal(r[year == 2022, obligation_net], -70)
  expect_equal(sum(r$obligation_net), -70)
})

test_that("the panel reproduces the award lifetime identity on the sample", {
  p <- sample_panel()
  a <- p$panel[award_key == "ASST_NON_HDTRA12310001_097"]
  expect_equal(sum(a$obligation_net), 1300000)
  r <- suppressMessages(us_reconcile(p))
  expect_equal(r[award_key == "ASST_NON_HDTRA12310001_097", status], "ok")
})

test_that("panel grain is unique and net splits into gross parts", {
  p <- sample_panel()
  g <- p$panel
  expect_equal(nrow(g), data.table::uniqueN(g[, .(org_id, award_key, year)]))
  expect_equal(g$obligation_net, g$obligation_positive + g$obligation_negative +
                 g$deobligation_prior_year)
})

test_that("inbound subawards do not contaminate pass-through", {
  p <- sample_panel()
  # every subaward row in the sample is inbound; none may appear as outbound
  expect_equal(sum(p$panel$subaward_out_amount), 0)
  expect_gt(nrow(p$subawards_in), 0)
  # and net_revenue therefore equals obligation_net
  expect_equal(p$panel$net_revenue, p$panel$obligation_net)
})

test_that("subaward direction classification handles all four cases", {
  sb <- us_sample_extract()$subawards[1:4]
  sb[, prime_uei      := c("AAAAAAAAAAA1", "CFFMYPABYAG3", "CFFMYPABYAG3", "AAAAAAAAAAA1")]
  sb[, subawardee_uei := c("CFFMYPABYAG3", "AAAAAAAAAAA1", "CFFMYPABYAG3", "BBBBBBBBBBB1")]
  sb[, subaward_key := paste0("S", 1:4)]
  out <- suppressMessages(us_normalize_subawards(sb, org_uei = "CFFMYPABYAG3"))
  expect_equal(out[order(subaward_key)]$direction,
               c("in", "out", "internal", "unrelated"))
})

test_that("org rollup conserves totals", {
  p <- sample_panel()
  oy <- us_org_year(p)
  expect_equal(sum(oy$obligation_net), sum(p$panel$obligation_net))
  byfam <- us_org_year(p, by = "award_family")
  expect_equal(sum(byfam$obligation_net), sum(p$panel$obligation_net))
})

test_that("the audit runs clean on the sample", {
  a <- us_audit(sample_panel())
  expect_equal(a[check == "duplicate grain rows", value], "0")
  expect_equal(a[check == "awards attributed to >1 organization", value], "0")
  expect_false(any(a$status == "warn" &
                     a$check %in% c("duplicate grain rows",
                                    "duplicate transaction keys after normalization")))
})

test_that("fiscal period shifts October actions into the next year", {
  p_cal <- sample_panel(period = "calendar")
  p_fy  <- sample_panel(period = "fiscal")
  # totals conserved across period bases
  expect_equal(sum(p_cal$panel$obligation_net), sum(p_fy$panel$obligation_net))
  expect_equal(unique(p_fy$panel$year_basis), "fiscal")
})

test_that("fill_gaps attaches subawards dated outside prime activity", {
  ex <- us_sample_extract()
  # invent an outbound subaward on a real award, dated after its last action
  sb <- ex$subawards[1]
  sb[, `:=`(prime_award_key = "ASST_NON_HDTRA12310001_097",
            prime_uei = "H7LMD1ANJNN4",          # this award's recipient
            subawardee_uei = "AAAAAAAAAAA1",
            subaward_amount = 50000,
            subaward_action_date = as.Date("2026-06-01"),
            subaward_year = 2026L, subaward_fiscal_year = 2026L,
            subaward_key = "orphan-test-1")]
  ex$subawards <- data.table::rbindlist(list(ex$subawards, sb), use.names = TRUE)
  ex$meta$subawards <- "both"

  p0 <- suppressWarnings(suppressMessages(us_panel(ex)))
  p1 <- suppressWarnings(suppressMessages(us_panel(ex, fill_gaps = TRUE)))

  # without fill_gaps the 2026 subaward has no row and is dropped
  expect_equal(sum(p0$panel$subaward_out_amount), 0)
  # with fill_gaps it lands on a zero-obligation row and hits net_revenue
  row <- p1$panel[award_key == "ASST_NON_HDTRA12310001_097" & year == 2026L]
  expect_equal(nrow(row), 1L)
  expect_equal(row$obligation_net, 0)
  expect_equal(row$subaward_out_amount, 50000)
  expect_equal(row$net_revenue, -50000)
  expect_equal(row$org_id, "H7LMD1ANJNN4")
  # award attributes still attach to the synthetic row
  expect_equal(row$award_group, "assistance")
  # grain stays unique and the identity holds everywhere
  g <- p1$panel
  expect_equal(nrow(g), data.table::uniqueN(g[, .(org_id, award_key, year)]))
  expect_equal(g$net_revenue, g$obligation_net - g$subaward_out_amount)
})

test_that("fill_gaps also zero-fills interior years of an award's life", {
  p1 <- suppressMessages(us_panel(us_sample_extract(), fill_gaps = TRUE))
  a <- p1$panel[award_key == "ASST_NON_HDTRA12310001_097"][order(year)]
  # actions in 2022, 2024, 2025 -> 2023 must exist as a zero row
  expect_true(2023L %in% a$year)
  expect_equal(a[year == 2023L, obligation_net], 0)
  # totals unchanged by the padding
  p0 <- suppressMessages(us_panel(us_sample_extract()))
  expect_equal(sum(p1$panel$obligation_net), sum(p0$panel$obligation_net))
})

test_that("a multi-org award-year does not double-count pass-through", {
  ex <- us_sample_extract()
  # give one award a second recipient org by remapping one UEI, then attach
  # an outbound subaward to that award-year
  sb <- ex$subawards[1]
  sb[, `:=`(prime_award_key = "ASST_NON_HDTRA12310001_097",
            prime_uei = "H7LMD1ANJNN4", subawardee_uei = "AAAAAAAAAAA1",
            subaward_amount = 10000,
            subaward_action_date = as.Date("2024-03-01"),
            subaward_year = 2024L, subaward_fiscal_year = 2024L,
            subaward_key = "dupe-test-1")]
  ex$subawards <- data.table::rbindlist(list(ex$subawards, sb), use.names = TRUE)
  ex$meta$subawards <- "both"
  # split the award's transactions across two synthetic orgs in the same year
  tx <- ex$transactions
  k <- tx$award_key == "ASST_NON_HDTRA12310001_097" & tx$action_year == 2024
  stopifnot(sum(k) >= 2)
  tx$recipient_uei[which(k)[1]] <- "ZZZZZZZZZZZ9"
  ex$transactions <- tx
  ex$meta$uei <- c(ex$meta$uei, "ZZZZZZZZZZZ9")

  p <- suppressWarnings(suppressMessages(us_panel(ex)))
  a24 <- p$panel[award_key == "ASST_NON_HDTRA12310001_097" & year == 2024L]
  expect_equal(nrow(a24), 2L)                       # two org rows, one award-year
  expect_equal(sum(a24$subaward_out_amount), 10000) # counted once, not twice
})
