# Run a set of download jobs to completion

Batches UEIs into jobs, keeps a bounded number in flight, polls each to
a terminal state, then retries any failed batch one UEI at a time – a
single oversized recipient otherwise poisons its whole batch.

## Usage

``` r
us_download_run(
  uei,
  award_types = us_award_type_codes("all"),
  start_date = "2007-10-01",
  end_date = Sys.Date(),
  batch_size = us_opt("batch_size"),
  concurrent = us_opt("concurrent"),
  timeout_min = 120,
  retry_singly = TRUE
)
```

## Arguments

- uei:

  Character vector of UEIs.

- award_types:

  Award type codes.

- start_date, end_date:

  Action-date bounds.

- batch_size:

  UEIs per job. Default from `usaspend.batch_size`.

- concurrent:

  Jobs in flight. Default from `usaspend.concurrent`.

- timeout_min:

  Give up after this many minutes.

- retry_singly:

  Retry failed batches one UEI at a time.

## Value

A `data.table` job manifest: one row per job with `state`, `rows`,
`url`, and the UEIs it covered. Jobs that never finished are kept in the
manifest with their failure state – they are not dropped, because a
swallowed failure is indistinguishable from a recipient with no awards.
