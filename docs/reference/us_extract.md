# Extract raw award data for a set of UEIs

The single entry point for acquisition. Both paths return the same
canonical tables, so downstream normalization does not know or care
which was used.

## Usage

``` r
us_extract(
  uei,
  years = 2008:2025,
  award_types = us_award_type_codes("all"),
  source = c("auto", "api", "archive"),
  subawards = c("in", "none", "out", "both"),
  subsidiaries = FALSE,
  dest = us_cache_dir("raw")
)
```

## Arguments

- uei:

  Character vector of UEIs.

- years:

  Integer vector of fiscal years.

- award_types:

  Award type codes; defaults to all.

- source:

  `"auto"`, `"api"`, or `"archive"`.

- subawards:

  `"none"`, `"in"` (subawards received: free by-product on the API path;
  on the archive path appended via
  [`us_fetch_subawards_in()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_in.md),
  which count-screens each UEI batch and fetches only where inbound rows
  exist), `"out"` (pass-through paid: queried by prime award from either
  path), or `"both"`.

- subsidiaries:

  Also extract the full histories of subsidiaries the parent-UEI match
  surfaces, and count them as part of their parent organization. API
  path only. See the Subsidiaries section.

- dest:

  Directory for intermediate files. Defaults to the package cache.

## Value

A list of class `usaspend_extract` with elements `transactions`,
`subawards`, `jobs` (the acquisition manifest), `org_map` (the UEI
crosswalk: requested UEIs and discovered subsidiaries, see
[`us_find_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_find_subsidiaries.md))
and `meta`. `meta$uei` is every UEI whose own history was extracted;
`meta$uei_requested` is the original request.

## Details

- `"api"`:

  Submits bulk-download jobs to `POST /api/v2/download/transactions/`.
  Right for one organization or a small batch. Returns prime
  transactions and, as a by-product, subawards where the queried UEI is
  the *subawardee*.

- `"archive"`:

  Downloads the annual Award Data Archive files and filters them locally
  with duckdb. Right for large batches: the cost is fixed in the number
  of fiscal years rather than the number of recipients. Prime
  transactions only – there is no bulk subaward file.

- `"auto"`:

  Picks whichever
  [`us_extract_plan()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract_plan.md)
  estimates as cheaper.

Subawards *paid out* – the pass-through figure needed to compute net
revenue – are not available from either bulk path. Set
`subawards = "out"` to walk the resulting award keys through
[`us_fetch_subawards_out()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_out.md),
which costs roughly one extra API call per award and is screened so that
awards reporting no subawards are skipped.

## Subsidiaries

On the API path the recipient filter also matches a transaction's
*parent* UEI (see
[`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md)):
querying a parent organization returns the transactions its subsidiaries
filed while it was recorded as parent, but not their earlier history.
Every such subsidiary is recorded in the crosswalk `org_map` (see
[`us_find_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_find_subsidiaries.md)),
mapped to the requested UEI it rolls up to.

With `subsidiaries = FALSE` (the default) their own histories are not
pulled, and the extract says so when it finishes:
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
leaves their awards out of the panel and
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
labels them `"out_of_sample"`, because a truncated history cannot
reconcile. With `subsidiaries = TRUE` each subsidiary UEI is queried in
its own right (full history, as
[`us_add_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_subsidiaries.md)
does) and added to the requested set, so the panel counts it as part of
its parent organization. See
[`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md).

The archive path filters on `recipient_uei` locally, so it neither
receives subsidiaries' rows nor discovers them.

## Examples

``` r
if (FALSE) { # \dontrun{
# one organization, the API path
ex <- us_extract("CFFMYPABYAG3", years = 2015:2025)

# a batch, using the annual archives, with pass-through subawards
ueis <- readLines("TOP1000-UEIS.txt")
ex <- us_extract(ueis, years = 2008:2025, source = "archive", subawards = "out")
} # }
```
