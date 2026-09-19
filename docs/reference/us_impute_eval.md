# Cross-validated evaluation of an outlay-imputation configuration

K-fold (by award) evaluation of the liquidation-curve model against the
two reference rules: `as_obligated` (cash booked in the commitment year)
and `even_spread` (the fitted global ratio spread evenly over the
performance window). Reports both metrics from the experiment: `timing`
(misallocation share, imputed series rescaled to the actual total) and
`level_timing` (no rescaling – the method is charged for the level too).

## Usage

``` r
us_impute_eval(
  training,
  cells = c("dur_bin", "late_start", "short_family"),
  min_cell = 8L,
  folds = 5L,
  seed = 1L
)
```

## Arguments

- training:

  A `usaspend_outlay_training`.

- cells, min_cell:

  Passed to
  [`us_impute_fit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_fit.md).

- folds:

  Number of CV folds.

- seed:

  RNG seed for fold assignment.

## Value

A list: `summary` (mean/median/dollar-weighted by method and metric),
`by_class` (mean timing misallocation by `mod_class`), and `scores` (per
award).

## Examples

``` r
ev <- us_impute_eval(outlay_training)
ev$summary
#>    metric       method  mean median dollar_weighted
#>    <char>       <char> <num>  <num>           <num>
#> 1:  level        model 0.350  0.303           0.350
#> 2:  level  even_spread 0.453  0.469           0.442
#> 3:  level as_obligated 0.745  0.884           0.734
#> 4: timing        model 0.340  0.291           0.314
#> 5: timing  even_spread 0.441  0.459           0.407
#> 6: timing as_obligated 0.658  0.829           0.648
```
