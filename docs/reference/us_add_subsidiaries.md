# Extract the full histories of an extract's subsidiaries

Pulls, through the API, every subsidiary UEI in the extract's crosswalk
whose own history is not yet in it, and adds them to the requested set
so
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
counts them as part of their parent organization. Equivalent to having
run
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
with `subsidiaries = TRUE`, without repeating the main pull.

## Usage

``` r
us_add_subsidiaries(extract, max_rounds = 3L, dest = us_cache_dir("raw"))
```

## Arguments

- extract:

  A `usaspend_extract` from
  [`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md).

- max_rounds:

  A subsidiary's own pull can surface subsidiaries of its own; they are
  pulled in further rounds, up to this many in total.

- dest:

  Directory for intermediate files. Defaults to the package cache.

## Value

The extract with transactions (and, per `meta$subawards`, subawards)
added, `org_map` updated, and `meta$uei` extended; `meta$uei_requested`
keeps the original request.

## Details

A query on the subsidiary's own UEI returns its whole history, including
years before the parent relationship existed (for an acquired firm, the
years before the acquisition). Those years are counted to the parent
organization; see
[`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md)
for how to drop them.

## Examples

``` r
if (FALSE) { # \dontrun{
ex <- us_extract("JJHCMK4NT5N3", years = 2008:2025)   # RTI
us_find_subsidiaries(ex)                               # IRG, among others
ex <- us_add_subsidiaries(ex)
} # }
```
