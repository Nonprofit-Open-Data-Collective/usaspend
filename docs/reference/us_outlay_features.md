# Award-level features for outlay imputation

Collapses a transaction ledger to one row per award carrying the traits
the imputation model uses (duration, start timing) and the modification
taxonomy defined by the imputation experiment (see `IMPUTATION.md` 6.4).

## Usage

``` r
us_outlay_features(transactions)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")` (normalized or raw
  canonical).

## Value

One row per award: identifiers, `first_fy`, `last_oblig_fy`,
`first_month` (fiscal month of the first action, Oct = 1), `late_start`
(first obligated Apr-Sep), obligation totals, period-of-performance
fields, `duration`, `dur_bin` (capped at 6), extension/reduction
booleans and `mod_class`.

## The modification taxonomy

`mod_class` is one label per award, first match wins:

- `reduced`:

  De-obligations exceed 5% of gross positive.

- `extension_funded`:

  Final `pop_end_date` pushed more than 90 days past the first reported
  one, with material new money (\> 5% of prior positives) at or after
  the extension event.

- `extension_timeline`:

  Extended as above without material new money – a no-cost extension.

- `multi_year_incremental`:

  Obligations in more than one fiscal year, no material extension or
  reduction.

- `single_year`:

  All obligations in one fiscal year.

## Examples

``` r
f <- us_outlay_features(us_sample_extract()$transactions)
f[, .N, by = mod_class]
#>                 mod_class     N
#>                    <char> <int>
#> 1:                reduced     3
#> 2:       extension_funded     4
#> 3: multi_year_incremental     5
#> 4:     extension_timeline     3
#> 5:            single_year     3
```
