# usaspend — accounting rules

How raw USAspending transactions become `ORG × AWARD × YEAR` net revenue.

Every rule below is numbered by the section the corresponding placeholder
function points at. Rules marked **[measured]** are grounded in the bundled
sample extract (`us_sample_extract()`, a real three-UEI pull from 2026-08-27);
rules marked **[open]** are decisions the pilot has to settle.

---

## 1. The problem

A federal award is not a payment. It is a running ledger of promises, and the
ledger is written in modifications:

```
ASST_NON_HDTRA12310001_097                                    [measured]

  mod       date         action                       amount
  0         2022-12-16   A  NEW                     +309,655
  P00001    2022-12-16   B  CONTINUATION                   0
  P00002    2024-02-29   B  CONTINUATION            +385,990
  P00003    2024-06-04   B  CONTINUATION            +304,355
  P00004    2024-08-26   C  REVISION                       0
  P00005    2025-05-06   C  REVISION                       0
  P00006    2025-08-28   C  REVISION                       0
  P00007    2025-09-02   C  REVISION                +300,000
                                                  ──────────
                                                   1,300,000
                              total_obligated_amount 1,300,000  ✓
```

Eight actions, one award, four calendar years, three of them zero-dollar. The
panel wants one row per year with the money that landed in that year — and the
sum across years must come back to the award's reported lifetime total. That
identity holding exactly is the check that the whole pipeline is right.

Now the harder shape, from the same extract:

```
ASST_NON_D8732143_075                                         [measured]
  03        2024-05-13   C  REVISION                -310,999
```

A claw-back of $310,999 recorded in 2024 against an award whose lifetime total is
$1,388,205. Which year loses the money? §5.4.

---

## 2. What counts as money

USAspending carries a dozen dollar columns. Three groups, and only one of them
is revenue.

### 2.1 Revenue — sum these

| column | note |
|---|---|
| `federal_action_obligation` | the signed amount committed by this action. **The default measure.** |
| `pragmatic_obligation` | USAspending's derived column (`generated_pragmatic_obligations`); equals the obligation except for loans, where it is the subsidy cost. Assistance only — contracts have no such column and the package fills it from the obligation. **[measured]** |

### 2.2 Ceilings — never sum these

`potential_total_value_of_award`, `base_and_all_options_value`,
`base_and_exercised_options_value`, `current_total_value_of_award`,
`total_funding_amount` (which includes the non-federal share).

These describe capacity, not money. **[measured]** The sample contains
`CONT_IDV_HHSD200200720032I_7523`: a $40,000,000 potential value against $0
obligated across seven modifications. A ceiling-based panel would credit that
organization with $40M it never received.

### 2.3 Not revenue at all — separate columns

| column | why |
|---|---|
| `face_value_of_loan` | a liability, not income |
| `original_loan_subsidy_cost` | the government's expected loss, not a payment to the recipient |
| `non_federal_funding_amount` | cost share from someone else |
| `total_outlayed_amount_for_overall_award` | award-lifetime, not annual — see below |

### 2.4 Outlays are not available annually (in award data)

The award data has no annual disbursement figure. `total_outlayed_amount_for_overall_award`
is lifetime-to-date and blank on most rows **[measured]** — in the sample it is
populated on one award of eighteen. Annual outlays exist only in the
account-level File C data, reachable per award via `POST /awards/funding/` but
absent from every transaction download this package builds on.

Coverage follows the reporting mandates, and it is not just an era problem
**[measured on VUMC, 2026-08-28, `data-raw/outlay-timing-analysis.R`]**:

* File C outlay reporting was quarterly and optional from FY2017, required for
  COVID-supplemental awards from April 2020, and monthly and mandatory for all
  agencies only from FY2022. Lifetime outlay totals **undercount** any award
  straddling those dates — the pre-mandate outlays were never reported, not
  merely not yet paid.
* Coverage varies by agency and family as much as by era. Share of VUMC awards
  with a nonzero lifetime outlay, by first action: assistance 33% / 78% / 91%
  across pre-FY2017 / FY2017–21 / FY2022+, contracts 0% / 15% / 14%. The
  contract gap is an agency gap: post-FY2022, HHS 98% versus VA contracts 0%
  and DoD 2%.
