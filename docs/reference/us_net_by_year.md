# Net an award ledger into organization x award x year records

The central aggregation: collapses signed transactions into one row per
organization, award and year, under an explicit de-obligation policy.

## Usage

``` r
us_net_by_year(
  ledger,
  org_map,
  period = c("calendar", "fiscal"),
  deobligation_policy = c("as_posted", "restate", "drop"),
  fill_gaps = FALSE
)
```

## Arguments

- ledger:

  Output of
  [`us_ledger()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_ledger.md).

- org_map:

  Output of
  [`us_org_map()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_map.md).
  Transactions whose `recipient_uei` is not in the map are dropped (with
  a message) – text matching on the API returns stray recipients, and an
  award's history can include years when it belonged to a different
  organization.

- period:

  `"calendar"` (default) or `"fiscal"`.

- deobligation_policy:

  `"as_posted"`, `"restate"`, or `"drop"`.

- fill_gaps:

  Emit zero rows for org-award-years with no activity between an award's
  first and last year.

## Value

A `data.table` at organization x award x year grain with gross positive,
gross negative and net obligations, loan columns, and counts.

## The de-obligation policy

A claw-back recorded in 2024 against money obligated in 2021 can be
booked two ways, and neither is wrong:

- `"as_posted"` (default):

  Book every action in the year it happened. Cash-basis-like; matches
  USAspending's presentation; each year is reproducible from that year's
  transactions. A large reversal can drive a year negative.

- `"restate"`:

  Push each award's negative amounts back against that award's positive
  years, latest-first (LIFO). Accrual-like; cleaner "what was this
  year's cohort ultimately worth"; but last year's figure changes when
  this year's data arrives. Transactions do not identify what they
  reverse, so LIFO within the award is the matching rule, applied
  uniformly.

- `"drop"`:

  Discard negatives. Overstates every affected year; exists only so the
  overstatement can be measured, and warns.
