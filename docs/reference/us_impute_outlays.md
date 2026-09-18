# Impute annual outlays from obligations data

Allocates each award's net obligations across fiscal years as imputed
cash, using a fitted liquidation-curve model where the award's data
supports it and an explicit fallback where it does not. Dollars are
never `NA`: awards outside the model's support envelope get the basic
rule *global outlay/obligation ratio x (net obligations / performance
periods)*, and `imputation_method` says which rule produced each row.

## Usage

``` r
us_impute_outlays(transactions, model = NULL, reconcile = FALSE)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")`, or a precomputed
  feature table from
  [`us_outlay_features()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_features.md).

- model:

  A `usaspend_outlay_model`; `NULL` uses the bundled
  [outlay_model](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_model.md),
  fitted on the packaged experiment's ground truth.

- reconcile:

  Rescale each award's series to sum exactly to its net obligations (see
  the section below). Rows gain the flag `reconciled_to_obligations`.

## Value

A `data.table`, one row per award x fiscal year: `outlay_imputed`
(dollars), event time `t`, `imputation_method` (`"liquidation_curve"` /
`"even_spread"` / `"none"`) and `imputation_flags`.

## When the model steps aside

The model path requires a first-obligation year, positive net
obligations, and a duration the training data supports (at least
`min_cell` ground-truth awards of that duration – the support envelope).
Everything else – missing period-of-performance dates, a missing start
month, durations beyond the envelope – falls back to even spread, with
the reason in `imputation_flags`. An award still in progress is *not* a
fallback case: the curve projects its remaining cash, including fiscal
years after the data pull; those rows simply carry future `fy` values.

## The `reconcile` switch – typical cash versus the accounting identity

By default the imputed series is the **typical payment schedule** given
the obligations: its total is the model's fitted liquidation ratio times
net obligations (globally about 0.94), because that is what completed
awards actually deliver. `reconcile = TRUE` rescales each award's series
so its total equals net obligations **exactly** – re-imposing the
accounting identity that money obligated is eventually either paid or
de-obligated. Use it when the imputed dollars must tie out against the
obligations ledger (modeling government spending or organization
revenue); for an award still in progress the identity holds over the
full projected life, not over any partial window observed to date.

## Examples

``` r
tx <- us_normalize_transactions(us_sample_extract()$transactions)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
imp <- us_impute_outlays(tx)
#> Imputed outlays for 18 awards.
#> • even_spread=8 liquidation_curve=4 none=6
imp[, .(dollars = sum(outlay_imputed)), by = imputation_method]
#>    imputation_method  dollars
#>               <char>    <num>
#> 1:              none        0
#> 2: liquidation_curve  9702259
#> 3:       even_spread 14874129
```
