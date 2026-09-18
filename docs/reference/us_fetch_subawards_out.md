# Subawards paid out by a prime award

**This is not the same thing as the subaward files that come back from
the bulk download endpoint.** Filtering `/download/transactions/` on
`recipient_search_text` returns subawards where your UEI is the
*subawardee* – money flowing in. Verified twice: a three-UEI probe
returned 32 subaward rows, all inbound; the full 50-org pilot returned
39,243 rows, every one inbound or internal, zero outbound.

## Usage

``` r
us_fetch_subawards_out(award_key, screen = TRUE, page_limit = 100)
```

## Arguments

- award_key:

  Character vector of generated unique award ids.

- screen:

  Check `subaward_count` first and skip awards that report none.

- page_limit:

  Records per page (API maximum 100).

## Value

A `data.table` with one row per subaward: `award_key`,
`subaward_number`, `subaward_action_date`, `subaward_amount`,
`subawardee_name`, `description`.

## Details

To measure pass-through – money the organization is obliged to pay
onward, which must be netted out of revenue – you have to query by prime
award. There is no bulk file for this; the annual Award Data Archive
contains prime transactions only.

For many awards use
[`us_fetch_subawards_batch()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_batch.md),
which batches hundreds of award ids per query. This per-award walk
survives for one-off inspection of a single award; it screens on
`subaward_count` first unless `screen = FALSE`.

## Examples

``` r
if (FALSE) { # \dontrun{
us_fetch_subawards_out("ASST_NON_4482DRCAP00000001_070")
} # }
```
