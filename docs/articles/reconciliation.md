# Reconciliation: accounting identities

``` r
library(usaspend)
p <- us_panel(us_sample_extract())
```

The goal of this package is to start from a **complex transaction
ledger** — tens of thousands of modification rows carrying corrections,
restated duplicates, zero-dollar administrative actions, claw-backs, and
ceilings that are not money — and convert it into an **accounting
ledger**: one row per organization × award × year whose dollars add up
under stated rules. “Under stated rules” is the whole game. Every rule
is a choice, and a choice that cannot be checked against an independent
figure is an assumption. This vignette lays out the identities the
package imposes, then shows how they are tested.

## The identities

### What adds, what subtracts, what has no effect

The money column is `federal_action_obligation`, and **the sign is the
truth** — the action-type code describes intent, never direction (a
CONTINUATION can carry negative dollars; 6,344 did in the pilot).

- **Adds to net**: any positive obligation — originations (assistance
  `A`, contract base awards), funded continuations (assistance `B`,
  contract option exercises `G`), positive revisions and funding-only
  actions (contract `C`). A *program expansion* looks like this: new
  positive obligations, usually alongside a period extension.
- **Subtracts from net**: any negative obligation — de-obligations and
  claw-backs, arriving under every action class (terminations, negative
  continuations, negative revisions, closeout adjustments). The
  `deobligation_policy` argument of
  [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
  chooses *when* they subtract: the year posted (`as_posted`), restated
  LIFO against the award’s earlier positive years (`restate`), or
  measured-and-discarded (`drop`).
- **No effect on net**: zero-dollar actions — 20–30% of all rows. These
  carry the administrative record: period-of-performance changes,
  closeouts, vendor and transfer updates. A *timeline-only extension* is
  the canonical case: the end date moves, the money does not, net is
  untouched. (A non-zero amount on an administrative action is flagged
  `money_on_admin_action` rather than silently trusted.)
- **Never in net at all**: loan face value (the borrower’s liability),
  loan subsidy cost, non-federal cost share, and every ceiling —
  `potential_value`, IDV vehicle totals. The pilot holds \$115bn of IDV
  ceiling against \$0.75bn actually obligated on those vehicles.

### The award window, and whether it binds

The **period of performance** (`pop_start_date` → `pop_end_date`) is the
award’s declared window. It is *descriptive, not binding*: transactions
legitimately post after the end date (corrections, closeout
adjustments), and the normalizer only flags actions landing more than a
year past it (`action_after_pop`) rather than rejecting them.

The window also **moves**. The data signature of a period change is a
`pop_end_date` that differs across an award’s transaction sequence — the
first reported value is the original plan, the last is the final window,
and
[`us_outlay_features()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_outlay_features.md)
classifies the difference: an extension past 90 days with material new
money is `extension_funded` (an expansion), without new money
`extension_timeline` (a no-cost extension), and a shortened window
usually rides along with a `reduced` award’s de-obligations.

**Closeout is a third clock.** The closeout action (contract code `K`,
assistance `D` “Adjustment to Completed Award”) follows neither the
performance end nor the last payment: measured on File C ground truth,
cash is still arriving a year after the performance end
(outlay/obligation ratio 0.90 at one year, 1.00 only at three), and
de-obligations of genuine underspend post later still. Performance end →
final drawdowns → audit and closeout is a sequence spanning years, and
each stage leaves rows.

### Two year definitions

Every transaction carries both `action_year` (calendar) and
`action_fiscal_year` (federal fiscal: October–September), and
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
builds on either (`period =`). The choice is an accounting decision:
October–December actions belong to different years under the two
definitions, so panels built on different bases do not reconcile
year-by-year, only in lifetime totals. Match the basis to the linked
data — calendar for IRS Form 990 and most organizational outcomes,
fiscal for anything meeting the federal ledgers (File C outlays exist
*only* in fiscal periods, which is why
[`us_add_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_outlays.md)
and
[`us_add_imputed_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_imputed_outlays.md)
require a fiscal panel).

### Pass-through: the prime’s ledger and the sub’s

A prime award’s obligations are the organization’s **gross** federal
revenue. What it is obliged to pay onward to subrecipients is measured
separately (`subaward_out_amount`), and the identity

> `net_revenue = obligation_net − subaward_out_amount`

defines the **retained** column: what the prime keeps after
pass-through. The same dollar deliberately appears twice in the system —
once in the prime’s gross, once as the subrecipient’s inbound revenue
(`subaward_in_amount`, kept in the separate org-year `subawards_in`
table) — because both ledgers are true at their own level. What the
package never does is add them in one total.

### Why a subaward row will not reconcile

Subaward data is **not a transaction ledger**. FSRS rows are *report
lines*: one line per subaward as last restated, no modification history,
no de-obligations, reported only above the \$30k threshold, and lagging
the obligations they draw on (13% of pilot pass-through dollars posted
in years with no prime activity). There is no lifetime total to test a
subaward sum against, so subaward figures are treated as **floors**
carried alongside the reconciled prime ledger — never as a ledger that
must balance.

## Testing the identities

The tests check two distinct assumptions:

1.  **The database and the retrieval are consistent** — the extract
    holds what USAspending holds, without duplication or loss along the
    download path.
2.  **The transaction-to-accounting transformation gets the math right**
    — de-duplication, delete handling, sign netting, and year assignment
    reproduce the totals they should.

A single external figure tests both at once: USAspending publishes each
award’s **lifetime obligation total, computed by a different system than
the transactions**. If the extract is complete and the netting is
correct, summed transactions return to that total.
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
runs the identity per award and labels every exception:

``` r
r <- us_reconcile(p)
#> Reconciled 18 awards: 15 exact (83%).
#> • ok=15 no_reported_total=2 break=1
r[, .(award_key = substr(award_key, 1, 34), total_obligated, tx_sum, gap, status)]
#>                              award_key total_obligated    tx_sum     gap
#>                                 <char>           <num>     <num>   <num>
#>  1: CONT_AWD_HHSD2002006M15742P_7523_-              NA       0.0      NA
#>  2: CONT_AWD_HHSD2002006M18386P_7523_-              NA       0.0      NA
#>  3:              ASST_NON_D8732143_075       1388205.4 -310999.0 1699204
#>  4:         ASST_NON_HDTRA12310001_097       1300000.0 1300000.0       0
#>  5: CONT_AWD_73351023P0025_7300_-NONE-         62100.0   62100.0       0
#>  6: CONT_AWD_FA875018C0013_9700_-NONE-       7598606.0 7598606.0       0
#>  7: CONT_AWD_FA875019C0203_9700_-NONE-       5098414.0 5098414.0       0
#>  8: CONT_AWD_HHSD2002007200320001_7523        281586.3  281586.3       0
#>  9: CONT_AWD_HHSD2002007200320002_7523        390297.9  390297.9       0
#> 10: CONT_AWD_HHSD2002007200320003_7523       1818651.0 1818651.0       0
#> 11: CONT_AWD_HHSD2002007200320004_7523        458210.1  458210.1       0
#> 12: CONT_AWD_HR001122C0033_9700_-NONE-       8464104.0 8464104.0       0
#> 13: CONT_AWD_HT009023FG0570037_9700_W8         14206.0   14206.0       0
#> 14: CONT_AWD_W81K0209P0001_9700_-NONE-        101196.0  101196.0       0
#> 15: CONT_AWD_W81K0214P0076_9700_-NONE-        107019.0  107019.0       0
#> 16:    CONT_IDV_HHSD200200720032I_7523             0.0       0.0       0
#> 17:        CONT_IDV_W81K0219A0012_9700             0.0       0.0       0
#> 18:        CONT_IDV_W81K0225AA002_9700             0.0       0.0       0
#>                status
#>                <char>
#>  1: no_reported_total
#>  2: no_reported_total
#>  3:             break
#>  4:                ok
#>  5:                ok
#>  6:                ok
#>  7:                ok
#>  8:                ok
#>  9:                ok
#> 10:                ok
#> 11:                ok
#> 12:                ok
#> 13:                ok
#> 14:                ok
#> 15:                ok
#> 16:                ok
#> 17:                ok
#> 18:                ok
```

### Reading the labels

The sample reconciles 15 of 18 exactly, and the exceptions carry the two
lessons:

- **`no_reported_total`** — nothing to check against; a coverage fact,
  not a failure.
- **[`break`](https://rdrr.io/r/base/Control.html)** — the claw-back
  award shows `tx_sum = −$310,999` against a \$1.39M lifetime total
  because the extract’s window holds only the reversal. The identity
  *should* fail here: **a UEI-filtered extract is an organization-eye
  view, not an award-eye view**, and the panel measures what this
  organization was obligated in these years — which legitimately differs
  from whole-life totals whenever the award’s history extends beyond the
  window (`window_edge`, `recent_open`) or the award moved between
  institutions (`multi_recipient`).

### The same test at scale

On the full 50-org pilot (61,738 awards), after normalization:

| status | awards | explanation |
|----|----|----|
| **ok — exact to the dollar** | 44,680 (72%) | both assumptions hold |
| no reported total | 4,955 | nothing to check against |
| recent/open award | 4,133 | corrections keep arriving after the pull (API-audited) |
| window edge | 1,564 | pre-2008 history sits below the search floor |
| multi-recipient | 129 | the award’s other slice belongs to another organization |
| unexplained | ~10% | API audit: mostly the same mechanisms mid-window, dominated by NIH awards following a PI between institutions |

72% exact — with every exception *labeled* — is a strong result for a
UEI-filtered extract, and the labeling is the point: a falling “ok”
share on a rebuild is the earliest sign of a broken rule, and an
unlabeled break is a real question, not noise. De-duplication is what
makes the number possible: before the duplicate rule
([`vignette("accounting")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/accounting.md)),
5,754 additional pilot awards failed the identity.

