#' Vanderbilt University Medical Center: raw transactions
#'
#' Every prime award transaction for Vanderbilt University Medical Center
#' (EIN 35-2528741, UEI `GYLUH9UXHDX5`), FY2008--FY2025, exactly as it comes
#' back from the acquisition layer: harmonized to `us_schema("transactions")`
#' but **not yet normalized**. (This single-UEI pull happens to contain no
#' batch duplicates -- those arise when UEIs are spread across overlapping
#' download jobs -- but the normalization flags still have work to do:
#' 1,422 of the 12,085 rows are de-obligations and 2,816 are zero-dollar
#' administrative actions.)
#'
#' VUMC was chosen as the packaged example because it exercises every
#' accounting rule at once: 2,166 awards across grants and contracts, 1,422
#' de-obligation (claw-back) rows, $2.2bn of outbound pass-through (about 45%
#' of everything it receives -- the highest share in the 50-org pilot), and
#' $0.6bn received as a subawardee.
#'
#' Pulled from `POST /api/v2/download/transactions/` on 2026-08-27. Public
#' federal award data.
#'
#' @format A `data.table` with 12,085 rows matching
#'   `us_schema("transactions")`. Key fields:
#' \describe{
#'   \item{transaction_key}{Unique id of the award action (dedup key).}
#'   \item{award_key}{Generated unique award id; groups modifications into
#'     awards.}
#'   \item{award_group, award_family, award_type_code, award_type_label}{
#'     Contract vs assistance, and the finer type (project grant, definitive
#'     contract, IDV, ...).}
#'   \item{modification_number, action_date, action_year,
#'     action_fiscal_year}{When the action happened; both year bases are
#'     derived from `action_date`.}
#'   \item{action_type_code, action_type_label, action_class}{What the action
#'     claims to be (new, continuation, revision, ...), classified per family
#'     because the codes collide across families.}
#'   \item{correction_delete_code, record_type_code}{FABS correction/delete
#'     indicator and record type; drive the normalization rules.}
#'   \item{federal_action_obligation}{The signed dollars committed by this
#'     action -- the money column. Negative rows are real claw-backs.}
#'   \item{pragmatic_obligation}{USAspending's derived measure (equals the
#'     obligation except for loans).}
#'   \item{loan_face_value, loan_subsidy_cost, non_federal_funding_amount}{
#'     Loan and cost-share amounts; never revenue.}
#'   \item{award_total_obligated, award_total_outlayed}{Award-lifetime totals
#'     as reported by USAspending; the reconciliation reference.}
#'   \item{recipient_uei, recipient_name, recipient_parent_uei,
#'     recipient_state}{Who received it, as registered at action time.}
#'   \item{awarding_agency_code/name, awarding_sub_agency_code/name,
#'     funding_agency_code/name}{Who awarded and who funded.}
#'   \item{cfda_number, cfda_title, naics_code, psc_code}{Program (assistance)
#'     and industry/product (contract) classifiers.}
#'   \item{pop_start_date, pop_end_date}{Period of performance.}
#'   \item{last_modified_date, source_file}{Provenance.}
#' }
#' @seealso [vumc_subawards], [vumc_panel], [us_normalize_transactions()],
#'   [us_panel()]
#' @examples
#' # raw vs normalized row counts: the duplicates are still in here
#' nrow(vumc_transactions)
#' tx <- us_normalize_transactions(vumc_transactions)
#' attr(tx, "usaspend_dropped")
"vumc_transactions"

#' Vanderbilt University Medical Center: subaward rows, both directions
#'
#' All FSRS subaward report lines touching VUMC: 3,212 rows from the
#' recipient-filtered bulk download (VUMC as *subawardee* -- inbound), plus
#' 7,182 rows fetched by prime award with [us_fetch_subawards_batch()]
#' (VUMC as *prime* -- outbound pass-through). The two pulls are needed
#' because a recipient-filtered download never returns outbound rows.
#'
#' `direction` is `NA` on purpose: it cannot be inferred from a row alone.
#' [us_normalize_subawards()] assigns it (`in` / `out` / `internal` /
#' `unrelated`) given the organization's UEI set, and de-duplicates the FSRS
#' monthly restatements on `subaward_key`.
#'
#' @format A `data.table` with 10,394 rows matching `us_schema("subawards")`.
#'   Key fields:
#' \describe{
#'   \item{subaward_key}{Composite dedup key (prime award | subaward number |
#'     action date).}
#'   \item{prime_award_key, prime_award_id}{The prime award the money flows
#'     under.}
#'   \item{prime_uei, prime_name}{The prime awardee (VUMC on outbound rows).}
#'   \item{subawardee_uei, subawardee_name}{Who received the subaward (VUMC on
#'     inbound rows). Often `NA` for government subawardees.}
#'   \item{subaward_amount, subaward_action_date, subaward_year,
#'     subaward_fiscal_year}{Committed amount and when it was committed --
#'     the booking basis.}
#'   \item{report_year, report_month, report_last_modified}{FSRS reporting
#'     vintage; lags the action date, sometimes across fiscal years.}
#'   \item{prime_award_amount, prime_awarding_agency_name,
#'     prime_cfda_numbers}{Context carried from the prime award.}
#'   \item{direction}{`NA` until [us_normalize_subawards()] assigns it.}
#' }
#' @seealso [vumc_transactions], [vumc_panel], [us_normalize_subawards()]
#' @examples
#' sb <- us_normalize_subawards(vumc_subawards,
#'                              org_uei = unique(vumc_transactions$recipient_uei))
#' sb[, .(rows = .N, dollars = sum(subaward_amount, na.rm = TRUE)),
#'    by = direction]
"vumc_subawards"

