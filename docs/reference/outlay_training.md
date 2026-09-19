# Outlay-imputation ground truth

The training set behind the bundled
[outlay_model](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_model.md):
2,785 awards whose annual File C outlays are fully trustworthy, pooled
from two populations – 1,174 from VUMC plus the 50-nonprofit pilot
(first obligated FY2020+, over \$50K) and 1,611 from a
1,000-organization sample pulled 2026-09-18 (first obligated FY2017+,
any size). File C obligations reconcile with the award's own ledger, and
either lifetime outlays match lifetime obligations within 10%
(`tier = "reconciled"`, 2,464 awards) or the award began inside the
FY2022 monthly reporting mandate with a completed, plateaued cash series
(`tier = "shape_complete"`, 321). Ten awards in both populations are
kept once, as their sample record. Built by
`data-raw/make-outlay-model.R`; the experiment that designed the screens
and picked the model is documented in `IMPUTATION.md`, the pooling in
its section 7.

## Usage

``` r
outlay_training
```

## Format

A list of class `usaspend_outlay_training`:

- awards:

  One row per candidate award (14,022): the features from
  [`us_outlay_features()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_features.md)
  (including `short_family`), File C lifetime figures, `linked`, `tier`
  (`NA` for awards that failed the truth screen), and `population`
  (`"pilot"` or `"sample"`).

- grid:

  One row per ground-truth award x fiscal year: `oblig_fy` (net
  obligations booked that year), `actual` (File C outlays), event time
  `t`, and the cell features.

- meta:

  `as_of` (FY2026), `sources` (each population's screens and truth
  count), and build time.

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
#> • 14022 candidate awards, 2785 ground truth
#> • 2464 reconciled, 321 shape-complete
#> • 8719 award-year rows, as of FY2026
outlay_training$awards[!is.na(tier), .N, by = .(tier, mod_class)]
#>               tier              mod_class     N
#>             <char>                 <char> <int>
#>  1:     reconciled                reduced   276
#>  2:     reconciled multi_year_incremental   448
#>  3:     reconciled     extension_timeline   263
#>  4:     reconciled            single_year  1390
#>  5:     reconciled       extension_funded    87
#>  6: shape_complete            single_year    44
#>  7: shape_complete multi_year_incremental   128
#>  8: shape_complete                reduced    75
#>  9: shape_complete       extension_funded    31
#> 10: shape_complete     extension_timeline    43
```
