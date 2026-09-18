# Batched outbound subaward fetch

The efficient way to get pass-through for a whole extract. Instead of
one request per award, this filters
`POST /api/v2/search/spending_by_award/` with `subawards = TRUE` on
batches of prime `award_ids` – measured cap: 500 ids per request
succeeds, 1,000 returns HTTP 503; the default batch of 400 leaves
headroom. On the 50-org pilot this reduced 61,738 per-award calls to
under 200 requests.

## Usage

``` r
us_fetch_subawards_batch(awards, batch_size = 400, cap_guard = 9000)
```

## Arguments

- awards:

  The award spine from
  [`us_normalize_awards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_awards.md),
  or any `data.frame` with `award_key` and `award_id` columns.

- batch_size:

  Prime award ids per request (max ~500).

- cap_guard:

  Split a batch when its subaward count exceeds this.

## Value

A `data.table` matching `us_schema("subawards")`, one row per outbound
subaward, with `prime_uei` filled from the spine when available so
[`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md)
can classify direction.

## Details

Three safeguards, all measured:

- **Assistance and contract type codes cannot be mixed.** With
  `subawards = TRUE`, the *result* endpoint returns HTTP 422 when
  `award_type_codes` spans both families – while the *count* endpoint
  accepts the mix, which makes the failure silent if unhandled. The
  fetch therefore runs one pass per family.

- **The 10k result cap is per filter set.** Each batch is counted first
  (`spending_by_award_count`, `subawards = TRUE`); a batch whose count
  nears the cap is split recursively, so nothing silently truncates.

- **FAINs and PIIDs are ambiguous.** `award_ids` matches the bare id,
  which different agencies can reuse, so results are filtered back to
  the exact `prime_award_generated_internal_id` values in `awards`.
  Strays are dropped, not kept.

## Examples

``` r
if (FALSE) { # \dontrun{
aw <- us_normalize_awards(tx)
out <- us_fetch_subawards_batch(aw)
} # }
```
