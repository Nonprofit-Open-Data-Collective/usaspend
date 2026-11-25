# How USAspending data is structured

``` r
library(usaspend)
ex <- us_sample_extract()
p  <- us_panel(ex)
```

USAspending publishes award data at three grains, and almost every
analytic mistake with this data comes from mixing them up.

| grain | one row is | carries |
|----|----|----|
| **transaction** | one award *action* — a new award, a modification, a correction | a signed dollar amount and a date |
| **award** | one prime award over its whole life | lifetime totals, current attributes, ceilings |
| **subaward** | one FSRS report line | prime → subrecipient flows (see [`vignette("subawards")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/subawards.md)) |

## An award is a ledger, not a payment

The award grain looks like the natural unit, but an award is a
*container*. Its life is written at the transaction grain — and most of
that life is paperwork:

``` r
tx <- p$transactions
tx[award_key == "ASST_NON_HDTRA12310001_097",
   .(modification_number, action_date, action_type_label,
     federal_action_obligation)][order(action_date)]
#>    modification_number action_date action_type_label federal_action_obligation
#>                 <char>      <Date>            <char>                     <num>
#> 1:                   0  2022-12-16               New                    309655
#> 2:              P00001  2022-12-16      Continuation                         0
#> 3:              P00002  2024-02-29      Continuation                    385990
#> 4:              P00003  2024-06-04      Continuation                    304355
#> 5:              P00004  2024-08-26          Revision                         0
#> 6:              P00005  2025-05-06          Revision                         0
#> 7:              P00006  2025-08-28          Revision                         0
#> 8:              P00007  2025-09-02          Revision                    300000
```

Eight actions, four calendar years, three zero-dollar revisions. In the
sample as a whole, 49% of transactions carry \$0 (in the contract-heavy
sample; 23% in the 50-org pilot) — administrative actions and
period-of-performance changes. They are the majority of *modifications*
and they are how activity gets counted, so the package keeps them,
flagged.

**Only the transaction grain supports an annual panel.** The award grain
has one lifetime total and no dates money moved; the transaction grain
has a signed amount and a date on every action. That is the whole reason
the package’s pipeline is built on transactions.

## Where an award sits: three hierarchies, not one

It is tempting to picture a single tree — agency → program → project →
award. USAspending has no such tree. An award hangs from **three
separate hierarchies**, and neither “program” nor “project” is a formal
level in any of them.

**Who manages it — the agency hierarchy.** A department (the *toptier*
agency, e.g. HHS) → a *sub-tier* agency (NIH, CDC) → an office. Every
award records this twice: the **awarding** agency, which signed the
award, and the **funding** agency, whose budget pays for it
(`awarding_agency_name`, `awarding_sub_agency_name`,
`awarding_office_name`; `funding_agency_name`). They usually agree, not
always.

**What it is for — the classification hierarchy.** The nearest thing to
a “program area”, and it differs by family:

- **Assistance** (grants, cooperative agreements, direct payments,
  loans) carries an *Assistance Listing* number (`cfda_number`, formerly
  CFDA), e.g. `93.853`. The prefix belongs to one agency — `93` is HHS,
  `12` DoD, `47` NSF.
- **Contracts** have no program code at all. They are classified by
  *what was bought* — product/service code (`psc_code`) and industry
  (`naics_code`).
- The **budget** side is a third classification: Treasury account →
  program activity → object class. It lives in the account-level File C
  data
  ([`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md)),
  not in the award files, and one award can draw on several accounts.

**The award itself — the award hierarchy.** Contracts nest; assistance
is flat:

    contracts                                  assistance
      vehicle (IDV: IDIQ, BPA, GSA schedule)     award (FAIN)
        └ task / delivery order (PIID)             └ amendments  = transactions
            └ modifications = transactions             └ subawards
                └ subawards

A vehicle is a ceiling, not money; the dollars are obligated on the
orders beneath it, and each order is **its own award** with its own key.
The sample holds one CDC vehicle and four delivery orders placed under
it:

