# Filter unpacked archives down to a set of UEIs

Streams the archive CSVs through duckdb, keeps only rows whose
`recipient_uei` is in `uei`, and harmonizes the result to
`us_schema("transactions")`. Memory stays bounded because duckdb reads
the CSVs lazily and the UEI list is joined as a table rather than pasted
into a giant `IN` clause.

## Usage

``` r
us_archive_filter(
  uei,
  csv_dir,
  group = c("assistance", "contract"),
  memory_limit = "8GB",
  parquet_out = NULL
)
```

## Arguments

- uei:

  Character vector of UEIs to keep.

- csv_dir:

  One or more directories of unpacked archive CSVs.

- group:

  `"assistance"` or `"contract"` – which family these files hold.

- memory_limit:

  duckdb memory ceiling.

- parquet_out:

  Optional path; if given, the filtered rows are also written to parquet
  so later runs skip the CSV scan entirely.

## Value

A `data.table` matching `us_schema("transactions")`.
