test_that("award type codes map to families", {
  x <- us_classify_award_type(c("04", "D", "IDV_B", "07", "ZZZ", NA))
  expect_equal(x$award_family,
               c("grant", "contract", "idv", "loan", "unknown", "unknown"))
  expect_equal(x$award_group,
               c("assistance", "contract", "contract", "assistance",
                 "unknown", "unknown"))
})

test_that("blank contract award types fall back to the IDV type", {
  # contract IDV rows carry a blank award_type_code; the type is in idv_type_code
  x <- us_classify_award_type(c(NA, "D"), idv_type_code = c("IDV_C", NA))
  expect_equal(x$award_type_code, c("IDV_C", "D"))
  expect_equal(x$award_family, c("idv", "contract"))
})

test_that("action type codes are interpreted per family", {
  # "B" is CONTINUATION for assistance and SUPPLEMENTAL AGREEMENT for contracts
  x <- us_classify_action(c("B", "B"), c("assistance", "contract"))
  expect_equal(x$action_class, c("continuation", "revision"))

  # "C" is REVISION for assistance and FUNDING ONLY ACTION for contracts
  y <- us_classify_action(c("C", "C"), c("assistance", "contract"))
  expect_equal(y$action_class, c("revision", "funding_only"))

  # "D" collides too
  z <- us_classify_action(c("D", "D"), c("assistance", "contract"))
  expect_equal(z$action_class, c("adjustment", "revision"))
})

test_that("a blank action type is unclassified, not an error", {
  # base contract actions legitimately have no action type
  x <- us_classify_action(c(NA, ""), "contract")
  expect_equal(x$action_class, c("unclassified", "unclassified"))
})

test_that("non-contract families use the assistance code set", {
  x <- us_classify_action("B", c("grant"))
  expect_equal(x$action_class, "continuation")
})

test_that("award type code selection works by family and group", {
  expect_setequal(us_award_type_codes("grant"), c("02", "03", "04", "05"))
  expect_true(all(c("02", "07", "09") %in% us_award_type_codes("assistance")))
  expect_false(any(c("A", "IDV_B") %in% us_award_type_codes("assistance")))
  expect_length(us_award_type_codes("all"), 22)
  expect_error(us_award_type_codes("nonsense"), "No award types")
})
