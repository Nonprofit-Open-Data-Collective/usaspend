# Prime award overview

Fetches `GET /api/v2/awards/{award_key}/` for one award. This is the
only place USAspending exposes `subaward_count` and
`total_subaward_amount`, which is what makes the pass-through screen in
[`us_fetch_subawards_out()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_out.md)
cheap.

## Usage

``` r
us_fetch_award(award_key)
```

## Arguments

- award_key:

  A generated unique award id, e.g. `"ASST_NON_R01AA025947_075"`.

## Value

A one-row `data.table`, or a row with `error = TRUE` on failure.

## Details

Note that `total_obligation`, `total_outlay` and `total_subaward_amount`
are all award-lifetime figures. They are useful for reconciliation,
never as an annual measure.

## Examples

``` r
if (FALSE) { # \dontrun{
us_fetch_award("ASST_NON_4482DRCAP00000001_070")
} # }
```
