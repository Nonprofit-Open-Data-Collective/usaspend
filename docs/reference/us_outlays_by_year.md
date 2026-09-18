# Collapse File C funding records to annual outlays per award

Turns the period-level funding table into one row per award x federal
fiscal year, applying the cumulative-within-year rule that
`gross_outlay_amount` requires: within each account cell (federal
account x DEFC x object class x program activity x funding agency) the
annual outlay is the **last reported value** of the fiscal year, and the
award-year outlay is the sum over cells. `transaction_obligated_amount`
is incremental, so it sums directly; it is returned as
`filec_obligation` so the caller can check File C against the award's
own transaction ledger – the linkage screen
[`us_add_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_outlays.md)
runs per award.

## Usage

``` r
us_outlays_by_year(funding)
```

## Arguments

- funding:

  A `data.table` matching `us_schema("funding")`, from
  [`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md).

## Value

A `data.table` of `award_key`, `fiscal_year`, `outlay` (NA when the
award-year reported no outlay rows, never a fake zero),
`filec_obligation`, and `n_periods`.

## Details

Years are **federal fiscal years**; File C has no calendar-year form.
