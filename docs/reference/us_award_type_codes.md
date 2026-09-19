# Award type codes accepted by the download endpoints

Award type codes accepted by the download endpoints

## Usage

``` r
us_award_type_codes(group = "all")
```

## Arguments

- group:

  One or more of `"contract"`, `"idv"`, `"grant"`, `"direct_payment"`,
  `"loan"`, `"other"`, `"assistance"` (grant + direct payment + loan +
  other), or `"all"`.

## Value

Character vector of award type codes.

## Examples

``` r
us_award_type_codes("grant")
#> [1] "02" "03" "04" "05"
length(us_award_type_codes("all"))
#> [1] 22
```
