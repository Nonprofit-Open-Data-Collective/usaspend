# List available annual archive files

List available annual archive files

## Usage

``` r
us_archive_manifest(
  fiscal_year = NULL,
  type = c("assistance", "contracts"),
  full_only = TRUE
)
```

## Arguments

- fiscal_year:

  Integer vector of fiscal years. `NULL` returns whatever the endpoint
  offers for the current year.

- type:

  `"assistance"`, `"contracts"`, or both.

- full_only:

  Drop the incremental "Delta" files.

## Value

A `data.table` with `fiscal_year`, `type`, `file_name`, `url`,
`updated_date`, `is_delta`.

## Examples

``` r
if (FALSE) { # \dontrun{
us_archive_manifest(2024)
} # }
```
