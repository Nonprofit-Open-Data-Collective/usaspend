# Normalize a raw transaction ledger

Turns harmonized-but-raw transactions into a clean ledger, one row per
real award action, ready for aggregation.

## Usage

``` r
us_normalize_transactions(
  transactions,
  requested_uei = NULL,
  drop_aggregates = TRUE
)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")`. The five
  disruption fields (`transaction_description`,
  `base_and_all_options_value`, `awarding_office_code`/`_name`,
  `pop_potential_end_date`) are optional: extracts harmonized before
  they were added are accepted and the fields filled with `NA`.

- requested_uei:

  Optional character vector of the UEIs actually asked for, used to flag
  strays returned by the API's text matching.

- drop_aggregates:

  Drop assistance `record_type_code` 1.

## Value

A `data.table` matching `us_schema("transactions")` plus
`is_zero_dollar`, `is_deobligation`, `is_stray_uei`, `is_legacy_cdi` and
a character `flags` column. Carries a `usaspend_dropped` attribute
recording what was removed and why.

## What it does

1.  **De-duplicates on `transaction_key`.** Overlapping download batches
    produce exact duplicates. In the pilot, 19,445 of 241,118 assistance
    rows (8.1%) and 1,383 of 60,907 contract rows (2.3%) were
    duplicates, and every single one was a byte-identical copy – same
    amount, same `last_modified_date`. De-duplicating recovered 5,754
    awards that had previously failed the lifetime reconciliation check.

2.  **Drops deleted records.** `correction_delete_code == "D"` means the
    record was withdrawn. Note that `"C"` does *not* mean "superseded by
    something else" – it means this row is itself the correction, and it
    is the current version, so it is kept. 37.6% of pilot assistance
    rows carry `"C"`. A pipeline that drops them would discard a third
    of the data. `"L"` is an undocumented legacy value; in the pilot all
    1,719 instances are Department of Energy records dated 2008-2017.
    They are kept and flagged.

3.  **Drops aggregate records** (`record_type_code == 1`), which are
    county-level rollups with no identified recipient and would
    double-count.

4.  **Keeps zero-dollar actions, flagged.** They are 20% of pilot
    assistance transactions and 30% of contract transactions. They carry
    period-of-performance changes and are how activity is counted.

5.  **Flags anomalies** rather than silently repairing them.

## Examples

``` r
tx <- us_normalize_transactions(us_sample_extract()$transactions)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
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
#> [1] 120
#> 
#> $input
#> [1] 120
#> 
```
