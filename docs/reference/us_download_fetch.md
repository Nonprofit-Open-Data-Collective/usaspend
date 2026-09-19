# Download and unzip finished jobs

Download and unzip finished jobs

## Usage

``` r
us_download_fetch(jobs, dest = us_cache_dir("raw"))
```

## Arguments

- jobs:

  Manifest from
  [`us_download_run()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_run.md).

- dest:

  Directory for the unzipped CSVs. Defaults to the package cache.

## Value

Character vector of the CSV paths in `dest`, with attribute `fetched`:
the job file names that were downloaded and unzipped. A job that failed
either step is warned about and left out of `fetched`.