### Structural invariants — `us_audit()`

Checks needing no external reference:

``` r
us_audit(p)
#>                                                     check     value status
#>                                                    <char>    <char> <char>
#>  1:                      rows at org x award x year grain        67   info
#>  2:                                  duplicate grain rows         0     ok
#>  3:                  awards attributed to >1 organization         0     ok
#>  4:        duplicate transaction keys after normalization         0     ok
#>  5:          org-award-years with negative net obligation         6   info
#>  6: rows where pass-through pushes net_revenue below zero         0   info
#>  7:                 share of zero-dollar transactions (%)      49.2   info
#>  8:                   transactions carrying anomaly flags         8   info
#>  9:                                         years covered 2008-2025   info
#> 10:                            outbound subawards fetched     FALSE   warn
```

No transaction key twice, no award attributed to two organizations, one
row per org-award-year — plus the counters worth watching over time
(negative years, zero-dollar share, anomaly flags) and a warning
whenever outbound subawards were never fetched, so
`net_revenue = obligation_net` cannot pass silently as a netted figure.

## Obligations versus outlays

Everything above concerns the **budget ledger** — obligations, the
promises. The **payment ledger** — outlays, the cash — is a separate
system with its own identity: money obligated is eventually either paid
out or de-obligated, so lifetime outlays converge to lifetime net
obligations at closeout. The data confirms the identity where
measurement allows: awards with full reporting coverage and two-plus
years to liquidate reach a median outlay/obligation ratio of exactly
1.00.

