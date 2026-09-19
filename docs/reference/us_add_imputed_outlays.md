# Attach imputed outlays to a panel

Runs
[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md)
on the panel's own transaction ledger and joins the result onto the org
x award x year table as `outlay_imputed`, with `imputation_method` per
award. Money measures already in the panel are never touched. Rows are
added (flagged `imputed_outlay_only_year`) for fiscal years the curve
allocates cash to but the panel has no row for – including *future*
years of awards still in progress, which is the point of imputation.

## Usage

``` r
us_add_imputed_outlays(
  panel,
  model = NULL,
  fill_gaps = TRUE,
  reconcile = FALSE
)
```

## Arguments

- panel:

  A `usaspend_panel` built with `period = "fiscal"` (curves are fitted
  in fiscal event time).

- model:

  A `usaspend_outlay_model`; `NULL` uses the bundled
  [outlay_model](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_model.md).

- fill_gaps:

  Add rows for imputed-cash years the panel lacks.

- reconcile:

  Rescale each award's imputed series to sum exactly to its net
  obligations – see
  [`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md).

## Value

The panel with `outlay_imputed` and `imputation_method` columns and
`meta$imputation` recording the model and method tally.

## Examples

``` r
p <- us_panel(us_sample_extract(), period = "fiscal")
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
#> Warning: No outbound subawards present -- pass-through cannot be netted out.
#> ℹ Bulk downloads match on the subawardee. Use `us_fetch_subawards_out()` to
#>   fetch pass-through by prime award.
p <- us_add_imputed_outlays(p)
#> Imputed outlays for 18 awards.
#> • liquidation_curve=12 none=6
#> Added 41 imputed-outlay years outside the panel's activity rows.
p$panel[, .(oblig = sum(obligation_net), imputed = sum(outlay_imputed))]
#>       oblig  imputed
#>       <num>    <num>
#> 1: 25383391 25551466
```
