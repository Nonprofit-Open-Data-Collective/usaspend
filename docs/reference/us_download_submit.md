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

## `recipient_search_text` also matches the parent UEI

**measured** The filter matches a transaction whose `recipient_uei` *or*
`recipient_parent_uei` is one of `uei`. Querying a parent organization
therefore returns its subsidiaries' transactions too – but only the ones
filed while that parent was recorded as the parent. Querying RTI
(`JJHCMK4NT5N3`) returned transactions of International Resources Group
(`R29FEFR7P8H9`), which RTI acquired in 2017: of the 14 transactions on
`CONT_AWD_AIDEPPI110300013_7200_AIDEPPI000300013_7200`, all with IRG as
recipient, only the 2 carrying RTI as parent came back; the earlier
ones, filed under parents L-3 and Engility, did not. A subsidiary's
awards thus arrive with truncated histories.
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
keeps only UEIs in the organization map and flags the rest
(`awards$in_sample`), and
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
labels their awards `"out_of_sample"`, unless their full histories are
pulled with `us_extract(subsidiaries = TRUE)` or
[`us_add_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_subsidiaries.md).
