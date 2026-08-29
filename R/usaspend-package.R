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
  "recipient_state", "org_state", "w", "total_net", "index", "n_org_rows",
  ## outlays (File C)
  "reporting_fiscal_year", "reporting_fiscal_month", "gross_outlay_amount",
  "transaction_obligated_amount", "fiscal_year", "outlay", "filec_obligation",
  "has_outlay_rows", "outlay_amount", "outlay_coverage", "first_year",
  "oblig", "filec",
  ## outlay imputation
  ".fy_month", ".share", "first_fy", "last_oblig_fy", "first_month",
  "late_start", "dur_bin", "duration", "pop_end_fy", "pop0_end_fy",
  "ext_days", "ext_fy", "money_after_ext", "extended", "funded_ext",
  "reduced", "mod_class", "oblig_positive", "oblig_negative", "tier",
  "linked", "outlay_total", "last_outlay_fy", "sh_prev", "sh_cur",
  "actual", "oblig_fy", "fy", "t", "share", "share_dur", "share_glob",
  "sh", "tmax", "end_fy", "n_periods", "n_awards", "method",
  "outlay_imputed", "imputation_method", "imputation_flags", "fold",
  "in_pop", "pop_n", "timing_model", "timing_as_obligated",
  "timing_even_spread", "y0", "y1"
))
