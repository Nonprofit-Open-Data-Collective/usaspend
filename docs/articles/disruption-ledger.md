# Disruption on the ledger

How the awards that were targeted after 20 January 2025 changed
administratively: the notices, schedule cuts and missing money, set
against the same awards' history and against a normal year (the cohort
running on 20 January 2023, followed for the same days).

Data through Draft · preliminary

A companion to [Nonprofit award disruption,
2025–26](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption-2025.md),
built from the same cohorts, categories and flags. The ledger signals
are the ones
[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md)
defines (see
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md)),
computed here on all 1.47 million actions of both cohorts; the tables
are pre-computed from the nonprofit database, which is not shipped with
the package.

## Ten awards, start to finish

Each row is one award picked by rule from the 2025 cohort: an award with
File C outlays in at least three quarters before January 2025, closest
to \$1.5 million obligated, matching the pattern named on the left.
Hover a mark for the action and its description text.

Ledger actions, schedule and cash, October 2023 – December 2027

Grey bar: the end date in force on 20 January 2025. Dark line: the end
date now. Blue blocks underneath: cash paid out each quarter (File C),
scaled within each award.

Award identifiers and recipient names are in the hover cards.

## The ledger, month by month

Actions per 1,000 cohort awards per month, months from the cohort start

Month 0 is 20 January 2023 or 20 January 2025. Three-month moving
average. The shaded months at the right are still filling in
(USAspending posts actions up to ~90 days late).

2023 cohort2025 cohort

## Disrupted awards against the rest of their cohort

Actions per 1,000 awards in each category per month, 2025 cohort

The not-disrupted line falls too after month 0, because every cohort
award is getting closer to its end date. Read each category against it.

## Where the change is concentrated

Change in the share of active awards in each category, 2025 minus 2023,
percentage points

Agencies with at least 300 active awards in both cohorts, sorted by the
change in terminations. Faded cells are within sampling noise
(two-proportion test, \|z\| \< 2).

## How far schedules moved

Change in the end date over the window, share of active awards per
three-month bin

Square-root bar heights, so the small cut bars stay visible next to
routine one-year extensions. Changes under one month are left out.

All awards

Grants

Contracts

End date pulled earlierExtended

## Waiting for next year’s money

Share of continuation awards funded, by days from the due date

Annually funded assistance awards whose next increment fell due inside
the window (one year after the last funding before the cohort start).
Due date = day 0.

2023 cohort2025 cohort

## Sources

USAspending annual award archives FY2008–FY2026 (generated 2026-09-06)
filtered to the npmatch nonprofit crosswalk; File C account outlays via
`POST /awards/funding/`. Cohorts, categories and flags as in the main
report (flags v2); ledger signals from
[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md).
Tables built by pipeline stage 29 (`29_disruption_visuals.R` →
`visuals_tables.json`) on .