* Where both series exist (FY2022+ VUMC awards whose File C obligations
  reconcile with their award transactions), within-year obligations and
  within-year outlays diverge widely: obligations put a median 90% of an
  award's dollars in its first fiscal year, outlays 2%; cash lags commitment
  by roughly one year; about two-thirds of dollars land in a different year
  under the two measures. Same-year portfolio correlation was 0.37 against
  0.74 for outlays-on-prior-year-obligations.

`us_money_column("outlay")` therefore **errors** rather than returning a
plausible substitute. The panel measures obligations, says so, and reports the
obligation-to-outlay gap per award in `us_reconcile()` so the reader can see how
far that is from cash.

Annual outlays are available as an **optional, explicitly scoped layer**:
`us_fetch_outlays()` walks the per-award File C endpoint,
`us_outlays_by_year()` applies the cumulative-within-fiscal-year rule
(`gross_outlay_amount` is reported as of period end and resets at the FY
boundary — the annual figure is the last value per account cell, never the
period sum), and `us_add_outlays()` joins the result onto a fiscal panel as
`outlay_amount` plus a per-award `outlay_coverage` grade (`complete` /
`truncated_pre_FY2022` / `unlinked` / `no_outlay_rows` / `no_file_c` /
`fetch_failed`). A missing measurement is `NA`, never a fake zero;
`obligation_net` and `net_revenue` are never touched.

### 2.5 What the ledger actually contains — **[measured]**

The pilot's 302,025 prime transactions, by award type. The right-hand column is
the rule; the dollar column is why the rule matters.

| type | rows | dollars | what it is | treatment |
|---|---|---|---|---|
| Project grants (04) + coop agreements (05) | 212k | $62.8bn | the core | revenue |
| Contracts (A–D) | 56.6k | $76.4bn | DO / definitive / PO / BPA call | revenue |
| Direct payments (06, 10) | 19.3k | $3.0bn | almost entirely Pell, work-study, SEOG — student aid moving *through* the institution | separable by family; usually excluded — §5.6 |
| Direct loans (07) | 6.5k | $0 obligated, **$626bn face value** | 100% Federal Direct Student Loans; the institution is a conduit | face value never reaches revenue — §2.3, §5.6 |
| Formula/block grants (03, 02) | 2.1k | $1.6bn | mostly the government-affiliated orgs | revenue |
| Other/reimbursable (11) | 1.2k | $0.3bn | DOE/DOD/USDA cooperative R&D | revenue-like |
| IDVs | 4.3k | ~$0.8bn obligated vs **$115bn ceiling** | contract vehicles | obligations only — §2.2 |
| Loan guarantees (08), insurance (09) | 0 | — | absent from this sample | — |

Two numbers in that table carry §2.2 and §2.3 on their own: $626bn of loan face
value and $115bn of IDV ceiling, against $118.5bn of actual net obligation. A
sum over the wrong dollar column overstates the pilot roughly sixfold.

Two shape facts follow from the same census. **23% of all transactions are $0**
(§3.4) and **8.6% are negative** (§5.1) — de-obligations arriving under every
action-type label, `CONTINUATION` included. About a third of the ledger carries
no new positive money, which is why row counts and dollar counts tell different
stories and why the panel never carries the net alone (§5.3).

---

## 3. Cleaning the transaction ledger — `us_normalize_transactions()`

1. **De-duplicate on `transaction_key`.** `assistance_transaction_unique_key` /
   `contract_transaction_unique_key` is genuinely unique per action. Duplicates
   arrive because download batches overlap and because an organization's several
   UEIs can appear in more than one job. Keep the row with the latest
   `last_modified_date`. **[measured]** In the pilot, 19,445 of 241,118
   assistance rows (8.1%) and 1,383 of 60,907 contract rows (2.3%) were
   duplicates — every one of them an exact copy (same amount, same
   `last_modified_date`), all doubletons. De-duplicating recovered 5,754 awards
   that had previously failed the lifetime reconciliation identity.

