# Size an archive pull before committing to it

Issues HEAD requests so you can see the download volume before spending
it.

## Usage

``` r
us_archive_size(manifest)
```

## Arguments

- manifest:

  Output of
  [`us_archive_manifest()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_manifest.md).

## Value

The manifest with a `size_mb` column and a printed total.
