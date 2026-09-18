# Fetch inbound subawards for a set of UEIs

Inbound subawards – money an organization receives as a *subawardee* –
appear nowhere in prime award data, and the annual Award Data Archive
carries no subawards at all. This fetches them from the API, so an
archive-path extract (or any UEI list) can be given its inbound flows.

## Usage

``` r
us_fetch_subawards_in(
  uei,
  years = NULL,
  via = c("search", "download"),
  batch_size = 10,
  cap_guard = 9000,
  dest = us_cache_dir("raw")
)
```

## Arguments

- uei:

  Character vector of UEIs (the subawardee side).

- years:

  Integer vector of fiscal years; `NULL` for everything since FY2008.

- via:

  `"search"` (default) or `"download"`.

- batch_size:

  UEIs per search request. Max ~20; the conservative default leaves
  headroom for large organizations.

- cap_guard:

  Split a batch when its subaward count exceeds this.

- dest:

  `"download"` route only: directory for intermediate files (subaward
  CSVs land in a `subawards_in/` subdirectory).

## Value

A `data.table` matching `us_schema("subawards")`, one row per inbound
subaward, with a `failures` attribute (a `data.table`, possibly empty)
recording anything that could not be resolved. Direction is left unset –
[`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)
assigns it from the organization's UEI set.

## Details

Two routes:

- `via = "search"` (default):

  Filters `POST /api/v2/search/spending_by_award/` with
  `subawards = TRUE` on `recipient_search_text`, which – measured live –
  matches the **subawardee**. Each batch is counted first and skipped
  when it holds nothing, so the common case (an organization with no
  inbound subawards) costs one cheap count. Orders of magnitude faster
  than download jobs at crosswalk scale.

- `via = "download"`:

  Runs the standard bulk-download jobs and harvests only their subaward
  files – the API path's full cost. The fallback if the search route
  ever misbehaves; also the only route that returns FSRS report-period
  columns (`report_year`, `report_month`, `report_last_modified`).

Measured constraints the search route works around (all hit live):
`recipient_search_text` caps near 20 values (50 returns HTTP 503) and
batches of very large organizations time out server-side, so batches
split recursively on failure down to a single UEI, then split the time
period; `award_type_codes` is required and cannot mix families (HTTP
422), so it runs one pass per family; the 10k result cap is per filter
set, so any batch counting near it is split before fetching. UEIs that
still fail after all splitting are reported in the `failures` attribute
and a warning – a failure is never allowed to read as "no subawards".

One measured quirk shapes the design: the search view returns the
`Sub-Awardee UEI` field as `NULL` even on rows it matched *by* that UEI,
so returned rows cannot be attributed from their own columns. Fetches
therefore run **one UEI at a time** (counts stay batched), and
`subawardee_uei` is stamped from the query. The text search could in
principle match something other than the UEI string; the pilot
validation found no such strays, but per-organization totals should
still be checked against an independent figure where one exists.
`prime_uei` is filled from `Prime Award Recipient UEI`, so
[`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)
can classify `internal` flows.

## Examples

``` r
if (FALSE) { # \dontrun{
ex <- us_extract(ueis, years = 2008:2025, source = "archive")
ex$subawards <- us_fetch_subawards_in(ueis, 2008:2025)
} # }
```
