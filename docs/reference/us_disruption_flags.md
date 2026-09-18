# Flag disruption signals on a transaction ledger

Adds one logical column per disruption signal to a canonical transaction
table, organized by the four-part taxonomy of
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md).
Flags are per *action*; aggregate them by award, agency, or period to
measure disruption. Nothing is dropped or netted.

## Usage

``` r
us_disruption_flags(transactions, early_days = 60L, cut_days = 30L)
```

## Arguments

- transactions:

  A `data.table` matching `us_schema("transactions")`, ideally from
  [`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md).
  The description and ceiling fields must be present for the text and
  ceiling flags; extracts harmonized before those fields existed get
  `FALSE` there.

- early_days:

  Days before the scheduled end within which a de-obligation still
  counts as routine.

- cut_days:

  Minimum end-date move, in days, for a cut or extension.

## Value

The input, ordered by award and action date, with the `dsr_*` logical
columns and the helper columns added.

## Details

The flags are deliberately literal – each is one observable property of
a single action – so they can be combined, audited against the
description text, and compared against a pre-period baseline. None of
them is proof of a policy decision on its own: an end-date cut is
routine on a supply order, and closeouts happen every year. Disruption
is a *change in the rate* of these actions, which is how the vignette
uses them.

## Termination signals

- `dsr_term_code`:

  Contract action type `E` (terminate for default), `F` (terminate for
  convenience) or `N` (legal contract cancellation). Assistance has no
  termination code.

- `dsr_term_text`:

  Termination or cancellation language in `transaction_description`
  (excluding "determination" and clause citations). The only formal
  termination signal for grants.

- `dsr_rescinded`:

  Language rescinding or reinstating a termination.

- `dsr_closeout`:

  Contract action type `K` (close out).

## Reduction signals

- `dsr_early_deob`:

  Negative obligation dated more than `early_days` before the scheduled
  end the action interrupts – money withdrawn from a live award, not a
  post-performance closeout.

- `dsr_end_cut`:

  The period-of-performance end moved *earlier* by more than `cut_days`
  and by at least a quarter of the remaining schedule.

- `dsr_ceiling_cut`:

  Negative `base_and_all_options_value`: the contract's potential value
  reduced (contracts only).

## Delay signals

- `dsr_extension`:

  End date moved *later* by more than `cut_days`.

- `dsr_stop_work`:

  Stop-work or suspension language in the description.

- `dsr_admin`:

  A zero-dollar action classed administrative – the category stop-work
  orders and notices are usually filed under.

Missed or late payments are properties of the *gaps between* actions and
of File C outlays, not of any single row; the vignette measures them at
the award level.

## Transfer signals

- `dsr_novation`:

  Contract action type `J`: same contract, new vendor.

- `dsr_transfer`:

  Contract action type `T` (transfer action), used to move an award's
  funds between agencies.

- `dsr_agency_change`:

  Awarding agency differs from the award's previous action – how an
  agency closure appears (USAID -\> State).

- `dsr_recipient_change`:

  Recipient UEI differs from the award's previous action.

## Helper columns

`sched_end` (the end date in force before this action), `end_shift_days`
(this action's end date minus that), and `ceiling_change` (the numeric
ceiling delta, `NA` for assistance).

## Examples

``` r
tx <- us_normalize_transactions(us_sample_extract()$transactions)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
f <- us_disruption_flags(tx)
f[, lapply(.SD, sum), .SDcols = patterns("^dsr_")]
#>    dsr_term_code dsr_term_text dsr_rescinded dsr_closeout dsr_early_deob
#>            <int>         <int>         <int>        <int>          <int>
#> 1:             1             0             0            1              3
#>    dsr_end_cut dsr_ceiling_cut dsr_extension dsr_stop_work dsr_admin
#>          <int>           <int>         <int>         <int>     <int>
#> 1:           2               5            28             0        27
#>    dsr_novation dsr_transfer dsr_agency_change dsr_recipient_change
#>           <int>        <int>             <int>                <int>
#> 1:            0            0                 0                    0
```