2. **Apply corrections and deletes.** Assistance rows carry
   `correction_delete_indicator_code`: `D` withdraws the record — drop it. `C`
   marks the row as *being* a correction: it is the current version and is
   **kept**. **[measured]** 37.6% of pilot assistance rows carry `C`; a pipeline
   that read `C` as "superseded" and dropped it would discard a third of the
   ledger. The pilot also surfaced two undocumented values: `L` (1,719 rows, all
   Department of Energy, 2008–2017) and `_` (4 rows, NRC, 2008). Both are kept
   and flagged `is_legacy_cdi`. Contracts have no such column; FPDS corrections
   arrive as new modifications instead, so contract rows are never deleted here.

3. **Drop aggregate records.** Assistance `record_type_code` 1 is a county-level
   aggregate with no identified recipient. Only 2 and 3 name an entity. Keeping
   type 1 double-counts money already present at entity level.

4. **Keep zero-dollar actions, flagged.** They are the majority of
   modifications — **[measured]** 30 of 111 contract actions in the sample are
   `OTHER ADMINISTRATIVE ACTION` at $0, and three of the eight actions on the
   worked example above. They carry period-of-performance changes and they are
   how activity is counted. Flag as `is_zero_dollar`; never drop.

5. **Flag anomalies, do not silently repair them.** A non-zero amount on an
   `administrative` action; an `action_date` outside the award's period of
   performance; an `action_date` before 2007-10-01 (impossible, given the search
   floor); a `recipient_uei` that was never requested (the API matches on text,
   so strays are possible).

6. **Never group on description strings.** **[measured]** The sample carries
   `"DELIVERY ORDER"` and `"DO"` for award type code C, and `"PURCHASE ORDER"`
   and `"PO"` for code B, *in the same file*. Labels come from
   `us_classify_award_type()` and `us_classify_action()`, which key on codes.

7. **Interpret action codes per family.** The codes collide: `B` is
   CONTINUATION for assistance and SUPPLEMENTAL AGREEMENT for contracts; `C` is
   REVISION versus FUNDING ONLY ACTION; `D` is ADJUSTMENT TO COMPLETED AWARD
   versus CHANGE ORDER. Any classifier that ignores `award_group` is wrong.

---

## 4. The award spine — `us_normalize_awards()`

1. **Award-level fields are sparse across transactions.** **[measured]**
   `total_dollars_obligated` and `current_total_value_of_award` are blank on most
   contract modification rows and populated on others. Take the value from the
   latest `action_date` that has one — never from an arbitrary row.

2. **Award attributes change over a life — including the recipient.**
   Sub-agency, recipient name, even the PIID can be modified. Record the value
   as of the latest action. **[measured]** This is not an edge case: NIH awards
   follow the principal investigator between institutions, so one `award_key`
   can carry transactions for several recipients over its life. In a pilot
   audit of 28 breaking awards, 11 turned out to have a *current* recipient
   that was never in the pilot at all (Minnesota, Duke, Northwestern, UC
   campuses...) — the pilot org held only an early slice of the award's
   history. This is why the panel grain is org × award × year rather than
   award × year, why `n_recipients` is carried on the spine, and why a
   UEI-filtered extract legitimately fails the lifetime identity on such
   awards.

3. **Blank award type on IDV rows.** **[measured]** Contract IDVs carry an empty
   `award_type_code`; the type is in `idv_type_code`, written as a bare letter
   (`"B"`, `"E"`). Bare `"B"` collides with Purchase Order, so it must be
   prefixed `IDV_` before lookup. This bug was live in the first draft and the
   fixture caught it.

4. **IDV rollup is a modelling choice.** **[open]** Delivery orders under an
   indefinite-delivery vehicle are separate awards with their own keys and their
   own obligations. Rolling them into the parent changes the award count and the
   agency attribution but not the dollar total. The argument exists and defaults
   to off; the pilot should report what it changes.

---

## 5. Netting — `us_ledger()` and `us_net_by_year()`

### 5.1 The sign is the truth

