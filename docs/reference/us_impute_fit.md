# Fit a liquidation-curve outlay model

The model is a set of empirical liquidation curves: the mean share of an
award's **net obligations** outlaid in each event-year `t` (years since
first obligation), by cell. Because the target is a share of
obligations, not of the cash total, each curve's sum encodes the cell's
outlay/obligation ratio and its shape encodes the lag – level and timing
in one object. This is the experiment's winning method (`IMPUTATION.md`
4: 0.27 mean misallocation, best unnormalized level + timing).

## Usage

``` r
us_impute_fit(
  training,
  cells = c("dur_bin", "late_start", "short_family"),
  min_cell = 8L,
  zero_fill = TRUE
)
```

## Arguments

- training:

  A `usaspend_outlay_training` from
  [`us_outlay_training()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_training.md).

- cells:

  Feature columns defining the cell. The default is duration x late
  start x `short_family`: `late_start` (first obligated Apr-Sep) shifts
  cash into the next fiscal year, and `short_family` splits one- and
  two-year awards into grant, contract and other (see
  [`us_outlay_features()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_features.md)).
  The original experiment selected duration x late start; the family
  split for short awards was added after pooling the pilot with a
  1,000-organization sample (`IMPUTATION.md` 7). Training grids built
  before `short_family` existed get it derived from `award_family` where
  the awards table carries it.

- min_cell:

  Minimum training awards for a cell to be used.

- zero_fill:

  Estimator for the per-event-year mean. `TRUE` (default) counts every
  cell award at every event-year, zero share past its own end, which
  makes `sum(curve) == mean lifetime outlay/obligation ratio` of the
  cell an exact identity. `FALSE` averages only the awards observed at
  each event-year (the survivor mean), whose tail years are estimated
  from the longer-lived awards only and whose sum can drift above the
  cell's mean ratio.

## Value

A list of class `usaspend_outlay_model`: the curve tables, per-duration
support counts, the global outlay/obligation ratio (used by the
even-spread fallback), and `meta`.

## Details

Prediction falls back hierarchically: the full cell where it has at
least `min_cell` training awards, then the duration-only curve, then the
global curve.

## What the model returns

The **typical payment schedule** given the observed obligations – both
its shape (the lag) and its level (the cell's mean lifetime
outlay/obligation ratio, below 1 for most cells). It does *not* impose
the accounting identity that outlays eventually equal net obligations;
[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md)`(reconcile = TRUE)`
re-imposes it on the output when the analysis wants dollars that tie out
to the obligations ledger.

## Examples

``` r
m <- us_impute_fit(outlay_training)
m
#> 
#> ── liquidation-curve outlay model ──────────────────────────────────────────────
#> • fitted on 2785 ground-truth awards (as of FY2026)
#> • cells: dur_bin x late_start x short_family, min cell 8
#> • global outlay/obligation ratio 0.92
#> • durations supported: 1 (n=529), 2 (n=676), 3 (n=717), 4 (n=633), 5 (n=97), 6
#>   (n=133)
# the zero-fill identity: each curve sums to its cell's mean ratio
m$curves_dur[, .(curve_sum = round(sum(share), 3)), by = dur_bin]
#> Key: <dur_bin>
#>    dur_bin curve_sum
#>      <int>     <num>
#> 1:       1     0.996
#> 2:       2     0.968
#> 3:       3     0.955
#> 4:       4     0.926
#> 5:       5     0.993
#> 6:       6     0.991
```
