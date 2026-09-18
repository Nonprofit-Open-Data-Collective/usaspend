# Adjust panel dollars for inflation

Restates every dollar column into constant dollars of a target year
using an annual price index: `amount * index[target] / index[year]`.

## Usage

``` r
us_adjust_inflation(
  x,
  target_year = NULL,
  index = NULL,
  cols = NULL,
  strict = TRUE
)
```

## Arguments

- x:

  A `usaspend_panel` (its `panel` and `subawards_in` tables are both
  adjusted), or any `data.frame` with a `year` column – including
  [`us_rollup()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_rollup.md)
  output, provided it was built with `year = TRUE` (a rollup collapsed
  across years mixes vintages and cannot be deflated; adjust first, then
  roll up).

- target_year:

  Year whose dollars to state everything in. Default: the latest year in
  the data that the index covers (a message says which).

- index:

  `NULL` for the bundled CPI-U series
  ([`us_price_index()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_price_index.md)),
  or a `data.frame` of `year` and `index`.

- cols:

  Columns to adjust. Default: the package's known dollar columns present
  in the data.

- strict:

  If `TRUE` (default), a data year missing from the index is an error.
  If `FALSE`, those rows' dollar columns become `NA` with a warning –
  visible, never silently unadjusted.

## Value

The same structure with dollar columns restated, and an
`usaspend_inflation` attribute (on the data.frame, or in `meta` for a
panel) recording the target year and index range used.

## Examples

``` r
p <- us_panel(us_sample_extract())
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
#> Warning: No outbound subawards present -- pass-through cannot be netted out.
#> ℹ Bulk downloads match on the subawardee. Use `us_fetch_subawards_out()` to
#>   fetch pass-through by prime award.
oy <- us_rollup(p, year = TRUE)
oy25 <- us_adjust_inflation(oy, target_year = 2025)
#> Restated 8 columns in 2025 dollars.
attr(oy25, "usaspend_inflation")
#> $target_year
#> [1] 2025
#> 
#> $cols
#> [1] "obligation_positive" "obligation_negative" "obligation_net"     
#> [4] "loan_face_value"     "subaward_out_amount" "subaward_in_amount" 
#> [7] "net_revenue"         "total_net"          
#> 
#> $index_years
#> [1] 2007 2025
#> 
#> $source
#> [1] "bundled CPI-U annual averages (BLS)"
#> 
```
