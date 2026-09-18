# Map UEIs to organizations

Large nonprofits hold several SAM registrations and USAspending splits
their awards across them, so the organization – not the UEI – is the
unit of analysis. Supply a crosswalk and every downstream table is keyed
on `org_id`. Without one, each UEI is its own organization.

## Usage

``` r
us_org_map(uei, org_map = NULL)
```

## Arguments

- uei:

  Character vector of UEIs.

- org_map:

  Optional two-column `data.frame` of `uei` and `org_id` (an EIN, for
  instance).

## Value

A `data.table` of `uei`, `org_id`.

## Examples

``` r
us_org_map(c("CFFMYPABYAG3", "H7LMD1ANJNN4"))
#>             uei       org_id
#>          <char>       <char>
#> 1: CFFMYPABYAG3 CFFMYPABYAG3
#> 2: H7LMD1ANJNN4 H7LMD1ANJNN4
```
