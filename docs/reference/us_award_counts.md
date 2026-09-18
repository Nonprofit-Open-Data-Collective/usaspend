# Pre-flight award counts for a set of UEIs

Cheap reconnaissance before committing to a pull: how many prime awards
each UEI has, by category. Use it to decide between the API and the
archive path, to size download batches, and to distinguish genuine
non-recipients from failed requests.

## Usage

``` r
us_award_counts(uei, start_date = "2007-10-01", end_date = Sys.Date())
```

## Arguments

- uei:

  Character vector of UEIs.

- start_date, end_date:

  Action-date bounds.

## Value

A `data.table`: one row per UEI with `contracts`, `idvs`, `grants`,
`direct_payments`, `loans`, `other`, `n_awards`, `error`, `message`.

## Details

Failures are recorded, never swallowed. A request that errors comes back
with `error = TRUE` and `n_awards = NA`, because a failure that reads as
zero is the most damaging silent bug in this pipeline – it turns a
rate-limit blip into a permanent "this nonprofit gets no federal money".

## Examples

``` r
if (FALSE) { # \dontrun{
us_award_counts(c("CFFMYPABYAG3", "H7LMD1ANJNN4"))
} # }
```
