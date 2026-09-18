# Build the organization x award x year panel

The end-to-end pipeline: normalize, ledger, net, join subaward flows,
attach award attributes.

## Usage

``` r
us_panel(
  extract,
  org_map = NULL,
  period = c("calendar", "fiscal"),
  measure = c("obligation", "pragmatic"),
  deobligation_policy = c("as_posted", "restate", "drop"),
  fill_gaps = FALSE
)
```

## Arguments

- extract:

  A `usaspend_extract` from
  [`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md),
  or a list with `transactions` and `subawards`.

- org_map:

  Optional `uei` to `org_id` crosswalk, see
  [`us_org_map()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_map.md).

- period:

  `"calendar"` (default) or `"fiscal"`.

- measure:

  Money measure, see
  [`us_money_column()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_money_column.md).

- deobligation_policy:

  See
  [`us_net_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_net_by_year.md).

- fill_gaps:

  Emit zero-obligation rows so every dollar of pass-through has a row to
  land on. This does two things: interior years of an award's life with
  no actions get zero rows (via
  [`us_net_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_net_by_year.md)),
  and outbound subawards booked to an org-award-year with no prime
  activity – common, because FSRS reports trail the obligations they
  draw on – get their own zero-obligation rows instead of being silently
  dropped. In the pilot, 13% of outbound dollars fell in such years.
  With `fill_gaps = FALSE` the panel's `subaward_out_amount` total is a
  floor, not the total fetched.

## Value

A list of class `usaspend_panel`: `panel` (org x award x year), `awards`
(the spine), `transactions` (the normalized ledger), `subawards`
(normalized, with direction), `subawards_in` (org-year inbound revenue),
and `meta`.

## What the panel measures

`obligation_net` is the net federal obligation booked to the
organization-award-year. It is a **commitment**, not a disbursement –
federal award data does not carry annual cash. `net_revenue` is
`obligation_net - subaward_out_amount`: what the organization commits to
keeping after money it is obliged to pass through. Outbound subawards
are present only if the extract fetched them (`subawards = "out"` or
`"both"` in
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md));
otherwise the column is zero and `subaward_coverage` says
`"not_fetched"`, so a zero is never mistaken for a measured zero.

Inbound subawards – money received as a subrecipient, invisible in prime
data – are aggregated per organization-year in the separate
`subawards_in` element, keyed by subawardee UEI, and also joined onto
matching panel rows as `subaward_in_amount` when the prime award key
appears in the panel (rare: it requires the org to be both prime and
subawardee).

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
p$panel[, .(rows = .N, net = sum(obligation_net)), by = year][order(year)]
#>      year  rows     net
#>     <int> <int>   <num>
#>  1:  2008     3   27370
#>  2:  2009     1   17370
#>  3:  2010     3  297621
#>  4:  2011     5  418321
#>  5:  2012     5 1846021
#>  6:  2013     5  -13284
#>  7:  2014     5  341271
#>  8:  2015     3   27370
#>  9:  2016     2   57736
#> 10:  2017     3  461795
#> 11:  2018     2 1989540
#> 12:  2019     9 2884432
#> 13:  2020     3 2335590
#> 14:  2021     2 2327120
#> 15:  2022     5 5467555
#> 16:  2023     3 2078099
#> 17:  2024     5 4450585
#> 18:  2025     3  368879
```
