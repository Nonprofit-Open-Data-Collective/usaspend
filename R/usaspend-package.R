#' @keywords internal
#' @aliases usaspend-package
#' @import data.table
#' @importFrom stats setNames
#' @importFrom utils unzip download.file head tail
"_PACKAGE"

## quiet R CMD check on data.table NSE symbols
utils::globalVariables(c(
  ".", ".N", ".SD", ":=",
  ## join and grouping keys
  "uei", "org_id", "award_key", "award_group", "award_family", "award_type_code",
  "year", "amount", "source_file",
  ## job manifest
  "state", "file_name", "batch", "n_uei", "rows", "url", "tag", "err", "error",
  "is_delta", "present",
  ## transaction ledger
  "action_date", "action_class", "federal_action_obligation",
  "pragmatic_obligation", "is_deobligation",
  ## subaward ledger
  "prime_award_key", "prime_uei", "prime_parent_uei", "subawardee_uei",
  "subawardee_parent_uei", "subaward_number", "subaward_action_date",
  "subaward_count", "direction",
  ## panel and reconciliation
  "action_year", "action_fiscal_year", "action_type_code", "award_type_label",
  "awarding_agency_code", "awarding_agency_name", "awarding_sub_agency_name",
  "base_action_date", "cfda_number", "cfda_title", "correction_delete_code",
  "deobligation_prior_year", "flags", "funding_agency_name", "gap",
  "i.subaward_count", "i.subaward_total", "i.recipient_uei", "latest_action_date",
  "loan_face_value", "loan_subsidy_cost", "n", "N", "n_recipients",
  "award_id", "award_total_obligated", "award_total_outlayed",
  "n_subawards_in", "n_subawards_out", "n_transactions", "naics_code",
  "net_revenue", "obligation_negative", "obligation_net",
  "obligation_positive", "parent_award_id", "pop_end_date", "pop_start_date",
  "psc_code", "recipient_name", "recipient_parent_uei", "recipient_uei",
  "record_type_code", "report_year", "report_last_modified", "status",
  "subaward_amount", "subaward_fiscal_year", "subaward_in_amount",
  "subaward_out_amount", "subaward_year", "subaward_key", "total_obligated",
  "total_outlayed", "transaction_key", "tx_sum", "V1", "is_zero_dollar",
  "amount_sign", "in_revenue", "obligated_in_extract", "last_modified_date",
  "recipient_state", "org_state", "w", "total_net", "index", "n_org_rows"
))
