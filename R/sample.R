#' A bundled sample extract
#'
#' A real three-UEI pull from `POST /api/v2/download/transactions/` taken on
#' 2026-08-27 and shipped verbatim, harmonized to the canonical schema on
#' demand. It exists so that the normalization and accounting functions can be
#' developed and tested offline against genuine USAspending output rather than
#' invented data.
#'
#' 152 rows. Small, but it contains most of the awkward cases: an award whose
#' transactions sum exactly to its reported lifetime total, a de-obligating
#' revision, zero-dollar administrative modifications, contract IDV rows with a
#' blank award type code, one award type code carrying two different
#' description strings in the same file, an IDV with a $40M ceiling against $0
#' obligated, and subaward rows that are entirely inbound.
#'
#' See `system.file("extdata/sample/README.md", package = "usaspend")`.
#'
#' @return A `usaspend_extract`.
#' @export
#' @examples
#' ex <- us_sample_extract()
#' ex
#' ex$transactions[, .N, by = .(award_group, action_class)]
us_sample_extract <- function() {
  dir <- system.file("extdata", "sample", package = "usaspend")
  if (!nzchar(dir)) us_abort("Sample data not installed.")
  rd <- function(f) data.table::fread(file.path(dir, f), colClasses = "character",
                                      showProgress = FALSE)
  tx <- data.table::rbindlist(list(
    us_harmonize_transactions(rd("Assistance_PrimeTransactions_sample.csv"),
                              "assistance", "Assistance_PrimeTransactions_sample.csv"),
    us_harmonize_transactions(rd("Contracts_PrimeTransactions_sample.csv"),
                              "contract", "Contracts_PrimeTransactions_sample.csv")),
    use.names = TRUE, fill = TRUE)
  sb <- data.table::rbindlist(list(
    us_harmonize_subawards(rd("Assistance_Subawards_sample.csv"),
                           "assistance", "Assistance_Subawards_sample.csv"),
    us_harmonize_subawards(rd("Contracts_Subawards_sample.csv"),
                           "contract", "Contracts_Subawards_sample.csv")),
    use.names = TRUE, fill = TRUE)
  structure(list(
    transactions = tx,
    subawards    = sb,
    jobs         = data.table::data.table(state = "finished", rows = nrow(tx) + nrow(sb)),
    meta = list(uei = c("CFFMYPABYAG3", "FG8QB99NF8K3", "H7LMD1ANJNN4"),
                years = 2008:2025, award_types = us_award_type_codes("all"),
                source = "bundled sample", subawards = "in",
                extracted_at = as.POSIXct("2026-08-27 06:37:00", tz = "UTC"))
  ), class = "usaspend_extract")
}
