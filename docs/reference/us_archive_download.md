# Download and unpack annual archives

Archives are cached under `us_cache_dir("archive")` and never re-fetched
if present – these are gigabyte files and an accidental re-download is
expensive.

## Usage

``` r
us_archive_download(manifest, unpack = TRUE)
```

## Arguments

- manifest:

  Output of
  [`us_archive_manifest()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_manifest.md).

- unpack:

  Unzip after downloading.

## Value

The manifest with `zip_path` and `csv_dir` columns.

## Details

A cached zip is trusted only if its central directory reads back cleanly
(`unzip(list = TRUE)`); a truncated file from an interrupted download is
deleted and re-fetched rather than silently unpacked. Downloads run with
`timeout` raised to `usaspend.download_timeout` (default 3600 s) – R's
60-second default truncates gigabyte files mid-stream – and a failed or
short download is removed instead of being left to masquerade as a cache
hit.
