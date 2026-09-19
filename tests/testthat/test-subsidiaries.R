## Subsidiaries surfaced by the parent-UEI match, simulated on the sample:
## one award is re-attributed to an unrequested UEI whose recorded parent is a
## requested UEI -- what the API returns for a subsidiary like IRG under RTI.

SUB <- "R29FEFR7P8H9"
KEY <- "ASST_NON_HDTRA12310001_097"   # reconciles exactly when complete

sub_extract <- function() {
  ex <- us_sample_extract()
  tx <- data.table::copy(ex$transactions)
  k <- tx$award_key == KEY
  tx$recipient_parent_uei[k] <- tx$recipient_uei[which(k)[1]]
  tx$recipient_uei[k] <- SUB
  ex$transactions <- tx
  ex
}
parent_of_sub <- function(ex) {
  ex$transactions[award_key == KEY, recipient_parent_uei][1]
}

## the subsidiary's own history as a query on its UEI returns it: the rows
## already present (filed under the requested parent) plus an earlier action
## filed under a previous parent, which the parent match never returned
sub_history <- function(ex) {
  own <- data.table::copy(ex$transactions[award_key == KEY])
  early <- own[1]
  early[, `:=`(transaction_key = "pre-acquisition-1",
               recipient_parent_uei = "LLLLLLLLLLL3",
               federal_action_obligation = 5000,
               action_date = as.Date("2019-01-15"))]
  data.table::rbindlist(list(own, early), use.names = TRUE)
}

test_that("us_find_subsidiaries lists parent-matched recipients only", {
  expect_equal(nrow(us_find_subsidiaries(us_sample_extract())), 0L)

  ex <- sub_extract()
  # a stray whose parent was never requested is not a subsidiary
  tx <- ex$transactions
  j <- which(tx$award_key != KEY)[1]
  tx$recipient_uei[j] <- "OTHERUEI0001"
  tx$recipient_parent_uei[j] <- "NOTREQUESTED"
  ex$transactions <- tx

  s <- us_find_subsidiaries(ex)
  expect_equal(s$uei, SUB)
  expect_equal(s$relationship, "subsidiary")
  expect_equal(s$parent_uei, parent_of_sub(ex))
  expect_equal(s$root_uei, parent_of_sub(ex))
  expect_equal(s$org_id, parent_of_sub(ex))
  expect_false(s$extracted)
  expect_equal(s$n_parent_matched, sum(ex$transactions$award_key == KEY))
})

test_that("a subsidiary's own subsidiary rolls up to the same root", {
  ex <- sub_extract()
  tx <- ex$transactions
  j <- which(tx$award_key != KEY)[1]
  tx$recipient_uei[j] <- "GRANDCHILD01"
  tx$recipient_parent_uei[j] <- SUB
  ex$transactions <- tx
  s <- us_find_subsidiaries(ex)
  expect_setequal(s$uei, c(SUB, "GRANDCHILD01"))
  expect_equal(s[uei == "GRANDCHILD01", parent_uei], SUB)
  expect_equal(s[uei == "GRANDCHILD01", root_uei], parent_of_sub(ex))
})

test_that("unextracted subsidiaries stay out of sample, listed in the crosswalk", {
  ex <- sub_extract()
  ex$org_map <- usaspend:::extract_crosswalk(ex)
  p <- suppressWarnings(suppressMessages(us_panel(ex)))
  expect_false(KEY %in% p$panel$award_key)
  expect_false(p$awards[award_key == KEY, in_sample])
  cw <- p$org_map
  expect_equal(cw[uei == SUB, relationship], "subsidiary")
  expect_false(cw[uei == SUB, in_sample])
  expect_equal(cw[uei == SUB, org_id], parent_of_sub(ex))
  r <- suppressWarnings(suppressMessages(us_reconcile(p)))
  expect_equal(r[award_key == KEY, status], "out_of_sample")
})

test_that("extracted subsidiaries join their parent's organization", {
  ex <- sub_extract()
  par <- parent_of_sub(ex)
  cw <- usaspend:::extract_crosswalk(ex)
  cw[uei == SUB, extracted := TRUE]
  ex$org_map <- cw
  ex$meta$uei <- c(ex$meta$uei, SUB)

  # no org_map: the subsidiary inherits the parent's UEI as org_id
  p <- suppressWarnings(suppressMessages(us_panel(ex)))
  expect_true(p$awards[award_key == KEY, in_sample])
  expect_equal(unique(p$panel[award_key == KEY, org_id]), par)
  r <- suppressWarnings(suppressMessages(us_reconcile(p)))
  expect_equal(r[award_key == KEY, status], "ok")

  # an org_map naming only the requested UEIs: the subsidiary follows its root
  om <- data.frame(uei = us_sample_extract()$meta$uei,
                   org_id = c("ORG-A", "ORG-B", "ORG-C"))
  p <- suppressWarnings(suppressMessages(us_panel(ex, org_map = om)))
  expect_equal(unique(p$panel[award_key == KEY, org_id]),
               om$org_id[om$uei == par])

  # an explicit row for the subsidiary wins
  om2 <- rbind(om, data.frame(uei = SUB, org_id = "ORG-IRG"))
  p <- suppressWarnings(suppressMessages(us_panel(ex, org_map = om2)))
  expect_equal(unique(p$panel[award_key == KEY, org_id]), "ORG-IRG")
})

