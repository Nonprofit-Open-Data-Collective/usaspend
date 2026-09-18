# Normalize a subaward ledger and assign direction

Normalize a subaward ledger and assign direction

## Usage

``` r
us_normalize_subawards(subawards, org_uei, year_basis = c("action", "report"))
```

## Arguments

- subawards:

  A `data.table` matching `us_schema("subawards")`.

- org_uei:

  Character vector of UEIs belonging to the organizations of interest.

- year_basis:

  `"action"` (default) or `"report"`.

## Value

A `data.table` matching `us_schema("subawards")` with `direction`
populated as `"in"`, `"out"`, `"internal"` or `"unrelated"`.

## Direction is the whole point

A bulk download filtered on `recipient_search_text` returns subawards
where the queried UEI is the **subawardee**, not the prime. Measured on
the 50-nonprofit pilot: of 39,243 subaward rows, **zero** had a prime
outside the pilot paying a subawardee outside it, and zero had a pilot
org as prime paying someone outside. Every row was matched on the
subawardee.

So `direction == "in"` rows arrive for free and are *additional revenue*
not visible in prime data. `direction == "out"` rows – the pass-through
that must be netted out of revenue – have to be fetched separately with
[`us_fetch_subawards_out()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_out.md).

## Other rules

1.  De-duplicates on `subaward_key`, keeping the latest
    `report_last_modified`. FSRS reports are restated month to month.

2.  Books on `subaward_action_date` by default. Report dates lag, in the
    pilot sometimes across a fiscal year boundary.

3.  Rows where the organization is both prime and subawardee are
    labelled `"internal"` and excluded from both flows, so that money
    moving between two UEIs of the same organization is not counted as
    revenue or as pass-through.
