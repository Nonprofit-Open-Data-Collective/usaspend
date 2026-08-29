## The canonical schema is the contract that lets the API path and the annual
## archive path be interchangeable. Both raw sources are harmonized to these
## columns before any normalization or accounting runs, so downstream code never
## has to know where a row came from.
##
## Column names below were taken from a live extract on 2026-08-27
## (POST /api/v2/download/transactions/), not from documentation:
##   Assistance_PrimeTransactions  112 columns
##   Contracts_PrimeTransactions   297 columns
##   Assistance_Subawards          113 columns
##   Contracts_Subawards           118 columns

us_schema_spec <- function() {

  ## Each schema is written as field = type pairs rather than as two parallel
  ## vectors. Parallel vectors drift: an off-by-one in a rep() count silently
  ## retypes every column after it, and the mistake only surfaces much later as
  ## a column-count mismatch.
  D <- function(...) {
    v <- c(...)
    data.table::data.table(field = names(v), type = unname(v))
  }
  chr <- "character"; num <- "numeric"; int <- "integer"; dat <- "Date"
  lgl <- "logical"
  list(
    transactions = D(
      transaction_key = chr, award_key = chr, parent_award_id = chr,
      award_group = chr, award_family = chr, award_type_code = chr,
      award_type_label = chr, award_id = chr, award_id_uri = chr,
      modification_number = chr,
      action_date = dat, action_year = int, action_fiscal_year = int,
      action_type_code = chr, action_type_label = chr, action_class = chr,
      correction_delete_code = chr, record_type_code = chr,
      federal_action_obligation = num, pragmatic_obligation = num,
      non_federal_funding_amount = num, loan_face_value = num,
      loan_subsidy_cost = num, award_total_obligated = num,
      award_total_outlayed = num,
      recipient_uei = chr, recipient_name = chr, recipient_parent_uei = chr,
      recipient_state = chr,
      awarding_agency_code = chr, awarding_agency_name = chr,
      awarding_sub_agency_code = chr, awarding_sub_agency_name = chr,
      funding_agency_code = chr, funding_agency_name = chr,
      cfda_number = chr, cfda_title = chr, naics_code = chr, psc_code = chr,
      pop_start_date = dat, pop_end_date = dat, last_modified_date = dat,
      source_file = chr
    ),
    subawards = D(
      subaward_key = chr, prime_award_key = chr, prime_award_id = chr,
      prime_uei = chr, prime_name = chr, prime_parent_uei = chr,
      subawardee_uei = chr, subawardee_name = chr, subawardee_parent_uei = chr,
      subaward_number = chr, subaward_type = chr, subaward_amount = num,
      subaward_action_date = dat, subaward_year = int, subaward_fiscal_year = int,
      report_year = int, report_month = int, report_last_modified = dat,
      prime_award_amount = num, prime_award_total_outlayed = num,
      prime_awarding_agency_name = chr, prime_cfda_numbers = chr,
      direction = chr, source_file = chr
    ),
    awards = D(
      award_key = chr, award_group = chr, award_family = chr,
      award_type_code = chr, award_type_label = chr, award_id = chr,
      parent_award_id = chr,
      recipient_uei = chr, recipient_name = chr, recipient_parent_uei = chr,
      recipient_state = chr,
      awarding_agency_code = chr, awarding_agency_name = chr,
      awarding_sub_agency_name = chr, funding_agency_name = chr,
      cfda_number = chr, cfda_title = chr, naics_code = chr, psc_code = chr,
      base_action_date = dat, latest_action_date = dat,
      pop_start_date = dat, pop_end_date = dat,
      total_obligated = num, total_outlayed = num, potential_value = num,
      subaward_count = num, subaward_total = num,
      n_transactions = int, n_years = int
    ),
    panel = D(
      org_id = chr, award_key = chr, year = int, year_basis = chr,
      award_group = chr, award_family = chr, award_type_code = chr,
      award_type_label = chr,
      awarding_agency_code = chr, awarding_agency_name = chr,
      awarding_sub_agency_name = chr, funding_agency_name = chr,
      cfda_number = chr, naics_code = chr, recipient_state = chr,
      n_transactions = int, n_actions_positive = int, n_actions_negative = int,
      obligation_positive = num, obligation_negative = num, obligation_net = num,
      deobligation_prior_year = num, loan_face_value = num, loan_subsidy_cost = num,
      subaward_out_amount = num, n_subawards_out = int,
      subaward_in_amount = num, n_subawards_in = int,
      net_revenue = num, flags = chr
    ),
    funding = D(
      award_key = chr,
      reporting_fiscal_year = int, reporting_fiscal_quarter = int,
      reporting_fiscal_month = int, is_quarterly_submission = lgl,
      federal_account = chr, account_title = chr,
      disaster_emergency_fund_code = chr,
      object_class = chr, object_class_name = chr,
      program_activity_code = chr, program_activity_name = chr,
      funding_agency_id = chr, funding_agency_name = chr,
      transaction_obligated_amount = num, gross_outlay_amount = num
    )
  )
}

