# Which transaction amount counts as money

USAspending carries several dollar columns and only some of them are
revenue. This returns the measure a given policy uses, so that the
choice is made once and visibly rather than being buried in an
aggregation.

## Usage

``` r
us_money_column(measure = c("obligation", "pragmatic", "outlay"))
```

## Arguments

- measure:

  One of `"obligation"`, `"pragmatic"`, `"outlay"`.

## Value

The canonical column name to sum.

## Details

- `"obligation"`:

  `federal_action_obligation`. The signed amount the government
  committed in this action. The default, and the only column that
  supports an annual panel.

- `"pragmatic"`:

  `pragmatic_obligation` – USAspending's own derived measure, which
  substitutes the loan subsidy cost for loans and equals the obligation
  otherwise. In the pilot the two are identical on every non-loan row.

- `"outlay"`:

  Not available. There is no transaction-level or annual outlay in the
  award data, and `award_total_outlayed` is lifetime-to-date, not
  annual. Its coverage follows the reporting mandates: account-level
  (File C) outlay reporting was quarterly and optional from FY2017,
  required for COVID-supplemental awards from April 2020, and monthly
  and mandatory for all agencies only from FY2022 – so lifetime outlays
  undercount any award straddling those dates (91% of pilot awards
  starting before 2017 report no outlay at all), and coverage varies by
  agency and award family, not just era: post-FY2022 in the VUMC pilot,
  98% of HHS awards carry an outlay against 0% of VA contracts.
  Requesting this raises an error rather than returning something
  misleading. Annual outlays can be attached to a fiscal panel as a
  separate, coverage-graded column with
  [`us_add_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_outlays.md)
  – they are an additional measure, never the panel measure.

The measures that must never be summed as revenue: `potential_value`,
`base_and_all_options_value`, `current_total_value_of_award`,
`total_funding_amount`. These are ceilings. The pilot holds \$115bn of
IDV ceiling value against \$0.75bn actually obligated on those vehicles
– a ceiling-based panel would overstate contract revenue by two orders
of magnitude.

## Examples

``` r
us_money_column("obligation")
#> [1] "federal_action_obligation"
```
