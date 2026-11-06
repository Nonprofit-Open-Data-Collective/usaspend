# Nonprofit award disruption, 2025–26

How many active federal awards to nonprofits were disrupted after
January 20, 2025? Every grant and contract held by a matched nonprofit
that was scheduled to be running on 20 January 2025, followed for days
and compared with the same window starting 20 January 2023.

Data through Draft · preliminary

This article applies the method in
[`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md)
to the whole nonprofit population: every UEI in the npmatch nonprofit
crosswalk (141,420 UEIs), pulled from the USAspending annual award
archives for FY2008–FY2026. That database is not shipped with the
package, so the article draws from pre-computed tables
(`data-raw/report_articles.R` copies them in). Two companion articles go
further: [Disruption on the
ledger](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption-ledger.md)
shows what disruption looked like action by action, and [Obligation
trends,
FY2026](https://nonprofit-open-data-collective.github.io/usaspend/articles/obligation-trends.md)
shows how far new money fell below trend.

## The short answer

## Which signals moved

Each award is read for the signals
[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md)
defines, then placed in one category, in this order: terminated (formal
notice or code), terminated (quiet end-date cut to within 90 days of the
action), reduced (early de-obligation, ceiling cut, or a shortened
schedule), stalled (an annually funded award whose next funding is more
than 120 days overdue, or stop-work language). The 2023 cohort is the
counterfactual: the same rules, the same window length, two years
earlier.

Share of active awards showing each signal

Active awards: (2025) and (2023 baseline). An award can show several
signals; the category rows at top are exclusive.

2023 baseline (from 20 Jan 2023)2025 (from 20 Jan 2025)

## When the terminations came

Awards receiving their first formal termination signal, by month

Formal terminations only (action code E/F/N or termination language, not
rescinded). Recent months are incomplete: contract actions post up to
~90 days late.

## By originating agency

Agency is the awarding agency on the award’s first action, so USAID
awards transferred to State stay with USAID. Terminations are the
cleanest comparison; the full category breakdown follows.

Share of active awards terminated (formal or quiet), by agency

Agencies with at least 600 active awards in 2025, sorted by the 2025
rate.

2023 baseline2025

## How much money

Three measures, because a termination notice usually moves no money.
**Obligated at T0** is the award’s net obligation on 20 January 2025.
**Cash at stake** is what the outlay model expected the award to pay out
in FY2025 and later, given its ledger as it stood on 20 January 2025:
the money that was still to arrive. **De-obligated** and **ceiling cut**
are the formal reductions recorded in the window.

## By organization size

Size is the organization’s IRS revenue (Business Master File), raised to
its largest single year of federal obligations where the BMF figure is
smaller, since federal awards are revenue: small \< \$1M, medium
\$1M–\$10M, large ≥ \$10M.

## Largest disrupted awards by cash at stake

## What this measure misses

- **Freezes with no recorded action.** An award whose payments stop
  without a termination, de-obligation or end-date change is invisible
  to ledger flags. The eight EPA Greenhouse Gas Reduction Fund awards in
  this population (\$20B obligated to Climate United Fund, Coalition for
  Green Capital, Power Forward Communities and others) have no recorded
  action of any kind between 20 January 2025 and , so they are counted
  as not disrupted here. File C shows why: the money was paid out in
  full by December 2024 (see *What was actually paid*).
- **Subawards.** The annual archives carry prime awards only. Nonprofits
  that receive federal money as subrecipients (through states,
  universities, or other nonprofits) are not measured.
- **Reporting lag.** Contract actions post up to ~90 days late and
  assistance up to ~30, so the last months of the window undercount.
- **Re-awards.** Work moved to a new award (same or different
  organization) reads as a termination of the old one; linking them is a
  matching problem not attempted here.
- **Organization matching.** Organizations come from the npmatch
  UEI-to-EIN crosswalk. A few large recipients are matched to a sibling
  EIN (Washington University → its student-media EIN; MITRE → MITRE
  Engenuity); the federal-revenue floor on size corrects their size
  class, not their name.

## What was actually paid

The ledger records decisions; outlays record payments. For every
disrupted award, and for a stratified sample of undisrupted ones, the
account-level outlays agencies report in File C were pulled from
USAspending (`POST /awards/funding/`): The comparison uses only **outlay
reporters**, meaning awards with a positive outlay in some quarter
between October 2022 and December 2024, so an agency that does not
report outlays (DoD, largely) never reads as non-payment. Control-sample
results are weighted to the undisrupted non-DoD awards they represent.

Share of awards receiving no cash in the quarter

Awards scheduled (as of 20 January 2025) to be running for the whole
quarter. File C through .

TerminatedStalledReducedNot disrupted (control, dashed)

### Cash flow on the same awards, before and after

Outlays July 2025 – June 2026 against the same awards’ outlays in
calendar 2024, for reporters scheduled to run through June 2026 and paid
in 2024. The control group gives the normal change. The eight Greenhouse
Gas Reduction Fund awards are left out (below).

### Awards that stopped paying with money still owed

Paid in the year before 20 January 2025, still scheduled to run past
April 2026, at least 10% of obligations unpaid on 20 January 2025, and
no outlay at all from July 2025 through June 2026.

## Next steps

- **Freeze detection across all undisrupted awards.** The control sample
  shows that ledger flags miss most State and USAID stoppages; a full
  File C pull of the 120,618 undisrupted awards not yet sampled (about 2
  days of API time at the observed rate) would count them all.
- **A 2023 payment baseline.** Pulling File C for the 2023 cohort would
  put the no-cash and stopped-paying rates on the same footing as the
  ledger flags.
- **The last failures.** 423 awards still failed after two retries (the
  API rejected about 16% of requests throughout); one more pass should
  recover most.

## Sources

Built with `usaspend` (main @ 22aa2c9: pooled outlay model, dur_bin ×
late_start × short_family;
[`us_disruption_flags()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_disruption_flags.md)).
Pipeline scripts 20–27 build the nonprofit database (tables
`disruption_active_2025`, `disruption_active_2023`,
`filec_award_quarter`, `payment_stopped`). Outlays: File C via
[`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md),
pulled 18–19 September 2026. Universe: grants, cooperative agreements
and contracts; loans, direct payments, insurance and IDV vehicles
excluded, and Defense Logistics Agency supply orders excluded as routine
churn.
