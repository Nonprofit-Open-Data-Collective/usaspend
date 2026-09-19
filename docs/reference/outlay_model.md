# The default liquidation-curve outlay model

The model
[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md)
uses when none is supplied: empirical liquidation curves (share of net
obligations outlaid per event-year, by award duration x late-fiscal-year
start, with one- and two-year awards further split by award family –
`short_family`; zero-filled estimator) fitted on
[outlay_training](https://nonprofit-open-data-collective.github.io/usaspend/reference/outlay_training.md).
Cross-validated performance on the pooled truth: mean misallocation 0.34
(timing) and 0.35 (level + timing) against 0.44/0.45 for even spread and
0.66/0.75 for treating obligations as cash; 0.30 on the pilot's awards
and 0.37 on the sample's, whose truth is harder under every method.
Every duration bin, including 6+ years (133 awards), is inside the
support envelope.

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
#> • fitted on 2785 ground-truth awards (as of FY2026)
#> • cells: dur_bin x late_start x short_family, min cell 8
#> • global outlay/obligation ratio 0.92
#> • durations supported: 1 (n=529), 2 (n=676), 3 (n=717), 4 (n=633), 5 (n=97), 6
#>   (n=133)
# the duration-4 liquidation curve
outlay_model$curves_dur[dur_bin == 4]
#> Key: <dur_bin>
#>    dur_bin     t        share     n
#>      <int> <int>        <num> <int>
#> 1:       4     0 0.0763453715   633
#> 2:       4     1 0.3891211323   633
#> 3:       4     2 0.3273282667   633
#> 4:       4     3 0.1250985812   633
#> 5:       4     4 0.0080780603   633
#> 6:       4     5 0.0000087693   633
```