#' Vanderbilt University Medical Center: the finished panel
#'
#' The org x award x year table [us_panel()] produces from
#' [vumc_transactions] and [vumc_subawards], built with
#' `fill_gaps = TRUE` (so every pass-through dollar has a row to land on),
#' calendar-year basis, `as_posted` de-obligation policy. 9,290 rows over
#' 2,166 awards, 2008--2026.
#'
#' This is the deliverable shape: one row per award per year, carrying the
#' awarding agency, award type, gross and net obligations, pass-through paid,
#' and `net_revenue`.
#'
#' @format A `data.table` with 9,290 rows matching `us_schema("panel")`.
#'   Key fields:
#' \describe{
#'   \item{org_id, award_key, year, year_basis}{The grain. `year_basis` is
#'     `"calendar"` here.}
#'   \item{award_group, award_family, award_type_code, award_type_label}{
#'     What kind of award.}
#'   \item{awarding_agency_code/name, awarding_sub_agency_name,
#'     funding_agency_name}{Who awarded and funded it.}
#'   \item{cfda_number, naics_code, recipient_state}{Program / industry /
#'     registered state.}
#'   \item{n_transactions, n_actions_positive, n_actions_negative}{Activity
#'     counts. A row with `n_transactions = 0` is a fill-gaps placeholder --
#'     an interior zero year, or a year holding only pass-through.}
#'   \item{obligation_positive, obligation_negative, obligation_net}{Gross
#'     inflow, gross claw-backs, and their sum. Kept separately so +5M/-4M
#'     is distinguishable from a clean +1M.}
#'   \item{deobligation_prior_year}{Only non-zero under the `restate`
#'     policy; zero throughout this table.}
#'   \item{loan_face_value, loan_subsidy_cost}{Loan amounts, outside revenue.}
#'   \item{subaward_out_amount, n_subawards_out}{Pass-through paid onward
#'     under this award-year.}
#'   \item{subaward_in_amount, n_subawards_in}{Subawards received under this
#'     award (rare at award level; org-level inflows live in the panel
#'     object's `subawards_in` table).}
#'   \item{net_revenue}{`obligation_net - subaward_out_amount`.}
#'   \item{flags}{Anomaly markers.}
#' }
#' @seealso [vumc_transactions], [vumc_subawards], [us_panel()], [us_rollup()]
#' @examples
#' # the pass-through share that made VUMC the packaged example
#' vumc_panel[, .(obligated = sum(obligation_net),
#'                passed_through = sum(subaward_out_amount))]
"vumc_panel"

#' Outlay-imputation ground truth
#'
#' The training set behind the bundled [outlay_model]: 1,184 awards from
#' VUMC plus the 50-nonprofit pilot whose annual File C outlays are fully
#' trustworthy -- File C obligations reconcile with the award's own ledger,
#' and either lifetime outlays match lifetime obligations within 10%
#' (`tier = "reconciled"`, 905 awards) or the award began inside the FY2022
#' monthly reporting mandate with a completed, plateaued cash series
#' (`tier = "shape_complete"`, 279). Built by
#' `data-raw/make-outlay-model.R`; the experiment that designed the screens
#' and picked the model is documented in `IMPUTATION.md`.
#'
#' @format A list of class `usaspend_outlay_training`:
#' \describe{
#'   \item{awards}{One row per candidate award (7,853): the features from
#'     [us_outlay_features()], File C lifetime figures, `linked`, and `tier`
#'     (`NA` for awards that failed the truth screen).}
#'   \item{grid}{One row per ground-truth award x fiscal year: `oblig_fy`
#'     (net obligations booked that year), `actual` (File C outlays), event
#'     time `t`.}
#'   \item{meta}{Screen parameters and build time (`as_of` FY2026).}
#' }
#' @seealso [outlay_model], [us_outlay_training()], [us_impute_fit()],
#'   [us_impute_eval()]
#' @examples
#' outlay_training
#' outlay_training$awards[!is.na(tier), .N, by = .(tier, mod_class)]
"outlay_training"

#' The default liquidation-curve outlay model
#'
#' The model [us_impute_outlays()] uses when none is supplied: empirical
#' liquidation curves (share of net obligations outlaid per event-year, by
#' award duration x late-fiscal-year start, zero-filled estimator) fitted
#' on [outlay_training]. Cross-validated performance: mean misallocation
#' 0.28 (timing) and 0.30 (level + timing) against 0.41/0.43 for even
#' spread and 0.75/0.85 for treating obligations as cash. Durations of 1-5
#' years are inside the support envelope; longer awards fall back to even
#' spread.
#'
#' @format A list of class `usaspend_outlay_model`; see [us_impute_fit()].
#' @seealso [us_impute_outlays()], [us_add_imputed_outlays()],
#'   [us_impute_fit()], [outlay_training]
#' @examples
#' outlay_model
#' # the duration-4 liquidation curve
#' outlay_model$curves_dur[dur_bin == 4]
"outlay_model"
