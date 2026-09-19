## A quoted multi-line field whose continuation lines each carry a comma, in a
## file with a single data row: enough to fool fread's dialect sniffer into
## "improper quoting" and a 3- or 5-column parse, with or without sep/quote
## pinned. This is the shape of real subaward descriptions.
multiline_csv <- function() {
  txt <- paste0(
    "award_key,description,city,amount,notes,url\n",
    "ASST_1,\"SCOPE OF WORK, COHORT 3\n",
    "ARTS PROMOTION, \n",
    "PUBLIC ART, \n",
    "COMMUNITY EVENTS, \n",
    "EDUCATION, \n",
    "THE \"\"MOON\"\" CENTER.\",ALBANY  ,100.00,,https://x/1\n")
  f <- tempfile(fileext = ".csv")
  writeBin(charToRaw(txt), f)
  f
}

test_that("quoted multi-line fields parse as one row", {
  x <- usaspend:::us_read_csv(multiline_csv())
  expect_equal(dim(x), c(1L, 6L))
  expect_equal(x$award_key, "ASST_1")
  expect_equal(x$description, paste0(
    "SCOPE OF WORK, COHORT 3\nARTS PROMOTION, \nPUBLIC ART, \n",
    "COMMUNITY EVENTS, \nEDUCATION, \nTHE \"MOON\" CENTER."))
  expect_equal(x$city, "ALBANY")  # unquoted whitespace trimmed, as fread does
  expect_equal(x$amount, "100.00")
  expect_equal(x$url, "https://x/1")
  expect_true(all(vapply(x, is.character, TRUE)))
})

test_that("doubled quotes are un-escaped on the fread path too", {
  f <- tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,\"say \"\"hi\"\"\"", "2,\"\"", "3,\"\"\"\"\"\""), f)
  x <- usaspend:::us_read_csv(f)
  expect_equal(x$b, c("say \"hi\"", "", "\"\""))
})

test_that("empty and header-only files read as empty tables", {
  f <- tempfile(fileext = ".csv")
  file.create(f)
  expect_equal(nrow(usaspend:::us_read_csv(f)), 0L)
  writeLines("a,b,c", f)
  x <- usaspend:::us_read_csv(f)
  expect_equal(dim(x), c(0L, 3L))
})

test_that("real subaward files that broke fread parse fully", {
  fx <- test_path("fixtures")
  rd <- function(f) usaspend:::us_read_csv(file.path(fx, f))
  expect_equal(dim(rd("Assistance_Subawards_2026-09-18_H08M53S49_1.csv")), c(1L, 113L))
  expect_equal(dim(rd("Assistance_Subawards_2026-09-18_H10M17S05_1.csv")), c(2L, 113L))
  expect_equal(dim(rd("Contracts_Subawards_2026-09-18_H11M24S50_1.csv")),  c(1L, 118L))

  parts <- usaspend:::read_download_dir(fx)
  expect_equal(nrow(parts$subawards), 4L)
  expect_true(all(grepl("^(ASST|CONT)_", parts$subawards$prime_award_key)))
})
