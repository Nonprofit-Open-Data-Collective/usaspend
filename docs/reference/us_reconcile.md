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
(`"out_of_sample"`, `"no_reported_total"`, `"ok"`, `"multi_recipient"`,
`"window_edge"`, `"recent_open"`, `"break"`, tested in that order), the
outlay ratio, and `in_sample`.

## Details

An award is `window_edge` when its history evidently begins before the
pull window: its earliest reported period-of-performance start (on the
award record or any of its transactions) precedes the first action date
in the extract, or its first in-extract action falls within a year of
the window opening. The second test alone misses awards made before the
window whose first in-window action is a later modification:
`base_action_date` is the earliest action *in the extract*, so it can
never precede the window. The period-of-performance test is added to it
rather than replacing it, because a later modification can move an
award's reported start date forward past its first obligation.

## Out-of-sample awards

An award is `"out_of_sample"` when none of its transactions carry a
recipient UEI in the panel's organization map – the UEIs whose own
histories
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
pulled. The bulk download filters on `recipient_search_text`, which also
matches a transaction's *parent* UEI (see
[`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md)),
so querying a parent returns its subsidiaries' transactions – but only
those filed while the parent was recorded as parent. Querying RTI
(`JJHCMK4NT5N3`) returned transactions of its subsidiary International
Resources Group from 2017 on, after the acquisition; the same awards'
earlier actions, filed under the previous parents, were not returned.
Such a history is truncated by construction, so the identity fails for
reasons that say nothing about the netting.

The test runs first, ahead of every other label: an out-of-sample award
is not part of the organization's panel whether or not it happens to
reconcile.
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
already leaves these transactions out of `panel`; they stay in `awards`
and `transactions`, flagged `in_sample = FALSE`, so the leak stays
visible. To count subsidiaries as part of their parents, extract their
full histories with `us_extract(subsidiaries = TRUE)` or
[`us_add_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_subsidiaries.md);
see
[`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md).
Panels built before
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
recorded its organization map fall back to the transactions'
`is_stray_uei` flag.

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
