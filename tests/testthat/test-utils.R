test_that("UEIs are cleaned and validated", {
  expect_equal(us_validate_uei("cffmypabyag3"), "CFFMYPABYAG3")
  expect_equal(us_validate_uei(" CFFMYPABYAG3 "), "CFFMYPABYAG3")
  expect_error(us_validate_uei("TOOSHORT"), class = "usaspend_bad_uei")
  expect_warning(x <- us_validate_uei("TOOSHORT", strict = FALSE))
  expect_true(is.na(x))
})

test_that("fiscal years start in October", {
  expect_equal(usaspend:::fiscal_year(as.Date("2024-09-30")), 2024L)
  expect_equal(usaspend:::fiscal_year(as.Date("2024-10-01")), 2025L)
  expect_equal(usaspend:::calendar_year(as.Date("2024-10-01")), 2024L)
})

test_that("numeric coercion tolerates the ways USAspending writes money", {
  expect_equal(usaspend:::as_num(c("1,234.50", "$99", "", "NA", "-310999.00")),
               c(1234.5, 99, NA, NA, -310999))
})

test_that("chunking respects the batch size", {
  expect_length(usaspend:::chunk(letters[1:11], 5), 3L)
  expect_equal(lengths(usaspend:::chunk(letters[1:11], 5)), c(5L, 5L, 1L))
  expect_length(usaspend:::chunk(character(0), 5), 0L)
})

test_that("org mapping defaults each UEI to its own organization", {
  m <- us_org_map(c("CFFMYPABYAG3", "H7LMD1ANJNN4"))
  expect_equal(m$org_id, m$uei)
})

test_that("org mapping collapses multiple UEIs onto one organization", {
  xw <- data.frame(uei = c("CFFMYPABYAG3", "H7LMD1ANJNN4"),
                   org_id = c("13-5562308", "13-5562308"))
  m <- us_org_map(c("CFFMYPABYAG3", "H7LMD1ANJNN4"), xw)
  expect_equal(unique(m$org_id), "13-5562308")
})

test_that("unmapped UEIs warn rather than vanish", {
  xw <- data.frame(uei = "CFFMYPABYAG3", org_id = "13-5562308")
  expect_warning(m <- us_org_map(c("CFFMYPABYAG3", "H7LMD1ANJNN4"), xw))
  expect_equal(nrow(m), 2L)
  expect_false(anyNA(m$org_id))
})

test_that("outlays are refused rather than approximated", {
  expect_equal(us_money_column("obligation"), "federal_action_obligation")
  expect_equal(us_money_column("pragmatic"), "pragmatic_obligation")
  expect_error(us_money_column("outlay"), "not available")
})

test_that("the extract planner recommends a path", {
  p <- us_extract_plan(rep("CFFMYPABYAG3", 10), years = 2020:2025)
  expect_equal(attr(p, "recommended"), "api")
  big <- us_extract_plan(sprintf("%012d", 1:60000), years = 2008:2025)
  expect_equal(attr(big, "recommended"), "archive")
})
