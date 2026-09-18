# Misallocation share between an imputed and an actual annual series

`0.5 * sum(|imputed - actual|) / sum(actual)`: the fraction of the
dollars placed in the wrong year. With `normalize = TRUE` the imputed
series is first rescaled to the actual total, isolating *timing*; with
`FALSE` the method is also charged for missing the cash *level*. See
`IMPUTATION.md` 3 for why this beats correlation for allocation tasks.

## Usage

``` r
us_misallocation(imputed, actual, normalize = TRUE)
```

## Arguments

- imputed, actual:

  Numeric vectors over the same years.

- normalize:

  Rescale `imputed` to the actual total first.

## Value

A scalar in `[0, Inf)` (`NA` if `sum(actual) <= 0`); values at or above
1 mean essentially none of the money was placed correctly.

## Examples

``` r
us_misallocation(c(50, 50), c(10, 90))
#> [1] 0.4
```
