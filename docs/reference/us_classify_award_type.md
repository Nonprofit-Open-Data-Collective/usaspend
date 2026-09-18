# Classify award type codes

Maps a USAspending award type code to a stable label, an award family
(contract / idv / grant / direct_payment / loan / other) and the
top-level group (contract vs assistance).

## Usage

``` r
us_classify_award_type(award_type_code, idv_type_code = NULL)
```

## Arguments

- award_type_code:

  Character vector of award type codes.

- idv_type_code:

  Optional character vector of IDV type codes, used where
  `award_type_code` is missing. Accepted bare (`"B"`) or prefixed
  (`"IDV_B"`).

## Value

A `data.table` with one row per input and columns `award_type_code`,
`award_type_label`, `award_family`, `award_group`.

## Details

Contract IDV rows carry a blank award type code – their type lives in
`idv_type_code` instead. Pass `idv_type_code` and it is used as a
fallback. Note that FPDS writes the IDV type as a bare letter (`"B"`,
`"E"`), which collides with the contract codes for Purchase Order and
Definitive Contract, so the fallback prefixes `IDV_` before looking the
code up.

## Examples

``` r
us_classify_award_type(c("04", "D", "IDV_B", NA))
#>    award_type_code    award_type_label award_family award_group
#>             <char>              <char>       <char>      <char>
#> 1:              04       Project Grant        grant  assistance
#> 2:               D Definitive Contract     contract    contract
#> 3:           IDV_B                 IDC          idv    contract
#> 4:            <NA>             Unknown      unknown     unknown
```