#' Canonical table schemas
#'
#' `usaspend` normalizes every source into four tables. `us_schema()` returns the
#' column contract for one of them; `us_empty()` returns a correctly typed
#' zero-row table, which is what the not-yet-implemented normalization functions
#' will fill.
#'
#' \describe{
#'   \item{`transactions`}{One row per award action. The only grain that supports
#'     an annual panel.}
#'   \item{`subawards`}{One row per FSRS subaward report line.}
#'   \item{`awards`}{One row per prime award -- the spine.}
#'   \item{`panel`}{One row per organization x award x year -- the deliverable.}
#'   \item{`funding`}{One row per account-level (File C) record for an award:
#'     federal account x period, from [us_fetch_outlays()]. The only place
#'     annual outlays exist.}
#' }
#'
#' @param table Which schema to return.
#' @return A `data.table` of `field` and `type` (`us_schema()`), or a zero-row
#'   `data.table` with those columns (`us_empty()`).
#' @export
#' @examples
#' us_schema("panel")
#' str(us_empty("transactions"))
us_schema <- function(table = c("transactions", "subawards", "awards", "panel", "funding")) {
  table <- match.arg(table)
  spec <- us_schema_spec()[[table]]
  if (nrow(spec) == 0L || length(spec$field) != length(spec$type)) {
    us_abort("Schema {.val {table}} is malformed: field and type lengths differ.")
  }
  spec[]
}

#' @rdname us_schema
#' @export
us_empty <- function(table = c("transactions", "subawards", "awards", "panel", "funding")) {
  spec <- us_schema(match.arg(table))
  make <- function(ty) switch(ty,
    character = character(0), numeric = numeric(0),
    integer = integer(0), Date = as.Date(character(0)),
    logical = logical(0), us_abort("Unknown schema type {.val {ty}}."))
  data.table::setDT(stats::setNames(lapply(spec$type, make), spec$field))[]
}

## --- raw -> canonical field maps -------------------------------------------
## Named vector: names are canonical fields, values are raw source columns.
## A canonical field absent from a source map is filled with NA of the right
## type, so the two families stack cleanly.

tx_map_assistance <- function() c(
  transaction_key            = "assistance_transaction_unique_key",
  award_key                  = "assistance_award_unique_key",
  award_id                   = "award_id_fain",
  award_id_uri               = "award_id_uri",
  modification_number        = "modification_number",
  action_date                = "action_date",
  action_type_code           = "action_type_code",
  correction_delete_code     = "correction_delete_indicator_code",
  record_type_code           = "record_type_code",
  award_type_code            = "assistance_type_code",
  federal_action_obligation  = "federal_action_obligation",
  pragmatic_obligation       = "generated_pragmatic_obligations",
  non_federal_funding_amount = "non_federal_funding_amount",
  loan_face_value            = "face_value_of_loan",
  loan_subsidy_cost          = "original_loan_subsidy_cost",
  award_total_obligated      = "total_obligated_amount",
  award_total_outlayed       = "total_outlayed_amount_for_overall_award",
  recipient_uei              = "recipient_uei",
  recipient_name             = "recipient_name",
  recipient_parent_uei       = "recipient_parent_uei",
  recipient_state            = "recipient_state_code",
  awarding_agency_code       = "awarding_agency_code",
  awarding_agency_name       = "awarding_agency_name",
  awarding_sub_agency_code   = "awarding_sub_agency_code",
  awarding_sub_agency_name   = "awarding_sub_agency_name",
  funding_agency_code        = "funding_agency_code",
  funding_agency_name        = "funding_agency_name",
  cfda_number                = "cfda_number",
  cfda_title                 = "cfda_title",
  pop_start_date             = "period_of_performance_start_date",
  pop_end_date               = "period_of_performance_current_end_date",
  last_modified_date         = "last_modified_date"
)

