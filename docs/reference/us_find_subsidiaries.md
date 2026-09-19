# Find subsidiaries surfaced by the parent-UEI match

The API recipient filter also matches a transaction's *parent* UEI (see
[`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md)),
so an extract holds some transactions of the requested organizations'
subsidiaries – only those filed while a requested UEI was recorded as
their parent. This lists them: every unrequested recipient whose
`recipient_parent_uei` is a requested UEI (or, recursively, an
already-found subsidiary).

## Usage

``` r
us_find_subsidiaries(extract)
```

## Arguments

- extract:

  A `usaspend_extract` from
  [`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md).

## Value

A `data.table`, one row per subsidiary UEI: `uei`, `org_id` (the
requested UEI it rolls up to, until
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
applies an `org_map`), `relationship`, `parent_uei` (the recorded
parent), `root_uei` (the requested UEI at the top of the chain),
`recipient_name`, `extracted` (whether its own full history is in the
extract), and `n_parent_matched` (transactions that arrived through the
parent match).

## Details

[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
records the result in `extract$org_map`; this function rebuilds it for
any extract, including ones made before the crosswalk existed. See
[`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md).

## Examples

``` r
us_find_subsidiaries(us_sample_extract())   # none in the sample
#> Empty data.table (0 rows and 8 cols): uei,org_id,relationship,parent_uei,root_uei,recipient_name...
```
