# Disruption in federal funding: a 1,000-nonprofit sample, FY2016–FY2026

The aggregates and case ledgers behind
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md),
built by `data-raw/make-disruption-sample.R` from a test pull of the
first 1,000 UEIs of a nonprofit crosswalk (434 of which hold federal
awards): 64,255 prime transactions on 15,050 awards, FY2008 to
2026-09-15, plus File C funding records for the 3,325 awards first
obligated FY2020 or later. Every ledger was re-harmonized with the
disruption fields and run through
[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md).

## Usage

``` r
disruption_sample
```

## Format

A list:

- meta:

  Sample description, pull date, `data_end`, `t0` (2025-01-20), counts,
  and `outlay_last_quarter` (the latest fiscal quarter with File C data,
  which is partially reported).

- trend_fy:

  Fiscal year x agency: gross and net obligations, new awards and
  actions, October–August of each year so FY2026 is comparable.

- trend_month:

  Month: gross obligations, de-obligations, actions.

- signals:

  Calendar year: counts of every `dsr_*` signal and related dollars over
  February–August, the window after the inauguration that every year
  shares.

- signals_agency:

  The same by agency, 2022 on.

- action_types:

  Contract and assistance action-type counts, February–August, by year.

- terminations:

  One row per award with a formal termination (`kind = "formal"`: action
  code or notice text) or an unexplained schedule cut
  (`"quiet_truncation"`) on or after 2025-01-20: dollars before and
  after, schedule before and after, `status` (`still obligated`,
  `de-obligated`, `new money since`, `rescinded`), and the best
  same-recipient successor candidate (`link`).

- continuations:

  Multi-year assistance anchors by the due year of their next funding
  action, agency, and `outcome`.

- outlay_quarters:

  Fiscal quarter x agency: awards scheduled active all quarter, how many
  received no File C outlay, and dollars.

- cases:

  Transaction ledgers for eleven illustrative awards, keyed by `case`,
  with the disruption fields and flags.

- pi_transfers:

  NIH grants whose history is split across institutions, from an API
  probe of reconciliation breaks.

- usaid:

  The USAID portfolio's fate: counts and the actions filed on it since
  2025-01-20.

## Source

USAspending.gov bulk download API and `POST /api/v2/awards/funding/`,
pulled 2026-09-18.

## Details

**The sample is not random.** The crosswalk is ordered by state, and one
recipient (RTI International) accounts for about a third of all
transactions, so agency-level results – especially USAID, EPA, and HHS
contracts – carry that organization's portfolio. Treat the numbers as a
worked example of the method, not as estimates for the nonprofit sector.

Awards are assigned to the agency that *originated* them (the awarding
agency on their first action), so an award moved from USAID to State
stays in the USAID series.

## See also

[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md),
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md)

## Examples

``` r
disruption_sample$signals[, .(year, term_code, end_cut, ceiling_cut, early_deob)]
#>     year term_code end_cut ceiling_cut early_deob
#>    <int>     <int>   <int>       <int>      <int>
#> 1:  2019         0      25          66         26
#> 2:  2020         1      22          60         31
#> 3:  2021         0      38          99         50
#> 4:  2022         2      26          56        100
#> 5:  2023         0      15          62        199
#> 6:  2024         0      18          64        186
#> 7:  2025        84      95         105        213
#> 8:  2026         2      18          94        173
```
