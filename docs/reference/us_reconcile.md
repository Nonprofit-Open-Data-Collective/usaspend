# Reconcile netted transactions against award lifetime totals

The invariant: for an award whose whole history is inside the extract,
the sum of `federal_action_obligation` across its transactions equals
the award's reported lifetime total. A break is classified, not just
counted – most breaks are structural (truncation, recipient changes),
not bugs.

## Usage

``` r
us_reconcile(panel, tolerance = 1)
```

## Arguments

- panel:

  A `usaspend_panel` from
  [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md).

- tolerance:

  Absolute dollar tolerance for the identity.

## Value

A `data.table`, one row per award: `tx_sum`, `reported`, `gap`, `status`
(`"ok"`, `"no_reported_total"`, `"window_edge"`, `"multi_recipient"`,
`"recent_open"`, `"break"`), and the outlay ratio.

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
r <- us_reconcile(p)
#> Reconciled 18 awards: 15 exact (83%).
#> • ok=15 no_reported_total=2 break=1
#> Warning: 1 award break the lifetime identity with no structural explanation -- inspect
#> before publishing.
r[, .N, by = status]
#>               status     N
#>               <char> <int>
#> 1: no_reported_total     2
#> 2:             break     1
#> 3:                ok    15
```
