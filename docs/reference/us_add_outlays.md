# Attach annual outlays to a panel

Adds a cash layer to a fiscal-year panel: `outlay_amount` per
org-award-year plus a per-award `outlay_coverage` grade, leaving
`obligation_net` and `net_revenue` untouched – outlays are a *separate
measure* of the same award, never a substitute (measured on VUMC FY2022+
awards, two-thirds of an award's dollars land in a different year under
outlays than under obligations, and cash lags commitment by about a
year).

## Usage

``` r
us_add_outlays(panel, funding = NULL, fill_gaps = TRUE, tolerance = 0.25)
```

## Arguments

- panel:

  A `usaspend_panel` built with `period = "fiscal"` – File C reports
  federal fiscal periods and has no calendar-year form.

- funding:

  Optional prefetched funding table from
  [`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md);
  when `NULL`, funding is fetched for every award in the panel (one
  paged request per award).

- fill_gaps:

  Add zero-obligation rows for outlay-years the panel does not cover.

- tolerance:

  Linkage screen: relative gap between File C lifetime obligations and
  the award's own allowed before the award is graded `"unlinked"`.

## Value

The panel with `outlay_amount` and `outlay_coverage` columns, a new
`outlays` element (the award x fiscal-year table from
[`us_outlays_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlays_by_year.md)),
and `meta$outlays` recording the coverage tally.

## Coverage grades, one per award

- `"complete"`:

  First panel activity FY2022+ (inside the monthly reporting mandate),
  File C obligations reconcile with the award's own transactions, outlay
  rows present.

- `"truncated_pre_FY2022"`:

  Linked and reporting, but the award predates the FY2022 mandate:
  pre-mandate outlays were never reported, so early years are `NA` and
  the lifetime sum is a floor.

- `"unlinked"`:

  File C obligations differ from the award's transaction ledger by more
  than `tolerance` – the outlay values describe money that cannot be
  reconciled to this award. Kept, flagged.

- `"no_outlay_rows"`:

  File C records exist but none carry an outlay (typical for
  pre-mandate-only reporters). All `outlay_amount` is `NA`.

- `"no_file_c"`:

  The endpoint returned no records at all (VA and DoD portfolios,
  mostly). All `NA`.

- `"fetch_failed"`:

  The request errored. All `NA` – a failure is never read as an empty
  result.

## Zero versus NA

`outlay_amount` is `0` only where a zero was plausibly *measured*: years
inside the award's reporting window (FY2022+, or any year with File C
outlay rows) for awards that report outlays. Years before the mandate
and awards with no outlay reporting are `NA`, so a missing measurement
is never mistaken for "no cash moved".

## Trailing cash years

Outlays lag obligations, so an award's cash routinely arrives after its
last obligation year – years the panel has no row for. With
`fill_gaps = TRUE` (the default, unlike
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
where trailing years are the exception) those years get zero-obligation
rows flagged `"outlay_only_year"`, attributed to the award's dominant
organization. With `fill_gaps = FALSE` those outlay dollars are dropped
and a message reports how much.

## Examples

``` r
if (FALSE) { # \dontrun{
p <- us_panel(ex, period = "fiscal")
p <- us_add_outlays(p)
p$panel[outlay_coverage == "complete",
        .(oblig = sum(obligation_net), cash = sum(outlay_amount)), by = year]
} # }
```