A negative `federal_action_obligation` is a de-obligation regardless of what the
action type says. **[measured]** In the sample a `REVISION` carries −$310,999 and
a `CONTINUATION` carries $0. Classify on the amount; use `action_class` as
context only.

### 5.2 Keep negatives

Dropping de-obligations inflates every affected year. They are ordinary federal
award activity. `deobligation_policy = "drop"` exists only so the size of that
overstatement can be measured, and warns when used.

### 5.3 Split gross from net

Every award-year carries `obligation_positive`, `obligation_negative` and
`obligation_net`. A cell netting to $1M from +$5M and −$4M is a different fact
from one netting to $1M from a single clean award. The panel must be able to
tell them apart, so it never carries the net alone.

### 5.4 The de-obligation policy — **[measured]**

A claw-back recorded in 2024 against money obligated in 2021 can be booked two
ways. Neither is wrong. The package implements both and refuses to choose
silently.

| policy | books the reversal in | character | cost |
|---|---|---|---|
| **`as_posted`** (default) | the year it happened | cash-basis-like; matches USAspending's own presentation; each year reproducible from that year's transactions | a large reversal can drive a year negative |
| `restate` | the year(s) that carried the obligation being reversed, latest-first (LIFO within the award) | accrual-like; cleaner picture of what a year's awards were ultimately worth | rewrites history — last year's published figure changes when this year's data arrives; transactions do not say what they reverse, so LIFO is the uniform matching rule |
| `drop` | nowhere | — | overstates. Diagnostic only. |

**Pilot result:** on $118.5bn of net obligations across 2007–2025, `restate`
moves most years by less than ±$50m (under 1%). The exceptions are exactly
where the policy is supposed to matter: 2024 loses $460m and 2025 gains $646m,
because recent claw-backs posted in those years get pushed back onto the years
that carried the money. The total is conserved to rounding. Conclusion:
**`as_posted` is a safe default for historical years; the policies genuinely
diverge only near the data's leading edge**, which is also where the numbers
are still moving anyway. 10% of pilot org-award-years net negative under
`as_posted` — real, and kept.

### 5.5 Year basis

`period = "calendar"` (the default for this project) books on the calendar year
of `action_date`; `"fiscal"` uses the federal fiscal year, which starts 1 October.
Both are **recomputed from `action_date`** rather than read from
`action_date_fiscal_year`, so the two bases are guaranteed consistent with each
other and with the dates.

### 5.6 Loans and direct payments stay out of revenue

**[measured]** In the pilot the loan question resolves cleanly: all 6,496
type-07 rows are **Federal Direct Student Loans (CFDA 84.268)** with
`federal_action_obligation = $0` on every row and $626bn in
`face_value_of_loan`. The universities are conduits — the loans are to
students, not to the institution. The obligation column already handles this
correctly by being zero; face value and subsidy cost travel in their own
columns and must never reach a revenue total.

Direct payments (06, 10) in the pilot are almost entirely student aid flowing
*through* the institution: Pell grants ($1.2bn, CFDA 84.063), Federal
Work-Study, SEOG. These are institutional pass-through of a different kind —
booked as obligations to the school but economically belonging to students.
They stay in the ledger with their `award_family = "direct_payment"` so the
panel can include or exclude them explicitly; for a nonprofit-revenue analysis
excluding them is usually right.

Type 11 ("other reimbursable, contingent, intangible or indirect") is small
($277m) and in the pilot is mostly DOE/DOD/USDA cooperative R&D — economically
similar to grants. Keep, separable by family.

---

## 6. Subawards — `us_normalize_subawards()` and `us_subaward_by_year()`

### 6.0 What a subaward row is

An FSRS (FFATA Subaward Reporting System) record: the prime recipient reporting
an organization to which it passed part of a federal award, once that subaward
crosses the **$30,000** threshold. Both parties are named with UEIs on every
row, which is what makes §6.1 recoverable at all.

