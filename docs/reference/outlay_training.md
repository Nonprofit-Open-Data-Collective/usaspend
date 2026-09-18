# Outlay-imputation ground truth

The training set behind the bundled
[outlay_model](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_model.md):
1,184 awards from VUMC plus the 50-nonprofit pilot whose annual File C
outlays are fully trustworthy – File C obligations reconcile with the
award's own ledger, and either lifetime outlays match lifetime
obligations within 10% (`tier = "reconciled"`, 905 awards) or the award
began inside the FY2022 monthly reporting mandate with a completed,
plateaued cash series (`tier = "shape_complete"`, 279). Built by
`data-raw/make-outlay-model.R`; the experiment that designed the screens
and picked the model is documented in `IMPUTATION.md`.

## Usage

``` r
outlay_training
```

## Format

A list of class `usaspend_outlay_training`:

- awards:

  One row per candidate award (7,853): the features from
  [`us_outlay_features()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_features.md),
  File C lifetime figures, `linked`, and `tier` (`NA` for awards that
  failed the truth screen).

- grid:

  One row per ground-truth award x fiscal year: `oblig_fy` (net
  obligations booked that year), `actual` (File C outlays), event time
  `t`.

- meta:

  Screen parameters and build time (`as_of` FY2026).

## See also

[outlay_model](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_model.md),
[`us_outlay_training()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_training.md),
[`us_impute_fit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_fit.md),
[`us_impute_eval()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_eval.md)

## Examples

``` r
outlay_training
#> 
#> ── outlay-imputation training set ──────────────────────────────────────────────
#> • 7853 candidate awards, 1184 ground truth
#> • 905 reconciled, 279 shape-complete
#> • 4020 award-year rows, as of FY2026
outlay_training$awards[!is.na(tier), .N, by = .(tier, mod_class)]
#>               tier              mod_class     N
#>             <char>                 <char> <int>
#>  1:     reconciled     extension_timeline   166
#>  2:     reconciled            single_year   386
#>  3:     reconciled       extension_funded    21
#>  4:     reconciled                reduced   115
#>  5:     reconciled multi_year_incremental   217
#>  6: shape_complete multi_year_incremental   115
#>  7: shape_complete       extension_funded    25
#>  8: shape_complete            single_year    32
#>  9: shape_complete     extension_timeline    42
#> 10: shape_complete                reduced    65
```