tx_map_contract <- function() c(
  transaction_key            = "contract_transaction_unique_key",
  award_key                  = "contract_award_unique_key",
  award_id                   = "award_id_piid",
  parent_award_id            = "parent_award_id_piid",
  modification_number        = "modification_number",
  action_date                = "action_date",
  action_type_code           = "action_type_code",
  award_type_code            = "award_type_code",
  federal_action_obligation  = "federal_action_obligation",
  award_total_obligated      = "total_dollars_obligated",
  award_total_outlayed       = "total_outlayed_amount_for_overall_award",
  recipient_uei              = "recipient_uei",
  recipient_name             = "recipient_name",
  recipient_parent_uei       = "recipient_parent_uei",
  recipient_state            = "recipient_state_code",
  awarding_agency_code       = "awarding_agency_code",
  awarding_agency_name       = "awarding_agency_name",
  awarding_sub_agency_code   = "awarding_sub_agency_code",
  awarding_sub_agency_name   = "awarding_sub_agency_name",
  funding_agency_code        = "funding_agency_code",
  funding_agency_name        = "funding_agency_name",
  naics_code                 = "naics_code",
  psc_code                   = "product_or_service_code",
  pop_start_date             = "period_of_performance_start_date",
  pop_end_date               = "period_of_performance_current_end_date",
  last_modified_date         = "last_modified_date"
)

sub_map <- function() c(
  prime_award_key            = "prime_award_unique_key",
  prime_uei                  = "prime_awardee_uei",
  prime_name                 = "prime_awardee_name",
  prime_parent_uei           = "prime_awardee_parent_uei",
  subawardee_uei             = "subawardee_uei",
  subawardee_name            = "subawardee_name",
  subawardee_parent_uei      = "subawardee_parent_uei",
  subaward_number            = "subaward_number",
  subaward_type              = "subaward_type",
  subaward_amount            = "subaward_amount",
  subaward_action_date       = "subaward_action_date",
  report_year                = "subaward_sam_report_year",
  report_month               = "subaward_sam_report_month",
  report_last_modified       = "subaward_sam_report_last_modified_date",
  prime_award_amount         = "prime_award_amount",
  prime_award_total_outlayed = "prime_award_total_outlayed_amount",
  prime_awarding_agency_name = "prime_award_awarding_agency_name",
  prime_cfda_numbers         = "prime_award_cfda_numbers_and_titles"
)

## Apply a field map, coerce to the canonical types, fill absent fields.
apply_map <- function(raw, map, table, source_file = NA_character_) {
  spec <- us_schema(table)
  out  <- data.table::data.table(.rows = seq_len(nrow(raw)))
  for (i in seq_along(spec$field)) {
    f <- spec$field[i]; ty <- spec$type[i]
    ## map is a named character vector: [[ ]] on an absent name errors, so
    ## membership has to be checked first
    src <- if (f %in% names(map)) unname(map[[f]]) else NA_character_
    v <- if (!is.na(src) && src %in% names(raw)) raw[[src]] else NA
    out[, (f) := switch(ty,
      character = as_chr(v), numeric = as_num(v),
      integer = as_int(v), Date = as_date(v), v)]
  }
  out[, ".rows" := NULL]
  out[, "source_file" := as_chr(source_file)]
  out[]
}

## The two acquisition paths agree on column NAMES but not always on which
## value lives where. Measured on FY2015 archives vs a same-window API pull:
## the archive CONTRACT files carry the (code, description) pairs
## action_type_code/action_type and idv_type_code/idv_type transposed --
## codes in the description column and descriptions (or mnemonics like "IDC")
## in the code column. Assistance files are not affected. Detected by value
## shape, not by source, so either representation harmonizes correctly.
unswap_code_pair <- function(raw, code_col, desc_col, max_code_chars = 1L) {
  if (!all(c(code_col, desc_col) %in% names(raw))) return(raw)
  looks_code <- function(x) {
    x <- x[!is.na(x) & nzchar(x)]
    if (!length(x)) return(NA)
    mean(nchar(x) <= max_code_chars) > 0.5
  }
  a <- looks_code(raw[[code_col]]); b <- looks_code(raw[[desc_col]])
  if (identical(a, FALSE) && identical(b, TRUE)) {
    us_msg("Raw columns {.field {code_col}}/{.field {desc_col}} arrived transposed (archive layout); un-swapping.")
    data.table::setnames(raw, c(code_col, desc_col), c(desc_col, code_col))
  }
  raw
}