``` r
aw <- p$awards
aw[award_key == "CONT_IDV_HHSD200200720032I_7523" |
     parent_award_id == "HHSD200200720032I",
   .(award_key, award_type_label, parent_award_id, n_transactions, total_obligated)]
#>                                                    award_key award_type_label
#>                                                       <char>           <char>
#> 1: CONT_AWD_HHSD2002007200320001_7523_HHSD200200720032I_7523   Delivery Order
#> 2: CONT_AWD_HHSD2002007200320002_7523_HHSD200200720032I_7523   Delivery Order
#> 3: CONT_AWD_HHSD2002007200320003_7523_HHSD200200720032I_7523   Delivery Order
#> 4: CONT_AWD_HHSD2002007200320004_7523_HHSD200200720032I_7523   Delivery Order
#> 5:                           CONT_IDV_HHSD200200720032I_7523              IDC
#>      parent_award_id n_transactions total_obligated
#>               <char>          <int>           <num>
#> 1: HHSD200200720032I              6        281586.3
#> 2: HHSD200200720032I              7        390297.9
#> 3: HHSD200200720032I              8       1818651.0
#> 4: HHSD200200720032I              5        458210.1
#> 5:              <NA>              7             0.0
```

The generated award key (`award_key`) spells out the nesting and the
agency that created each level:
`CONT_AWD_{order}_{agency}_{vehicle}_{vehicle agency}` for an order,
`CONT_IDV_{vehicle}_{agency}` for a vehicle, `ASST_NON_{FAIN}_{agency}`
for assistance. It is fixed when the award is created and never changes
— even if the award later moves to another agency
([`vignette("disruption")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/disruption.md)).

**“Project” has no identifier.** The closest stand-ins are the award
itself, a vehicle and its family of orders, or — for NIH — the core
project number embedded in the FAIN, which persists across budget years
and follows the investigator between institutions. Most agencies give a
competing renewal a *new* award number, so a multi-year project usually
has to be reconstructed by matching recipient, office, program code, and
description.

### Many awards cross agencies

Measured on a 1,000-nonprofit pull (15,420 awards; see
`disruption_sample`):

- **Shared vehicles.** 391 of 4,207 contract orders (9%) were placed by
  one agency under another agency’s vehicle — mostly GSA schedule
  contracts (agency codes `4730`, `4732`) used by HHS, EPA, USDA, DoD,
  and Commerce. The order’s key records both agencies.
- **Awarding ≠ funding.** 45 awards were signed by one agency for
  another under interagency agreements — Treasury for the Consumer
  Financial Protection Bureau, Interior for DHS, HHS, and DoD, GSA for
  the Postal Service.
- **Several budget accounts** can pay into one award (visible in File
  C).
- **Agency transfers.** When USAID was wound down, its awards kept their
  keys — with USAID’s code — while new actions named the Department of
  State as awarding agency.
- **Programs span agencies even when listings don’t.** An Assistance
  Listing belongs to one agency, but real programs often run as separate
  awards under several (the National Youth Tobacco Survey moved from a
  CDC contract to an FDA one).

So “an agency’s portfolio” has at least four definitions — awarding
agency (who manages the award), funding agency (whose budget pays), the
agency code in the key (where the award originated), and, for orders,
the vehicle’s agency. They can disagree on the same award; say which one
an analysis uses.

## The dozen dollar columns, in three groups

USAspending rows carry many dollar columns. Only one group is money
received.

**Revenue — sum these.** `federal_action_obligation`, the signed amount
committed by each action, is the default measure (with
`pragmatic_obligation` as USAspending’s loan-aware variant).

**Ceilings — never sum these.** `potential_total_value_of_award`,
`base_and_all_options_value`, `current_total_value_of_award`,
`total_funding_amount`. These describe *capacity*. The sample carries
the cautionary example — an indefinite-delivery vehicle with a
\$40,000,000 potential value and **zero dollars obligated** across its
modifications:

``` r
tx[award_key == "CONT_IDV_HHSD200200720032I_7523",
   .(action_date, award_type_label, federal_action_obligation)][order(action_date)][1:4]
#>    action_date award_type_label federal_action_obligation
#>         <Date>           <char>                     <num>
#> 1:  2008-03-11              IDC                         0
#> 2:  2010-11-18              IDC                         0
#> 3:  2011-01-06              IDC                         0
#> 4:  2012-02-24              IDC                         0
sum(tx[award_key == "CONT_IDV_HHSD200200720032I_7523"]$federal_action_obligation)
#> [1] 0
```

A ceiling-based panel would credit this organization with \$40M it never
received. (The money flows through the *delivery orders under* the
vehicle, which are separate awards — see
[`vignette("award-types")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/award-types.md).)

