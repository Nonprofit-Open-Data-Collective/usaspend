# Harmonize raw USAspending files to the canonical schema

Both acquisition paths – the REST download endpoint and the annual Award
Data Archive – emit the same underlying CSV layouts, so one harmonizer
serves both. Raw columns are read as character and cast explicitly here;
nothing is guessed by a CSV reader.

## Usage

``` r
us_harmonize_transactions(
  raw,
  group = c("assistance", "contract"),
  source_file = NA_character_
)

us_harmonize_subawards(
  raw,
  group = c("assistance", "contract"),
  source_file = NA_character_
)
```

## Arguments

- raw:

  A `data.frame`/`data.table` of raw USAspending columns, read as
  character.

- group:

  `"assistance"` or `"contract"`.

- source_file:

  Optional provenance label carried onto every row.

## Value

A `data.table` matching `us_schema("transactions")` or
`us_schema("subawards")`.

## Details

One measured divergence between the paths is repaired here: archive
*contract* files transpose the `action_type_code`/`action_type` and
`idv_type_code`/`idv_type` column pairs (codes and descriptions swap
places). The swap is detected from the values themselves and undone
before mapping, so both sources classify identically.

Derived on the way through:

- `award_group` from the file family (contract vs assistance).

- `award_type_label` / `award_family` from the code, with
  `idv_type_code` as a fallback because contract IDV rows carry a blank
  award type code.

- `action_type_label` / `action_class` from the code *and* the family,
  because the codes collide across families.

- `action_year` (calendar) and `action_fiscal_year` from `action_date`.
  The fiscal year is recomputed rather than trusting the source column.

- `pragmatic_obligation`, which USAspending supplies for assistance
  (`generated_pragmatic_obligations`, equal to the loan subsidy cost for
  loans and to the obligation otherwise) but not for contracts, where
  the obligation is copied in.

This is a mechanical reshape. It applies no accounting rules – no
de-duplication, no correction or delete handling, no netting. Those live
in
[`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md)
and are specified in `ACCOUNTING.md`.