test_that("org_map rows for UEIs outside the extract are reported, not used", {
  ex <- us_sample_extract()
  om <- data.frame(uei = c(ex$meta$uei, "ZZZZZZZZZZZ9"),
                   org_id = c("A", "B", "C", "D"))
  withr::local_options(usaspend.verbose = TRUE)
  expect_message(suppressWarnings(us_panel(ex, org_map = om)), "not in the extract")
})

test_that("us_extract reports subsidiaries it did not pull, and pulls them on request", {
  ex0 <- sub_extract()
  local_mocked_bindings(
    us_download_run = function(uei, ...) {
      data.table::data.table(tag = "main", batch = 1L, n_uei = length(uei),
                             ueis = paste(uei, collapse = ","),
                             file_name = "f", state = "finished",
                             rows = 1L, url = "u")
    },
    us_download_fetch = function(jobs, dest) structure(character(0), fetched = jobs$file_name),
    read_download_dir = function(dir) {
      if (grepl("^sub[0-9]+-", basename(dir))) {
        list(transactions = sub_history(ex0), subawards = us_empty("subawards"))
      } else {
        list(transactions = ex0$transactions, subawards = ex0$subawards)
      }
    })
  dest <- withr::local_tempdir()

  expect_message(
    ex <- us_extract(ex0$meta$uei, years = 2008:2025, source = "api",
                     dest = dest),
    "1 subsidiary UEI .* added to the crosswalk")
  expect_false(ex$org_map[uei == SUB, extracted])
  expect_equal(ex$meta$uei, ex0$meta$uei)
  expect_false(ex$meta$subsidiaries)

  expect_no_message(
    ex <- us_extract(ex0$meta$uei, years = 2008:2025, source = "api",
                     subsidiaries = TRUE, dest = dest),
    message = "added to the crosswalk")
  expect_true(ex$org_map[uei == SUB, extracted])
  expect_setequal(ex$meta$uei, c(ex0$meta$uei, SUB))
  expect_equal(ex$meta$uei_requested, ex0$meta$uei)
  # parent-matched rows are not duplicated; the earlier history is added
  expect_equal(nrow(ex$transactions), nrow(ex0$transactions) + 1L)
  expect_true("pre-acquisition-1" %in% ex$transactions$transaction_key)
  expect_true(any(grepl("subsidiaries-", ex$jobs$tag)))

  p <- suppressWarnings(suppressMessages(us_panel(ex)))
  expect_true(p$awards[award_key == KEY, in_sample])
  expect_equal(sum(p$panel[award_key == KEY, obligation_net]),
               sum(sub_history(ex0)$federal_action_obligation))
})

test_that("us_add_subsidiaries upgrades an existing extract", {
  ex0 <- sub_extract()
  local_mocked_bindings(
    us_download_run = function(uei, ...) {
      data.table::data.table(tag = "main", ueis = paste(uei, collapse = ","), file_name = "f",
                             state = "finished")
    },
    us_download_fetch = function(jobs, dest) structure(character(0), fetched = jobs$file_name),
    read_download_dir = function(dir) {
      list(transactions = sub_history(ex0), subawards = us_empty("subawards"))
    })
  ex <- suppressMessages(us_add_subsidiaries(ex0, dest = withr::local_tempdir()))
  expect_true(ex$org_map[uei == SUB, extracted])
  expect_true(SUB %in% ex$meta$uei)
  expect_error(us_add_subsidiaries(list()), "usaspend_extract")
})

test_that("a finished job whose files never arrived does not count as extracted", {
  # measured: an unzip into a path over Windows' 260-character limit failed
  # silently, and the subsidiary was marked extracted with no rows added
  ex0 <- sub_extract()
  local_mocked_bindings(
    us_download_run = function(uei, ...) {
      data.table::data.table(tag = "main", ueis = paste(uei, collapse = ","),
                             file_name = "f", state = "finished")
    },
    us_download_fetch = function(jobs, dest) structure(character(0), fetched = character(0)),
    read_download_dir = function(dir) {
      list(transactions = us_empty("transactions"), subawards = us_empty("subawards"))
    })
  expect_warning(
    ex <- suppressMessages(us_add_subsidiaries(ex0, dest = withr::local_tempdir())),
    "could not be extracted")
  expect_false(ex$org_map[uei == SUB, extracted])
  expect_false(SUB %in% ex$meta$uei)
})

test_that("us_download_fetch warns when a job cannot be unzipped", {
  d <- withr::local_tempdir()
  withr::local_options(usaspend.cache_dir = d)
  zipdir <- us_cache_dir("jobs")
  writeLines("not a zip", file.path(zipdir, "broken.zip"))
  jobs <- data.table::data.table(state = "finished", url = "u", file_name = "broken.zip")
  expect_warning(f <- suppressMessages(us_download_fetch(jobs, dest = d)), "unzip")
  expect_equal(attr(f, "fetched"), character(0))
})

test_that("report_subsidiaries says what was left out and why", {
  cw <- usaspend:::extract_crosswalk(sub_extract())
  msgs <- testthat::capture_messages(usaspend:::report_subsidiaries(cw))
  txt <- paste(msgs, collapse = " ")
  expect_match(txt, "full transactions have not been extracted")
  expect_match(txt, "out_of_sample")
  expect_match(txt, "org-map")
  cw[, extracted := TRUE]
  expect_silent(usaspend:::report_subsidiaries(cw))
})
