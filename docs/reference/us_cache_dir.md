# Cache location

Everything `usaspend` downloads is written under a cache directory so
that a re-run costs nothing. Annual archives in particular are 1-2 GB
each and must never be re-fetched by accident.

## Usage

``` r
us_cache_dir(..., create = TRUE)

us_cache_clear(what = c("jobs", "raw", "archive", "parquet", "duckdb", "all"))

us_cache_status()
```

## Arguments

- ...:

  Path components appended to the cache root.

- create:

  Create the directory if it does not exist.

- what:

  Which subdirectory to clear, or `"all"`.

## Value

A file path.

## Details

Layout:

    <cache>/jobs/      API download job zips and their manifests
    <cache>/raw/       unzipped CSVs from API jobs
    <cache>/archive/   annual Award Data Archive zips
    <cache>/parquet/   archive CSVs converted to partitioned parquet
    <cache>/duckdb/    on-disk duckdb databases