**Not revenue at all — separate columns.** `face_value_of_loan` (a
liability of the borrower), `original_loan_subsidy_cost` (the
government’s expected loss), `non_federal_funding_amount` (someone
else’s cost share).

## Obligations are promises; outlays are cash; only promises are annual

`federal_action_obligation` is a *commitment*. The disbursement — the
outlay — happens later, often across years, and within any given year
the two differ **widely**. Measured on the FY2022+ VUMC awards whose
account-level (File C) records reconcile with their award transactions:
obligations put a median 90% of an award’s dollars in its first fiscal
year while outlays put 2% there; the dollar-weighted center of cash lags
the center of commitment by roughly one year; and about two-thirds of an
award’s dollars land in a *different year* under outlays than under
obligations. An obligations panel and a cash panel are different
objects, and neither approximates the other.

The award data carries **no annual outlay figure at all**:
`total_outlayed_amount_for_overall_award` is lifetime-to-date and blank
on most rows. Annual outlays exist only in the account-level File C data
(exposed per award at `POST /awards/funding/`, absent from every bulk
transaction file), and their coverage follows the reporting mandates:
quarterly and effectively optional from FY2017, required for
COVID-supplemental awards from April 2020, monthly and mandatory for all
agencies only from FY2022. Lifetime outlay totals therefore *undercount*
any award straddling those dates — pre-mandate disbursements were never
reported, not merely not yet paid.

Nor is coverage just an era problem. On the VUMC sample data, the share
of awards carrying a nonzero lifetime outlay:

| first action | assistance | contracts |
|--------------|------------|-----------|
| pre-FY2017   | 33%        | 0%        |
| FY2017–21    | 78%        | 15%       |
| FY2022+      | 91%        | 14%       |

The contract gap is an *agency* gap: post-FY2022, 98% of HHS awards
carry an outlay against 0% of VA contracts and 2% of DoD awards. Whether
outlays exist for a portfolio depends on who funds it.

So an annual panel from this data measures obligations, and honest
analysis says so. The package enforces the honesty:
`us_money_column("outlay")` errors rather than substituting something
close, and
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
reports each award’s obligation-to-outlay ratio so the size of the gap
stays visible. For portfolios where cash genuinely matters,
[`us_add_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_outlays.md)
attaches annual File C outlays to a fiscal panel as a *separate* column
— fetched per award with
[`us_fetch_outlays()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_outlays.md),
graded per award for era, agency, and linkage coverage, and never
substituted into `obligation_net`.

## Award attributes are a moving target

Award-level fields — recipient, agency, even lifetime totals — are
stamped onto every transaction row *as of file generation*, and they
change over an award’s life. Two consequences, both measured:

- **Take attributes from the latest action**, never from an arbitrary
  row —
  [`us_normalize_awards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_awards.md)
  does this. On many rows the award-level fields are simply blank.
- **The recipient itself can change.** NIH awards follow the principal
  investigator between institutions, so one award’s history can span
  organizations. This is why the panel’s grain is *organization* × award
  × year, and why a UEI-filtered extract legitimately fails the lifetime
  identity on such awards
  ([`vignette("reconciliation")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/reconciliation.md)).

## Where to find every field

The reference companion to this vignette is
[`vignette("data-dictionary")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/data-dictionary.md):
entity-relationship diagrams of the source database, the extract, and
the panel; keys and cardinality; the accounting-critical fields of every
table; the award-type, action-class, and direction code tables; and
links to full per-table dictionaries as CSV.

## Transactions come dirty

The raw ledger needs cleaning before it can be netted — duplicates from
overlapping download batches, correction and delete indicator codes,
county-level aggregate records with no identified recipient. The rules,
each grounded in measured pilot data, are the subject of
[`vignette("accounting")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/accounting.md).
