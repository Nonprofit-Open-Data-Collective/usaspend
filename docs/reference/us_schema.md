# Canonical table schemas

`usaspend` normalizes every source into four tables. `us_schema()`
returns the column contract for one of them; `us_empty()` returns a
correctly typed zero-row table, which is what the not-yet-implemented
normalization functions will fill.

## Usage

``` r
us_schema(table = c("transactions", "subawards", "awards", "panel", "funding"))

us_empty(table = c("transactions", "subawards", "awards", "panel", "funding"))
```

## Arguments

- table:

  Which schema to return.

## Value

A `data.table` of `field` and `type` (`us_schema()`), or a zero-row
`data.table` with those columns (`us_empty()`).

## Details

- `transactions`:

  One row per award action. The only grain that supports an annual
  panel.

- `subawards`:

  One row per FSRS subaward report line.

- `awards`:

  One row per prime award – the spine.

- `panel`:

  One row per organization x award x year – the deliverable.

- `funding`:

  One row per account-level (File C) record for an award: federal
  account x period, from
  [`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md).
  The only place annual outlays exist.

## Examples

``` r
us_schema("panel")
#>                        field      type
#>                       <char>    <char>
#>  1:                   org_id character
#>  2:                award_key character
#>  3:                     year   integer
#>  4:               year_basis character
#>  5:              award_group character
#>  6:             award_family character
#>  7:          award_type_code character
#>  8:         award_type_label character
#>  9:     awarding_agency_code character
#> 10:     awarding_agency_name character
#> 11: awarding_sub_agency_name character
#> 12:      funding_agency_name character
#> 13:              cfda_number character
#> 14:               naics_code character
#> 15:          recipient_state character
#> 16:           n_transactions   integer
#> 17:       n_actions_positive   integer
#> 18:       n_actions_negative   integer
#> 19:      obligation_positive   numeric
#> 20:      obligation_negative   numeric
#> 21:           obligation_net   numeric
#> 22:  deobligation_prior_year   numeric
#> 23:          loan_face_value   numeric
#> 24:        loan_subsidy_cost   numeric
#> 25:      subaward_out_amount   numeric
#> 26:          n_subawards_out   integer
#> 27:       subaward_in_amount   numeric
#> 28:           n_subawards_in   integer
#> 29:              net_revenue   numeric
#> 30:                    flags character
#>                        field      type
#>                       <char>    <char>
str(us_empty("transactions"))
#> Classes 'data.table' and 'data.frame':   0 obs. of  48 variables:
#>  $ transaction_key           : chr 
#>  $ award_key                 : chr 
#>  $ parent_award_id           : chr 
#>  $ award_group               : chr 
#>  $ award_family              : chr 
#>  $ award_type_code           : chr 
#>  $ award_type_label          : chr 
#>  $ award_id                  : chr 
#>  $ award_id_uri              : chr 
#>  $ modification_number       : chr 
#>  $ action_date               : 'Date' num(0) 
#>  $ action_year               : int 
#>  $ action_fiscal_year        : int 
#>  $ action_type_code          : chr 
#>  $ action_type_label         : chr 
#>  $ action_class              : chr 
#>  $ transaction_description   : chr 
#>  $ correction_delete_code    : chr 
#>  $ record_type_code          : chr 
#>  $ federal_action_obligation : num 
#>  $ pragmatic_obligation      : num 
#>  $ non_federal_funding_amount: num 
#>  $ loan_face_value           : num 
#>  $ loan_subsidy_cost         : num 
#>  $ award_total_obligated     : num 
#>  $ award_total_outlayed      : num 
#>  $ base_and_all_options_value: num 
#>  $ recipient_uei             : chr 
#>  $ recipient_name            : chr 
#>  $ recipient_parent_uei      : chr 
#>  $ recipient_state           : chr 
#>  $ awarding_agency_code      : chr 
#>  $ awarding_agency_name      : chr 
#>  $ awarding_sub_agency_code  : chr 
#>  $ awarding_sub_agency_name  : chr 
#>  $ awarding_office_code      : chr 
#>  $ awarding_office_name      : chr 
#>  $ funding_agency_code       : chr 
#>  $ funding_agency_name       : chr 
#>  $ cfda_number               : chr 
#>  $ cfda_title                : chr 
#>  $ naics_code                : chr 
#>  $ psc_code                  : chr 
#>  $ pop_start_date            : 'Date' num(0) 
#>  $ pop_end_date              : 'Date' num(0) 
#>  $ pop_potential_end_date    : 'Date' num(0) 
#>  $ last_modified_date        : 'Date' num(0) 
#>  $ source_file               : chr 
#>  - attr(*, ".internal.selfref")=<externalptr> 
```
