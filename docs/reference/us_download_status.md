# Poll a download job

Poll a download job

## Usage

``` r
us_download_status(file_name)
```

## Arguments

- file_name:

  Job handle from
  [`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md).

## Value

A list with `status`, and when finished, `total_rows` and `file_url`. A
transient transport failure is reported as `status = "running"` on
purpose: a dropped poll must never be mistaken for a failed job.
