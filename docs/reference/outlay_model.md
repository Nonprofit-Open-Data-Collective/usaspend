# The default liquidation-curve outlay model

The model
[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md)
uses when none is supplied: empirical liquidation curves (share of net
obligations outlaid per event-year, by award duration x late-fiscal-year
start, zero-filled estimator) fitted on
[outlay_training](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_training.md).
Cross-validated performance: mean misallocation 0.28 (timing) and 0.30
(level + timing) against 0.41/0.43 for even spread and 0.75/0.85 for
treating obligations as cash. Durations of 1-5 years are inside the
support envelope; longer awards fall back to even spread.

## Usage

``` r
outlay_model
```

## Format

A list of class `usaspend_outlay_model`; see
[`us_impute_fit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_fit.md).

## See also

[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md),
[`us_add_imputed_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_imputed_outlays.md),
[`us_impute_fit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_fit.md),
[outlay_training](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_training.md)

## Examples

``` r
outlay_model
#> 
#> ── liquidation-curve outlay model ──────────────────────────────────────────────
#> • fitted on 1184 ground-truth awards (as of FY2026)
#> • cells: dur_bin x late_start, min cell 8
#> • global outlay/obligation ratio 0.94
#> • durations supported: 1 (n=27), 2 (n=273), 3 (n=416), 4 (n=454), 5 (n=13), 6
#>   (n=1)
# the duration-4 liquidation curve
outlay_model$curves_dur[dur_bin == 4]
#> Key: <dur_bin>
#>    dur_bin     t       share     n
#>      <int> <int>       <num> <int>
#> 1:       4     0 0.063772487   454
#> 2:       4     1 0.360364818   454
#> 3:       4     2 0.346694238   454
#> 4:       4     3 0.133250505   454
#> 5:       4     4 0.007561823   454
```
