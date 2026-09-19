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

- dest:

  Directory for intermediate files. Defaults to the package cache.

## Value

A list of class `usaspend_extract` with elements `transactions`,
`subawards`, `jobs` (the acquisition manifest) and `meta`.

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