#' Harmonize raw USAspending files to the canonical schema
#'
#' Both acquisition paths -- the REST download endpoint and the annual Award
#' Data Archive -- emit the same underlying CSV layouts, so one harmonizer
#' serves both. Raw columns are read as character and cast explicitly here;
#' nothing is guessed by a CSV reader.
#'
#' One measured divergence between the paths is repaired here: archive
#' *contract* files transpose the `action_type_code`/`action_type` and
#' `idv_type_code`/`idv_type` column pairs (codes and descriptions swap
#' places). The swap is detected from the values themselves and undone before
#' mapping, so both sources classify identically.
#'
#' Derived on the way through:
#' \itemize{
#'   \item `award_group` from the file family (contract vs assistance).
#'   \item `award_type_label` / `award_family` from the code, with `idv_type_code`
#'     as a fallback because contract IDV rows carry a blank award type code.
#'   \item `action_type_label` / `action_class` from the code *and* the family,
#'     because the codes collide across families.
#'   \item `action_year` (calendar) and `action_fiscal_year` from `action_date`.
#'     The fiscal year is recomputed rather than trusting the source column.
#'   \item `pragmatic_obligation`, which USAspending supplies for assistance
#'     (`generated_pragmatic_obligations`, equal to the loan subsidy cost for
#'     loans and to the obligation otherwise) but not for contracts, where the
#'     obligation is copied in.
#' }
#'
#' This is a mechanical reshape. It applies no accounting rules -- no
#' de-duplication, no correction or delete handling, no netting. Those live in
#' [us_normalize_transactions()] and are specified in `ACCOUNTING.md`.
#'
#' @param raw A `data.frame`/`data.table` of raw USAspending columns, read as
#'   character.
#' @param group `"assistance"` or `"contract"`.
#' @param source_file Optional provenance label carried onto every row.
#' @return A `data.table` matching `us_schema("transactions")` or
#'   `us_schema("subawards")`.
#' @export
us_harmonize_transactions <- function(raw, group = c("assistance", "contract"),
                                      source_file = NA_character_) {
  group <- match.arg(group)
  raw <- data.table::as.data.table(raw)
  if (group == "contract") {
    raw <- unswap_code_pair(raw, "action_type_code", "action_type")
    raw <- unswap_code_pair(raw, "idv_type_code", "idv_type")
  }
  map <- if (group == "assistance") tx_map_assistance() else tx_map_contract()
  out <- apply_map(raw, map, "transactions", source_file)

  out[, "award_group" := group]
  ty <- us_classify_award_type(out$award_type_code,
                               idv_type_code = if ("idv_type_code" %in% names(raw)) raw$idv_type_code else NULL)
  out[, c("award_type_code", "award_type_label", "award_family") :=
        list(ty$award_type_code, ty$award_type_label, ty$award_family)]

  ac <- us_classify_action(out$action_type_code, out$award_group)
  out[, c("action_type_label", "action_class") :=
        list(ac$action_type_label, ac$action_class)]

  out[, c("action_year", "action_fiscal_year") :=
        list(calendar_year(action_date), fiscal_year(action_date))]

  ## contracts have no generated_pragmatic_obligations column
  out[is.na(pragmatic_obligation), "pragmatic_obligation" := federal_action_obligation]

  out[, "recipient_uei" := clean_uei(out$recipient_uei)]
  out[, "recipient_parent_uei" := clean_uei(out$recipient_parent_uei)]
  data.table::setcolorder(out, us_schema("transactions")$field)
  out[]
}

#' @rdname us_harmonize_transactions
#' @export
us_harmonize_subawards <- function(raw, group = c("assistance", "contract"),
                                   source_file = NA_character_) {
  group <- match.arg(group)
  raw <- data.table::as.data.table(raw)
  out <- apply_map(raw, sub_map(), "subawards", source_file)

  pid <- if (group == "assistance") "prime_award_fain" else "prime_award_piid"
  out[, "prime_award_id" := if (pid %in% names(raw)) as_chr(raw[[pid]]) else NA_character_]

  out[, c("prime_uei", "prime_parent_uei", "subawardee_uei", "subawardee_parent_uei") :=
        list(clean_uei(prime_uei), clean_uei(prime_parent_uei),
             clean_uei(subawardee_uei), clean_uei(subawardee_parent_uei))]

  out[, c("subaward_year", "subaward_fiscal_year") :=
        list(calendar_year(subaward_action_date), fiscal_year(subaward_action_date))]

  ## FSRS has no globally unique subaward id; this composite is stable enough to
  ## de-duplicate on, and duplicates are common because one report is restated
  ## across months.
  out[, "subaward_key" := paste(prime_award_key, subaward_number,
                                format(subaward_action_date), sep = "|")]

  ## direction is unknown until an organization's UEI set is supplied; see
  ## us_normalize_subawards()
  out[, "direction" := NA_character_]
  data.table::setcolorder(out, us_schema("subawards")$field)
  out[]
}
