# Build the prime award spine

Collapses the transaction ledger to one row per award, taking each
award-level field from the latest action that actually reports one.

## Usage

``` r
us_normalize_awards(transactions, enrich = FALSE, rollup_idv = FALSE)
```

## Arguments

- transactions:

  A normalized ledger from
  [`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md).

- enrich:

  Call
  [`us_fetch_award()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_award.md)
  per award to add `subaward_count` and `subaward_total`. Costs one API
  request per award.

- rollup_idv:

  Attribute delivery-order obligations to the parent IDV.

## Value

A `data.table` matching `us_schema("awards")`, plus `n_recipients`.

## Why "latest non-missing" and not "any row"

Award-level columns are sparse across transactions. In the pilot,
`total_dollars_obligated` and `current_total_value_of_award` are blank
on most contract modification rows and populated on others; taking an
arbitrary row gives an arbitrary answer.

## An award is not owned by one organization

Award keys are shared. NIH research grants follow the principal
investigator between institutions, so a single `award_key` can carry
transactions for several recipients over its life. In a 28-award pilot
audit, 11 awards present in the extract had a *current* recipient that
was not a pilot organization at all – the pilot org held only part of
the award's history. This is why the panel grain is organization x award
x year and not award x year, and why `n_recipients > 1` is worth
inspecting.
