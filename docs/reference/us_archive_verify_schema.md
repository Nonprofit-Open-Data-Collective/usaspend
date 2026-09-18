# Check that an archive matches the canonical field map

The package assumes the annual archive CSVs carry the same column names
as the bulk download endpoint. That assumption is stated, not measured –
the probe that established the download schema used the API path, and
verifying the archive means unpacking a gigabyte file. Run this once
against a real archive to confirm, and it will tell you exactly which
mapped columns are missing.

## Usage

``` r
us_archive_verify_schema(csv_dir, group = c("assistance", "contract"))
```

## Arguments

- csv_dir:

  Directory of unpacked archive CSVs.

- group:

  `"assistance"` or `"contract"`.

## Value

A `data.table` of `canonical_field`, `raw_column`, `present`.
