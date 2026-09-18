# Build an outlay-imputation training set

Assembles the ground truth the imputation model is fitted on: award
features from the transaction ledger, annual File C outlays per award,
and the two-tier truth screen from the imputation experiment
(`IMPUTATION.md` 1). Awards that fail the screen are kept in `awards`
with `tier = NA` but excluded from `grid`.

## Usage

``` r
us_outlay_training(
  transactions,
  funding = NULL,
  min_first_fy = 2020L,
  min_oblig = 50000,
  as_of = NULL
)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")`.

- funding:

  Optional prefetched File C table from
  [`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md);
  fetched (one paged request per candidate award) when `NULL`.

- min_first_fy:

  Earliest first-obligation fiscal year to consider. File C coverage
  begins in earnest FY2020; earlier awards cannot be truth.

- min_oblig:

  Minimum absolute net obligation.

- as_of:

  The current (incomplete) federal fiscal year; defaults to today's.
  Used by the censoring screens.

## Value

A list of class `usaspend_outlay_training`: `awards` (features + File C
lifetime figures + `tier`), `grid` (award x fiscal year rows for truth
awards: `oblig_fy`, `actual`, event time `t`), and `meta`.

## The two tiers

Both require **linkage** – File C lifetime obligations within 10% of the
award's own ledger. `"reconciled"` additionally requires lifetime
outlays within 10% of lifetime obligations with cash no longer flowing.
`"shape_complete"` requires a first obligation FY2022+ (inside the
monthly reporting mandate), performance ended before the current fiscal
year, and a plateaued outlay series – the timing profile is fully
observed even where the level fell short.

## Examples

``` r
if (FALSE) { # \dontrun{
tr <- us_outlay_training(us_normalize_transactions(vumc_transactions))
} # }
```
