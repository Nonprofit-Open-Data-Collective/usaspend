# A bundled sample extract

A real three-UEI pull from `POST /api/v2/download/transactions/` taken
on 2026-08-27 and shipped verbatim, harmonized to the canonical schema
on demand. It exists so that the normalization and accounting functions
can be developed and tested offline against genuine USAspending output
rather than invented data.

## Usage

``` r
us_sample_extract()
```

## Value

A `usaspend_extract`.

## Details

152 rows. Small, but it contains most of the awkward cases: an award
whose transactions sum exactly to its reported lifetime total, a
de-obligating revision, zero-dollar administrative modifications,
contract IDV rows with a blank award type code, one award type code
carrying two different description strings in the same file, an IDV with
a \$40M ceiling against \$0 obligated, and subaward rows that are
entirely inbound.

See `system.file("extdata/sample/README.md", package = "usaspend")`.

## Examples

``` r
ex <- us_sample_extract()
ex
#> 
#> ── usaspend extract ────────────────────────────────────────────────────────────
#> • 3 UEIs, FY2008-FY2025, path "bundled sample"
#> • 120 transactions on 18 awards
#> • 32 subaward rows
#> • extracted 2026-08-27 06:37
ex$transactions[, .N, by = .(award_group, action_class)]
#>     award_group   action_class     N
#>          <char>         <char> <int>
#>  1:  assistance       revision     5
#>  2:  assistance    origination     1
#>  3:  assistance   continuation     3
#>  4:    contract   unclassified    13
#>  5:    contract       closeout     1
#>  6:    contract administrative    30
#>  7:    contract   continuation    12
#>  8:    contract       revision    21
#>  9:    contract   funding_only    33
#> 10:    contract    termination     1
```
