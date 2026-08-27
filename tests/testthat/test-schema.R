test_that("schemas are internally consistent", {
  for (tb in c("transactions", "subawards", "awards", "panel")) {
    s <- us_schema(tb)
    expect_equal(length(s$field), length(s$type), info = tb)
    expect_false(anyDuplicated(s$field) > 0, info = tb)
    e <- us_empty(tb)
    expect_equal(names(e), s$field, info = tb)
    expect_equal(nrow(e), 0L, info = tb)
  }
})

test_that("us_empty types match the schema", {
  e <- us_empty("transactions")
  expect_type(e$transaction_key, "character")
  expect_type(e$federal_action_obligation, "double")
  expect_s3_class(e$action_date, "Date")
  expect_type(e$action_year, "integer")
})

test_that("the bundled sample harmonizes to the canonical schema", {
  ex <- us_sample_extract()
  expect_s3_class(ex, "usaspend_extract")
  expect_equal(names(ex$transactions), us_schema("transactions")$field)
  expect_equal(names(ex$subawards), us_schema("subawards")$field)
  expect_equal(nrow(ex$transactions), 120L)   # 9 assistance + 111 contract
  expect_equal(nrow(ex$subawards), 32L)       # 29 assistance + 3 contract
})

test_that("harmonization recovers the award lifetime identity", {
  # ASST_NON_HDTRA12310001_097 has eight transactions summing to its reported
  # total_obligated_amount of $1,300,000. If the netting is right this holds
  # exactly; it is the invariant us_reconcile() will check at scale.
  tx <- us_sample_extract()$transactions
  a  <- tx[award_key == "ASST_NON_HDTRA12310001_097"]
  expect_equal(nrow(a), 8L)
  expect_equal(sum(a$federal_action_obligation), 1300000)
  expect_equal(unique(a$award_total_obligated), 1300000)
})

test_that("de-obligations survive harmonization with their sign", {
  tx <- us_sample_extract()$transactions
  expect_true(any(tx$federal_action_obligation < 0))
  neg <- tx[federal_action_obligation < 0]
  expect_true(any(neg$award_group == "assistance"))
  expect_true(any(neg$award_group == "contract"))
})

test_that("contract IDV rows get a type despite a blank award_type_code", {
  tx <- us_sample_extract()$transactions
  idv <- tx[award_family == "idv"]
  expect_gt(nrow(idv), 0L)
  expect_false(any(is.na(idv$award_type_code)))
})

test_that("action classes are assigned family-aware", {
  tx <- us_sample_extract()$transactions
  # contract "C" is FUNDING ONLY, assistance "C" is REVISION
  expect_true(any(tx[award_group == "contract" & action_type_code == "C"]$action_class
                  == "funding_only"))
  expect_true(any(tx[award_group == "assistance" & action_type_code == "C"]$action_class
                  == "revision"))
})

test_that("assistance carries pragmatic obligations and contracts inherit them", {
  tx <- us_sample_extract()$transactions
  # for non-loan assistance the two measures agree
  a <- tx[award_group == "assistance"]
  expect_equal(a$federal_action_obligation, a$pragmatic_obligation)
  # contracts have no such column upstream, so it is filled from the obligation
  cc <- tx[award_group == "contract" & !is.na(federal_action_obligation)]
  expect_equal(cc$federal_action_obligation, cc$pragmatic_obligation)
})

test_that("calendar and fiscal years are both derived and differ at the boundary", {
  tx <- us_sample_extract()$transactions
  oct <- tx[!is.na(action_date) & format(action_date, "%m") >= "10"]
  if (nrow(oct)) expect_true(all(oct$action_fiscal_year == oct$action_year + 1L))
  jan <- tx[!is.na(action_date) & format(action_date, "%m") < "10"]
  if (nrow(jan)) expect_true(all(jan$action_fiscal_year == jan$action_year))
})

test_that("subaward direction is left unset until the org UEI set is known", {
  sb <- us_sample_extract()$subawards
  expect_true(all(is.na(sb$direction)))
  # and every row in this pull is in fact inbound
  q <- c("CFFMYPABYAG3", "FG8QB99NF8K3", "H7LMD1ANJNN4")
  expect_true(all(sb$subawardee_uei %in% q))
  expect_false(any(sb$prime_uei %in% q))
})

test_that("archive-layout contract files with transposed code pairs harmonize identically", {
  ## Measured on FY2015: archive contract CSVs carry action_type_code/action_type
  ## and idv_type_code/idv_type with codes and descriptions in each other's
  ## columns. The harmonizer must detect and un-swap by value shape.
  base <- data.frame(
    contract_transaction_unique_key = c("K1", "K2", "K3"),
    contract_award_unique_key = c("A1", "A2", "A3"),
    award_id_piid = c("P1", "P2", "P3"),
    action_date = c("2015-01-15", "2015-02-15", "2015-03-15"),
    federal_action_obligation = c("100", "200", "0"),
    recipient_uei = rep("CFFMYPABYAG3", 3),
    last_modified_date = rep("2015-06-01", 3),
    stringsAsFactors = FALSE)

  api_layout <- cbind(base,
    action_type_code = c("C", "M", NA),
    action_type = c("FUNDING ONLY ACTION", "OTHER ADMINISTRATIVE ACTION", NA),
    award_type_code = c("D", "D", ""),
    idv_type_code = c(NA, NA, "B"),
    idv_type = c(NA, NA, "IDC"),
    stringsAsFactors = FALSE)
  archive_layout <- cbind(base,
    action_type_code = c("FUNDING ONLY ACTION", "OTHER ADMINISTRATIVE ACTION", NA),
    action_type = c("C", "M", NA),
    award_type_code = c("D", "D", ""),
    idv_type_code = c(NA, NA, "IDC"),
    idv_type = c(NA, NA, "B"),
    stringsAsFactors = FALSE)

  a <- suppressMessages(us_harmonize_transactions(api_layout, "contract"))
  b <- suppressMessages(us_harmonize_transactions(archive_layout, "contract"))

  expect_equal(a$action_type_code, b$action_type_code)
  expect_equal(a$action_class, b$action_class)
  expect_equal(a$award_type_code, b$award_type_code)
  expect_equal(b$action_type_code, c("C", "M", NA))
  expect_equal(b$action_class[1:2], c("funding_only", "administrative"))
  ## the blank-award-type IDV row must classify from the (un-swapped) idv code
  expect_equal(b$award_type_code[3], "IDV_B")
  expect_equal(b$award_family[3], "idv")
})
