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
  [`us_org_map()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_map.md)
  and the crosswalk section below. Extracted subsidiaries need not be
  listed: they inherit their parent's `org_id`.

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
(the spine, with `in_sample`), `transactions` (the normalized ledger),
`subawards` (normalized, with direction), `subawards_in` (org-year
inbound revenue), `org_map` (the resolved crosswalk: `uei`, `org_id`,
`relationship`, `root_uei`, ..., and `in_sample`), and `meta`.

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

## Organizations, subsidiaries and the crosswalk

The organization map is built from the extract's crosswalk
(`extract$org_map`, see
[`us_find_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_find_subsidiaries.md))
and `org_map`:

- Every UEI whose own history was extracted is in sample: the requested
  UEIs, plus subsidiaries pulled with `us_extract(subsidiaries = TRUE)`
  or
  [`us_add_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_subsidiaries.md).

- A requested UEI takes its `org_id` from `org_map`, else its own UEI.

- A subsidiary takes its `org_id` from `org_map` if listed there, else
  the `org_id` of the requested UEI it rolls up to – so it counts as
  part of its parent without being listed.

- `org_map` rows for UEIs not in the extract are ignored, with a
  message: a crosswalk cannot add data that was never pulled.

Subsidiaries the extract found but did not pull are out of sample. The
API filter also matches a transaction's *parent* UEI (see
[`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md)),
so the extract holds part of their history – only what they filed while
a requested UEI was recorded as parent. The panel leaves those
transactions out and reports how many it dropped. `awards` and
`transactions` keep them, deliberately: they are what the extract
returned, and dropping them would hide the leak. `awards` flags them
with `in_sample = FALSE`,
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
labels them `"out_of_sample"`, and `awards[(in_sample)]` is the
organizations' spine. See
[`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md).

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
