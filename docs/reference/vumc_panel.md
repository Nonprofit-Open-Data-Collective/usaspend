# Vanderbilt University Medical Center: the finished panel

The org x award x year table
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
produces from
[vumc_transactions](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_transactions.md)
and
[vumc_subawards](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_subawards.md),
built with `fill_gaps = TRUE` (so every pass-through dollar has a row to
land on), calendar-year basis, `as_posted` de-obligation policy. 9,290
rows over 2,166 awards, 2008–2026.

## Usage

``` r
vumc_panel
```

## Format

A `data.table` with 9,290 rows matching `us_schema("panel")`. Key
fields:

- org_id, award_key, year, year_basis:

  The grain. `year_basis` is `"calendar"` here.

- award_group, award_family, award_type_code, award_type_label:

  What kind of award.

- awarding_agency_code/name, awarding_sub_agency_name,
  funding_agency_name:

  Who awarded and funded it.

- cfda_number, naics_code, recipient_state:

  Program / industry / registered state.

- n_transactions, n_actions_positive, n_actions_negative:

  Activity counts. A row with `n_transactions = 0` is a fill-gaps
  placeholder – an interior zero year, or a year holding only
  pass-through.

- obligation_positive, obligation_negative, obligation_net:

  Gross inflow, gross claw-backs, and their sum. Kept separately so
  +5M/-4M is distinguishable from a clean +1M.

- deobligation_prior_year:

  Only non-zero under the `restate` policy; zero throughout this table.

- loan_face_value, loan_subsidy_cost:

  Loan amounts, outside revenue.

- subaward_out_amount, n_subawards_out:

  Pass-through paid onward under this award-year.

- subaward_in_amount, n_subawards_in:

  Subawards received under this award (rare at award level; org-level
  inflows live in the panel object's `subawards_in` table).

- net_revenue:

  `obligation_net - subaward_out_amount`.

- flags:

  Anomaly markers.

## Details

This is the deliverable shape: one row per award per year, carrying the
awarding agency, award type, gross and net obligations, pass-through
paid, and `net_revenue`.

## See also

[vumc_transactions](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_transactions.md),
[vumc_subawards](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_subawards.md),
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md),
[`us_rollup()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_rollup.md)

## Examples

``` r
# the pass-through share that made VUMC the packaged example
vumc_panel[, .(obligated = sum(obligation_net),
               passed_through = sum(subaward_out_amount))]
#>     obligated passed_through
#>         <num>          <num>
#> 1: 4449776760     2156331916
```
