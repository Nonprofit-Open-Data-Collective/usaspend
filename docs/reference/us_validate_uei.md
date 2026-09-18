# Validate a vector of UEIs

A SAM.gov Unique Entity Identifier is 12 alphanumeric characters. This
checks shape only – it cannot tell you whether an entity exists.

## Usage

``` r
us_validate_uei(uei, strict = TRUE)
```

## Arguments

- uei:

  Character vector of UEIs.

- strict:

  If `TRUE` (default), malformed UEIs raise an error. If `FALSE`, they
  are returned as `NA` with a warning.

## Value

Character vector of cleaned UEIs, same length as `uei`.

## Examples

``` r
us_validate_uei("cffmypabyag3")
#> [1] "CFFMYPABYAG3"
```
