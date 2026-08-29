# usaspend

An R package that takes a list of SAM.gov UEIs and returns a clean, normalized
panel of federal award activity from USAspending.gov, at
**organization × award × year** grain.

> **Status: acquisition layer works; the accounting layer is specified but not
> yet implemented.** The normalization and netting functions are documented
> placeholders that fail loudly with a pointer to their specification. They are
> being written against a 50-nonprofit pilot extract. See
> [PLAN.md](PLAN.md) §7 for the roadmap.

## What it does

Transaction data is a ledger of promises: new awards, continuations, revisions,
zero-dollar administrative modifications, and claw-backs. The panel needs one
row per organization, award and year carrying the awarding agency, the award
type, the net dollars obligated in that year, and the dollars passed through as
subawards.

```r
# one organization
ex <- us_extract("CFFMYPABYAG3", years = 2015:2025, subawards = "both")

# a batch, via the annual bulk archives instead of the API
ueis <- readLines("TOP1000-UEIS.txt")
ex   <- us_extract(ueis, years = 2008:2025, source = "archive")

# not implemented yet -- see ACCOUNTING.md
p <- us_panel(ex, org_map = crosswalk, period = "calendar")
```

Not sure which path? `us_extract_plan()` costs both from measured constants and
recommends one; `source = "auto"` follows it. Crossover is around 2,900 UEIs at
18 fiscal years.

## Two acquisition paths, one schema

| | API (`source = "api"`) | Archive (`source = "archive"`) |
|---|---|---|
| endpoint | `POST /api/v2/download/transactions/` | `FY####_All_{Assistance,Contracts}_Full.zip` |
| cost scales with | number of UEIs | number of fiscal years |
| best for | one org, or up to a few thousand UEIs | large batches |
| subawards | inbound only, as a by-product | none |

Both land on the same canonical schema (`us_schema()`), so nothing downstream
knows or cares which was used.

## Three things that will bite you

1. **Obligations are not payments.** The panel measures commitments. Federal
   award data carries no annual cash figure — lifetime outlays only, and those
   are complete only for awards begun after the FY2022 monthly reporting
   mandate (for some agencies not even then). `us_money_column("outlay")`
   errors rather than substituting something close; `us_add_outlays()` can
   attach account-level annual outlays to a fiscal panel as a separate,
   coverage-graded column.
2. **Bulk subawards run the wrong way.** Filtering on `recipient_search_text`
   returns subawards where your UEI is the *subawardee*, not the prime. A
   three-UEI test pull returned 32 subaward rows, all 32 inbound. Pass-through
   has to be queried per prime award — `us_fetch_subawards_out()`.
3. **De-obligations are real and must be kept.** Dropping them inflates every
   affected year. Which year a claw-back lands in is a policy choice, not a
   cleanup step; both policies are implemented and neither is applied silently.

## Documentation

- **[PLAN.md](PLAN.md)** — architecture, both acquisition paths with measured
  constraints, roadmap, open questions
- **[ACCOUNTING.md](ACCOUNTING.md)** — the reconciliation rules: what counts as
  money, netting, de-obligation policy, subaward direction, reconciliation
  invariants

## Install

```r
# install.packages("remotes")
remotes::install_github("Nonprofit-Open-Data-Collective/usaspend")
```

Requires `httr2`, `data.table`, `duckdb`, `DBI` and `cli`.

## Test fixture

`us_sample_extract()` returns a real 152-row three-UEI pull, shipped verbatim.
It is small but already contains an award whose transactions reconcile exactly
to its lifetime total, a de-obligating revision, 30 zero-dollar administrative
modifications, IDV rows with blank award types, unstable description strings,
and a $40M ceiling against $0 obligated. It caught two live bugs during
development.

## License

MIT © Nonprofit Open Data Collective