It is **not** the federal → state → local chain. When CMS pays a state Medicaid
agency and the state pays a hospital, USAspending sees only the federal → state
prime award; the state's onward payment is not an FSRS record, and Medicaid
provider payments never appear at all. The pass-through does surface where the
conduit is itself a federal prime grantee that reports — **[measured]** the
largest primes paying the pilot's 50 orgs are state agencies passing FEMA/ED/CMS
money down (CA Governor's Office of Emergency Services, FL Dept of Education,
MD Health Benefit Exchange). That is a meaningful but **incomplete** slice of
intergovernmental transfer, and no analysis may treat observed subawards as the
population of pass-through.

### 6.1 Direction is not optional

**[measured]** A bulk download filtered on `recipient_search_text` returns
subawards where the queried UEI is the **subawardee**. A three-UEI pull on
2026-08-27 returned 32 subaward rows: 32 inbound, 0 outbound. Confirmed at
scale on the pilot's 39,243 rows: 36,746 inbound, 2,497 internal (both parties
pilot orgs — NYU → NYU School of Medicine and similar), **0 outbound**. The
match is on the subawardee, so this is mechanical, not a property of the sample.

- `direction == "out"` — the organization is the prime. This is pass-through:
  money it is obliged to pay onward, and it must be **subtracted** from revenue.
  Obtainable only by querying per prime award (`us_fetch_subawards_out()`,
  `us_fetch_subawards_batch()`) — a separate API pass, **not yet run for the
  pilot**.
- `direction == "in"` — the organization is the subawardee. This is **additional
  revenue** that appears nowhere in prime data. An organization funded purely as
  a subrecipient looks like a non-recipient. **[measured]** $13.97bn on the
  pilot, against $118.5bn of prime obligations.

The asymmetry is the thing to remember: inbound arrives free with a
recipient-filtered extract, outbound costs a second pass by award, and only
outbound changes net revenue.

Direction cannot be inferred from a subaward row alone; it needs the
organization's UEI set. `us_subaward_by_year()` errors rather than guessing.

### 6.2 De-duplicate restatements

FSRS reports are restated month to month, so the same subaward reappears under
different `report_year` / `report_month`. Keep the latest
`report_last_modified` per `subaward_key`.

### 6.3 Year basis, and the reporting lag

Book on `subaward_action_date` by default — when the money was committed.
**[measured]** Report dates lag, sometimes across a fiscal year: the sample has
an action dated 2024-08-21 first reported in FY2025 month 3. The report date is
available as an alternative basis so the sensitivity can be measured.

### 6.4 Coverage must travel with the number

FSRS reporting is mandatory only above thresholds and is known to be incomplete.
Every subaward figure carries `n_subawards_out` and a coverage flag, so that "no
pass-through" and "not reported" stay distinguishable. A zero that is really a
missing report, silently netted, understates pass-through and overstates net
revenue.

### 6.5 Pass-through can be large

**[measured]** `ASST_NON_4482DRCAP00000001_070` (FEMA California public
assistance): $14.74 bn obligated, 2,330 subawards totalling $9.97 bn — 68 %
passed through. For pass-through entities the prime obligation is close to
meaningless as a revenue measure.

Full pilot outbound fetch (2026-08-27, `us_fetch_subawards_batch()`): 50,218
outbound subawards worth **$12.6bn against $118.5bn of net obligations** —
10.7% of the pilot's federal money is committed onward. Concentration is
extreme: 25 of 45 organizations report any outbound at all, and the top four
carry over half the dollars. One research institute passes through **45% of
everything it receives**; org-years exist where pass-through *exceeds* the
year's new obligations (a $540m outbound year against $326m of new money),
which is why `net_revenue` legitimately goes negative on 7,409 pilot
org-award-years and why the panel always carries the components, never the net
alone.

**Attachment requires `fill_gaps = TRUE`.** FSRS subawards trail the
obligations they draw on, so 13% of outbound dollars in the pilot were dated in
org-award-years with no prime activity at all. `us_panel(fill_gaps = TRUE)`
gives them zero-obligation rows (4,380 in the pilot) so that
`sum(subaward_out_amount)` equals the dollars fetched exactly; without it the
panel's pass-through is a floor, not a total. Conservation is exact because a
multi-recipient award-year attaches its pass-through once — to the org-row with
the dominant activity — never to both.

