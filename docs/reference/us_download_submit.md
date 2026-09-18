# Submit a bulk transaction download job

Submits one job to `POST /api/v2/download/transactions/` and returns the
server-assigned file name, which is the job handle.

## Usage

``` r
us_download_submit(
  uei,
  award_types = us_award_type_codes("all"),
  start_date = "2007-10-01",
  end_date = Sys.Date()
)
```

## Arguments

- uei:

  Character vector of UEIs (at most 20).

- award_types:

  Award type codes to include. Defaults to every type.

- start_date, end_date:

  Bounds on `action_date`. USAspending award search is floored at
  2007-10-01; earlier data needs the Custom Award Download or the full
  database.

## Value

A single string, the job file name, or `NA` if submission failed.

## Details

`recipient_search_text` is capped near 20 values by the API, and that
cap is undocumented. In practice large recipients time out server-side
well below the cap, so
[`us_download_run()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_run.md)
defaults to 5 UEIs per job and retries failures one UEI at a time.
