# Vanderbilt University Medical Center: raw transactions

Every prime award transaction for Vanderbilt University Medical Center
(EIN 35-2528741, UEI `GYLUH9UXHDX5`), FY2008–FY2025, exactly as it comes
back from the acquisition layer: harmonized to
`us_schema("transactions")` but **not yet normalized**. (This single-UEI
pull happens to contain no batch duplicates – those arise when UEIs are
spread across overlapping download jobs – but the normalization flags
still have work to do: 1,422 of the 12,085 rows are de-obligations and
2,816 are zero-dollar administrative actions.)

## Usage

``` r
vumc_transactions
```

## Format

A `data.table` with 12,085 rows matching `us_schema("transactions")`.
Key fields:

- transaction_key:

  Unique id of the award action (dedup key).

- award_key:

  Generated unique award id; groups modifications into awards.

- award_group, award_family, award_type_code, award_type_label:

  Contract vs assistance, and the finer type (project grant, definitive
  contract, IDV, ...).

- modification_number, action_date, action_year, action_fiscal_year:

  When the action happened; both year bases are derived from
  `action_date`.

- action_type_code, action_type_label, action_class:

  What the action claims to be (new, continuation, revision, ...),
  classified per family because the codes collide across families.

- correction_delete_code, record_type_code:

  FABS correction/delete indicator and record type; drive the
  normalization rules.

- federal_action_obligation:

  The signed dollars committed by this action – the money column.
  Negative rows are real claw-backs.

- pragmatic_obligation:

  USAspending's derived measure (equals the obligation except for
  loans).

- loan_face_value, loan_subsidy_cost, non_federal_funding_amount:

  Loan and cost-share amounts; never revenue.

- award_total_obligated, award_total_outlayed:

  Award-lifetime totals as reported by USAspending; the reconciliation
  reference.

- recipient_uei, recipient_name, recipient_parent_uei, recipient_state:

  Who received it, as registered at action time.

- awarding_agency_code/name, awarding_sub_agency_code/name,
  funding_agency_code/name:

  Who awarded and who funded.

- cfda_number, cfda_title, naics_code, psc_code:

  Program (assistance) and industry/product (contract) classifiers.

- pop_start_date, pop_end_date:

  Period of performance.

- last_modified_date, source_file:

  Provenance.

This object predates the five disruption fields added to the canonical
schema (`transaction_description`, `base_and_all_options_value`,
`awarding_office_code`, `awarding_office_name`,
`pop_potential_end_date`);
[`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md)
fills them with `NA`. See
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md)
for what they are for.

## Details

VUMC was chosen as the packaged example because it exercises every
accounting rule at once: 2,166 awards across grants and contracts, 1,422
de-obligation (claw-back) rows, \$2.2bn of outbound pass-through (about
45% of everything it receives – the highest share in the 50-org pilot),
and \$0.6bn received as a subawardee.

Pulled from `POST /api/v2/download/transactions/` on 2026-08-27. Public
federal award data.

## See also

[vumc_subawards](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_subawards.md),
[vumc_panel](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_panel.md),
[`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md),
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)

## Examples

``` r
# raw vs normalized row counts: the duplicates are still in here
nrow(vumc_transactions)
#> [1] 12085
tx <- us_normalize_transactions(vumc_transactions)
#> Normalized 12085 -> 12085 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 470 rows flagged
attr(tx, "usaspend_dropped")
#> $deleted
#> [1] 0
#> 
#> $aggregate
#> [1] 0
#> 
#> $duplicate
#> [1] 0
#> 
#> $kept
#> [1] 12085
#> 
#> $input
#> [1] 12085
#> 
```