### 6.6 The endpoint that serves the outbound fetch — **[measured]**

`POST /api/v2/search/spending_by_award/` with `subawards = true` and batched
`award_ids`. Traps, all live in the pilot run:
\
- **Mixed award-type families 422.** The *result* endpoint rejects an
  `award_type_codes` list spanning assistance and contracts — while the *count*
  endpoint accepts it, so an unhandled mix fails silently as "no subawards".
  One pass per family.
- **`award_ids` matches bare FAINs/PIIDs, which agencies reuse.** The pilot
  fetch returned 267,351 rows of which only 55,631 belonged to our awards once
  filtered on `prime_award_generated_internal_id`. Four out of five raw rows
  were strays. Filter on the generated key, always.
- **Batch caps:** 500 ids per request works, 1,000 returns 503. The 10k result
  cap is guarded by counting first and splitting recursively.
- Rows on multi-recipient awards whose *current* holder is outside the org set
  classify as `unrelated` ($127m in the pilot) — conservatively excluded from
  pass-through, since the subaward cannot be dated to our tenure of the award.

---

## 7. Assembly — `us_panel()`

```
net_revenue = obligation_net − subaward_out_amount
```

`net_revenue` can go negative for legitimate reasons: subawards are booked on
their own action dates, and a large pass-through can land in a year with little
new prime money. The panel therefore always carries both components and never
the net alone.

Organizations, not UEIs, are the unit. Large nonprofits hold several SAM
registrations and USAspending splits their awards across them — NYU has three
UEIs holding 2,687 / 4,721 / 9 awards. Supply a crosswalk to `us_org_map()` and
every table is keyed on `org_id`; without one, each UEI is its own organization.

---

## 8. Reconciliation — `us_reconcile()` and `us_audit()`

These matter more than they look. Every rule above is a choice, and a choice
that cannot be checked against an independent figure is an assumption.
USAspending publishes award-lifetime totals computed by a different system from
the transactions, which makes them a genuine external check.

1. **The lifetime identity.** For an award whose actions all fall inside the
   window, summed `federal_action_obligation` must equal
   `total_obligated_amount`. **[measured]** On the full pilot after
   normalization: **44,680 of 61,738 awards (72%) reconcile to the dollar.**
   The classified remainder: 4,955 report no lifetime total to check against;
   4,133 are recent/open awards (corrections keep arriving after the pull —
   an API audit of sampled breaks confirmed post-window transactions on the
   full award record); 1,564 start at the window edge (pre-2008 history is
   below the search floor); 129 are multi-recipient awards whose other slice
   belongs to another organization. That leaves ~10% genuinely unexplained,
   which the API audit suggests is mostly the same two mechanisms operating
   mid-window (PI transfers between institutions dominate). Every extract
   should publish this table; a falling "ok" share is the earliest sign of a
   broken rule.

   The deeper lesson from the audit: **a UEI-filtered extract is an
   organization-eye view, not an award-eye view.** The award's full history
   includes years at other institutions, and the panel measures what *this
   organization* was obligated — which is exactly the org × award × year
   number, and is *supposed* to differ from the award's lifetime total when
   the award moved.

2. **The outlay gap.** Report `total_outlayed / total_obligated` per award. This
   is the size of the promise-versus-payment gap — the number that tells a
   reader how far an obligations panel is from a cash panel. Expect it missing
   for most pre-FY2017 awards.

3. **Pass-through plausibility.** Flag awards where subawards exceed the prime
   obligation. Some are genuine (restatement across years), some are FSRS
   errors. Both need to be visible.

4. **Subaward coverage rate.** The share of awards above the FSRS threshold
   reporting no subawards at all.

5. **Negative years.** Count and list org-award-years netting below zero, with
   the reversals that caused them.

6. **Duplication and grain.** No `transaction_key` twice; no award attributed to
   two organizations; one row per org-award-year.

Run `us_audit()` on every rebuild and diff it against the previous run, so a
change in the data or in a rule shows up as a change in the audit rather than as
a quietly different number.
