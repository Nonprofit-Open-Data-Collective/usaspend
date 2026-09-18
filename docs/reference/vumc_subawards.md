# Vanderbilt University Medical Center: subaward rows, both directions

All FSRS subaward report lines touching VUMC: 3,212 rows from the
recipient-filtered bulk download (VUMC as *subawardee* – inbound), plus
7,182 rows fetched by prime award with
[`us_fetch_subawards_batch()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_batch.md)
(VUMC as *prime* – outbound pass-through). The two pulls are needed
because a recipient-filtered download never returns outbound rows.

## Usage

``` r
vumc_subawards
```

## Format

A `data.table` with 10,394 rows matching `us_schema("subawards")`. Key
fields:

- subaward_key:

  Composite dedup key (prime award \| subaward number \| action date).

- prime_award_key, prime_award_id:

  The prime award the money flows under.

- prime_uei, prime_name:

  The prime awardee (VUMC on outbound rows).

- subawardee_uei, subawardee_name:

  Who received the subaward (VUMC on inbound rows). Often `NA` for
  government subawardees.

- subaward_amount, subaward_action_date, subaward_year,
  subaward_fiscal_year:

  Committed amount and when it was committed – the booking basis.

- report_year, report_month, report_last_modified:

  FSRS reporting vintage; lags the action date, sometimes across fiscal
  years.

- prime_award_amount, prime_awarding_agency_name, prime_cfda_numbers:

  Context carried from the prime award.

- direction:

  `NA` until
  [`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)
  assigns it.

## Details

`direction` is `NA` on purpose: it cannot be inferred from a row alone.
[`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)
assigns it (`in` / `out` / `internal` / `unrelated`) given the
organization's UEI set, and de-duplicates the FSRS monthly restatements
on `subaward_key`.

## See also

[vumc_transactions](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_transactions.md),
[vumc_panel](https://nonprofit-open-data-collective.github.io/usaspend/reference/vumc_panel.md),
[`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)

## Examples

``` r
sb <- us_normalize_subawards(vumc_subawards,
                             org_uei = unique(vumc_transactions$recipient_uei))
#> Normalized 10394 -> 9603 subaward rows (791 duplicates removed).
#> • in=2498 internal=17 out=7088
sb[, .(rows = .N, dollars = sum(subaward_amount, na.rm = TRUE)),
   by = direction]
#>    direction  rows    dollars
#>       <char> <int>      <num>
#> 1:        in  2498  612928484
#> 2:       out  7088 2156331916
#> 3:  internal    17    4453486
```
