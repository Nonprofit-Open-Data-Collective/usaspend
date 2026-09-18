# Fetch account-level (File C) funding history per award

Walks `POST /api/v2/awards/funding/` for each award: one row per federal
account x object class x program activity x reporting period, carrying
the two account-level money fields. This is the **only** source of
annual outlays – the award data itself is lifetime-only (see
[`us_money_column()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_money_column.md)).

## Usage

``` r
us_fetch_outlays(award_key, page_limit = 100)
```

## Arguments

- award_key:

  Character vector of generated unique award ids.

- page_limit:

  Records per page (API maximum 100).

## Value

A `data.table` matching `us_schema("funding")`, with a `usaspend_failed`
attribute naming awards whose fetch errored.

## The two money columns are on different bases

`transaction_obligated_amount` is **incremental** per period.
`gross_outlay_amount` is **cumulative within each fiscal year** per
account cell (File C reports it as of period end, resetting at the
fiscal year boundary). Summing it across periods double-counts;
[`us_outlays_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlays_by_year.md)
applies the correct last-period-per-year rule.

## Failures are not empty results

An award whose request errors is recorded in the `usaspend_failed`
attribute and warned about – it must not be read as "this award has no
File C data". Awards that genuinely return zero records are simply
absent from the result.

## Examples

``` r
if (FALSE) { # \dontrun{
fc <- us_fetch_outlays("ASST_NON_NU2GGH002367_075")
us_outlays_by_year(fc)
} # }
```
