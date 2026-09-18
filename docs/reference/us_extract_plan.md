# Plan an extraction before running it

Compares the two acquisition paths for a given input and recommends one.
The API path costs time proportional to the number of UEIs; the archive
path costs a fixed volume proportional to the number of fiscal years.
They cross over somewhere in the low thousands of UEIs.

## Usage

``` r
us_extract_plan(
  uei,
  years = 2008:2025,
  batch_size = us_opt("batch_size"),
  concurrent = us_opt("concurrent"),
  mbps = 25
)
```

## Arguments

- uei:

  Character vector of UEIs.

- years:

  Integer vector of fiscal years to cover.

- batch_size, concurrent:

  Overrides for the API-path cost model.

- mbps:

  Assumed sustained download throughput, for the archive path.

## Value

A `data.table` comparing the paths, invisibly; the recommendation is
printed and returned in the `recommended` attribute.

## Details

The estimates are order-of-magnitude, built from measured constants: a
bulk-download job took 9-85 seconds server-side, `recipient_search_text`
caps near 20 values (and large recipients fail well below that, hence a
default batch of 5), and `FY2024_All_Assistance_Full` is 1.37 GB
compressed.

## Examples

``` r
us_extract_plan(rep("CFFMYPABYAG3", 40), years = 2015:2025)
#> Recommended path: api.
#> ℹ Crossover for 11 fiscal years is around 1797 UEIs.
#> ℹ Subawards paid out are NOT in the annual archives and always cost extra API
#>   calls -- see `us_fetch_subawards_out()`.
#>       path                                    unit download_gb est_minutes
#>     <char>                                  <char>       <num>       <num>
#> 1:     api 1 download jobs (+5 single-UEI retries)         0.0           2
#> 2: archive                      22 annual archives        30.8         144
#>    disk_gb
#>      <num>
#> 1:    0.01
#> 2:  123.00
```