But the payment ledger as *published* cannot be trusted the way the
budget ledger can
([`vignette("obligations-outlays")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/obligations-outlays.md)
has the full story): account-level outlay reporting was optional before
the FY2022 monthly mandate, whole agencies still report obligations
without outlays (DoD median ratio 0.00, Commerce 0.24, against
NSF/USDA/NASA at 1.00), and a fifth of fetched awards have File C
records that cannot be linked back to their own transaction ledger.
[`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md)
/[`us_add_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_outlays.md)
retrieve what exists and grade each award’s coverage rather than letting
gaps read as zeros.

Where real outlays don’t reach,
[`us_impute_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_impute_outlays.md)
fills in — and it is important to be precise about what it returns. The
model is fitted on awards whose payment ledgers are essentially complete
(screened by completeness and shape), and it predicts the **typical
payment schedule conditional on the obligations**: the shape of the cash
calendar, at the level completed awards actually deliver (~0.94 per
obligated dollar), not the accounting identity. Passing
`reconcile = TRUE` re-imposes the identity — each award’s imputed series
is rescaled to sum exactly to its net obligations (for an in-progress
award, over its full projected life rather than the years observed so
far). That is the configuration most users modeling government spending
or organizational revenue want: the dollars tie out to the reconciled
obligations ledger, and the model contributes what it genuinely knows,
the timing.

## Practice

Run
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
and
[`us_audit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_audit.md)
on every rebuild and diff against the previous run, so a change in the
data or in a rule shows up as a change in the audit rather than as a
quietly different number.
