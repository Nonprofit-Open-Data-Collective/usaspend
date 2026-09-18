# Annual price index bundled with the package

CPI-U, U.S. city average, all items, annual averages (1982-84 = 100),
from the Bureau of Labor Statistics. The 2025 value is the provisional
annual average; check BLS for revisions before publication-grade work,
or supply your own series via the `index` argument of
[`us_adjust_inflation()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_adjust_inflation.md)
– a two-column `data.frame` of `year` and `index` (any consistent base
year works, since only ratios are used).

## Usage

``` r
us_price_index()
```

## Value

A `data.table` of `year`, `index`.

## Examples

``` r
us_price_index()
#>      year   index
#>     <int>   <num>
#>  1:  2007 207.342
#>  2:  2008 215.303
#>  3:  2009 214.537
#>  4:  2010 218.056
#>  5:  2011 224.939
#>  6:  2012 229.594
#>  7:  2013 232.957
#>  8:  2014 236.736
#>  9:  2015 237.017
#> 10:  2016 240.007
#> 11:  2017 245.120
#> 12:  2018 251.107
#> 13:  2019 255.657
#> 14:  2020 258.811
#> 15:  2021 270.970
#> 16:  2022 292.655
#> 17:  2023 304.702
#> 18:  2024 313.689
#> 19:  2025 322.561
```
