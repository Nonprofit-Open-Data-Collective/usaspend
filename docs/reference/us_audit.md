# Audit a finished panel

Structural checks needing no external reference. Run on every rebuild
and diff against the previous run, so a change in the data or a rule
shows up as a change in the audit rather than as a quietly different
number.

## Usage

``` r
us_audit(panel)
```

## Arguments

- panel:

  A `usaspend_panel` from
  [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md).

## Value

A `data.table` of `check`, `value`, `status` (`"ok"` / `"info"` /
`"warn"`).

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
us_audit(p)
#>                                                     check     value status
#>                                                    <char>    <char> <char>
#>  1:                      rows at org x award x year grain        67   info
#>  2:                                  duplicate grain rows         0     ok
#>  3:                  awards attributed to >1 organization         0     ok
#>  4:        duplicate transaction keys after normalization         0     ok
#>  5:          org-award-years with negative net obligation         6   info
#>  6: rows where pass-through pushes net_revenue below zero         0   info
#>  7:                 share of zero-dollar transactions (%)      49.2   info
#>  8:                   transactions carrying anomaly flags         8   info
#>  9:                                         years covered 2008-2025   info
#> 10:                            outbound subawards fetched     FALSE   warn
```
