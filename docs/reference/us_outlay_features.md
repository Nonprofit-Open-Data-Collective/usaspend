# Award-level features for outlay imputation

Collapses a transaction ledger to one row per award carrying the traits
the imputation model uses (duration, start timing) and the modification
taxonomy defined by the imputation experiment (see `IMPUTATION.md` 6.4).

## Usage

``` r
us_outlay_features(transactions, max_pop_years = 10L)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")` (normalized or raw
  canonical).

- max_pop_years:

  Largest plausible gap, in fiscal years, between the last obligation
  and the final period-of-performance end. Longer gaps are treated as a
  missing end date (see the section on implausible end dates). `Inf`
  disables the rule.

## Value

One row per award: identifiers, `first_fy`, `last_oblig_fy`,
`first_month` (fiscal month of the first action, Oct = 1), `late_start`
(first obligated Apr-Sep), obligation totals, period-of-performance
fields (`pop_end_fy`, `pop_end_fy_reported`, `pop_end_implausible`),
`duration`, `dur_bin` (capped at 6), `short_family`, extension/reduction
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

## Implausible end dates

Some awards carry placeholder period-of-performance end dates (2079,
2099) or multi-decade compliance periods that say nothing about when
cash moves. A final end date whose fiscal year lies more than
`max_pop_years` past the last obligation year is treated as **missing**
for imputation: `pop_end_fy` is set to `NA` (so `duration` falls back to
the obligation span), the reported year is kept in
`pop_end_fy_reported`, and `pop_end_implausible` is `TRUE`. Imputed rows
for such awards carry the flag `pop_end_implausible`. The default of 10
years sits well beyond the model's longest duration bin (6+); in a
1,000-organization test pull the gap was 6 years or less for over 98% of
awards with an end date.

## Short awards by family

`short_family` is the award family – `"grant"`, `"contract"` or
`"other"` (direct payments, loans, IDVs, and anything unlabelled) – for
awards of one or two years, and `"any"` for longer ones. Short awards
pay out on family-specific schedules: a direct payment is cash almost at
once, a one-year grant is drawn down over the following year. For awards
of three or more years the family split added nothing and cost accuracy
on the longest ones, so those keep one curve per duration. See
`IMPUTATION.md` 7.

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
