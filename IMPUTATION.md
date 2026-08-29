# Imputing annual outlays from obligations

An experiment: given only what the obligations side of USAspending shows — the
signed transaction ledger, period-of-performance dates, award attributes — how
closely can an award's *annual cash* (File C outlays) be reconstructed? If a
cheap allocation rule gets close, the obligations panel can stand in for cash;
if not, analyses that need cash need the real outlay layer
(`us_add_outlays()`), with its FY2022+ / agency-coverage limits.

Everything here is measured. The scripts are
`data-raw/outlay-imputation-experiment.R` (dataset, methods, scoring) and
`data-raw/outlay-timing-analysis.R` (the earlier coverage/timing probe);
results live in `data-raw/outlay-imputation-results.rds`.

## 1. Ground truth

Candidates: VUMC (bundled) plus the 50-nonprofit pilot extract — awards first
obligated **FY2020+** with **> $50k** net obligations; pilot candidates
further screened to awards whose final period of performance ended by FY2025
(completed awards are the only ones whose cash story can be finished).

Every ground-truth award must be **linked**: its File C lifetime obligations
(`transaction_obligated_amount` summed) within 10% of its own transaction
ledger. An award whose account-level records cannot be reconciled to its
award-level records cannot serve as truth for either.

Two tiers:

* **Tier 1 — `reconciled`.** Lifetime outlays within 10% of lifetime
  obligations and cash no longer flowing. The strict "obligations equal
  outlays" case: both the *level* and the *timing* of cash are trustworthy.
* **Tier 2 — `shape_complete`.** First obligated FY2022+ (inside the monthly
  reporting mandate, so no truncated history), performance ended by FY2025,
  outlay series plateaued (≤ 5% of cash in FY2026, ≤ 20% in FY2025), at least
  25% of obligations observed as cash. Lifetime cash may fall short of
  obligations — underspend, pending de-obligation — but the annual *shape*
  is fully observed, which is all the allocation task needs.

Tier 1 is rarer than theory says it should be, and the gap decomposes
cleanly (measured on the 2,000 linked completed awards in the combined
sample). In principle lifetime outlays converge to lifetime net obligations
at closeout — unspent money is de-obligated until the two meet — and the
data confirms it where nothing interferes: FY2022+ starts with two or more
years to liquidate sit at a median ratio of **1.00**. The observed
shortfalls are, in order of importance:

* **Reporting truncation** — FY2020 starts show a median ratio of 0.40,
  FY2021 starts 0.84, FY2022+ starts 0.92: pre-mandate cash was never
  reported, not never paid.
* **Agency outlay-reporting practice** — agency fixed effects explain 75%
  of log-ratio variance in the clean (FY2022+, ended-by-FY2024) subset:
  DoD reports File C obligations but essentially no outlays (median 0.00),
  Commerce 0.24, while NSF, USDA and NASA sit at 1.00 and HHS at 0.91.
  Most of the residual "level gap" is measurement, not spending behavior.
* **Liquidation in progress** — within the clean era the ratio climbs from
  0.90 one year after the performance end to 1.00 at three years: grantees
  draw down and close out on a lag.
* **Pending de-obligations** — an underspent award's net obligations stay
  overstated until the closeout modification posts, which can take years.

## 2. Methods

| id | name | rule |
|---|---|---|
| M0 | `as_obligated` | cash booked in the year it was obligated — the implicit status quo of using an obligations panel as if it were spending |
| M1 | `even_pop` | net obligations spread evenly over the performance window (first obligation FY through final `pop_end_date` FY) — the user-facing default rule |
| M2 | `profile_duration` | empirical mean share-by-event-year profile, by award duration bin (1–6+ years), learned on training folds only (5-fold CV by award) |
| M3 | `profile_dur_type` | duration × award-type cells (project grant / cooperative agreement / contract / other assistance), falling back to the duration profile when a cell has < 8 training awards |
| M4 | `profile_dur_start` | duration × late-start cells (first obligation in Apr–Sep books most of its first-year cash into the next FY) |
| M5 | `phase_split` | awards with a *funded extension* are split at the extension event; each phase's obligations are spread evenly over that phase's own window |
| M6 | `liquidation_curve` | like M4, but the profile target is the share of **net obligations** (not of the cash total) outlaid per event-year — the curve's sum encodes the outlay/obligation ratio, its shape the lag: level and timing in one object |

The profile methods encode the lag structure the earlier timing probe
measured (cash trails commitment by roughly a year); they are deliberately
transparent — cell means with hierarchical fallback — rather than a fitted
model, because at these sample sizes a model's flexibility would mostly fit
noise.

## 3. The metric, and why not correlation

**Misallocation share** = ½ · Σ_y |imputed_y − actual_y| / total — the
fraction of the award's dollars placed in the wrong fiscal year. 0 is
perfect; 1 is completely wrong. The imputed series is normalized to the
actual cash total first, so the metric isolates *timing*.

Mean absolute error is the right family and correlation is not, for three
reasons:

1. **The task is allocation.** The total is known (it is the obligations);
   the only question is *which year*. An L1 error on the allocation is
   directly interpretable as misplaced dollars. MAE on annual dollars is the
   same idea unnormalized; we report the share form so awards of different
   sizes are comparable, plus a dollar-weighted version so big awards count
   for what they are.
2. **Correlation is scale- and level-invariant.** A profile with the right
   shape but half the amplitude scores r = 1 while badly mispredicting every
   year. A method cannot be rewarded for invariances the problem does not
   have.
3. **Pooled correlations are dominated by between-award variation.** Big
   awards have big years everywhere; pooled r mostly measures "large awards
   are large", not timing skill. Measured directly: the as-obligated method
   posts a *higher* pooled correlation than even-spread while misallocating
   nearly twice as many dollars.

## 4. Results

Ground truth: **1,189 awards** (909 tier-1 reconciled, 280 tier-2
shape-complete) drawn from 2,986 fetched candidates across VUMC and the
50-nonprofit pilot — HHS, USDA, NSF, NASA, Commerce, Interior and others.
Measured 2026-08-29.

| method | mean | median | dollar-weighted |
|---|---|---|---|
| as_obligated (M0) | 0.75 | 0.90 | 0.75 |
| even_pop (M1) | 0.41 | 0.41 | 0.39 |
| profile_duration (M2) | 0.29 | 0.25 | 0.28 |
| profile_dur_type (M3) | 0.29 | 0.25 | 0.27 |
| **profile_dur_start (M4)** | **0.27** | **0.22** | **0.27** |
| phase_split (M5) | 0.40 | 0.41 | 0.39 |
| **liquidation_curve (M6)** | **0.27** | **0.22** | **0.27** |

On the timing metric M6 ties M4 exactly — after normalization they share a
shape. The separation shows on the **unnormalized** metric, where a method
is also charged for missing the cash *level* (half-L1 against the actual
total, no rescaling): M6 scores **0.29 mean / 0.23 median** against 0.30 /
0.24 for M4, 0.43 for even-spread, and 0.85 for as-obligated — and the gap
widens on tier-2 awards (0.34 vs 0.37), exactly where lifetime cash falls
short of obligations. One curve carries both level and timing, which makes
M6 the deployed model.

Reading:

* **Treating obligations as cash misplaces three-quarters of dollars**
  (median 90%). The obligations panel is not a cash proxy at the annual
  grain, full stop.
* **The naive even spread halves the error** (0.41): knowing only the
  performance window is already worth a lot.
* **Learned profiles cut it to roughly a quarter.** The best cheap model
  (duration × late-fiscal-year-start, M4) reaches 0.27 mean / 0.22 median.
  The late-start feature earns its place: an award first obligated in
  Apr–Sep pushes most of its first-year cash into the next FY, and the
  profile learns it. Award *type* adds almost nothing beyond duration
  (M3 ≈ M2) — in a grant-dominated sample, duration and start timing carry
  the signal.
* Rankings are identical within each tier and in dollar-weighted form, and
  the profile advantage is largest exactly where it matters — multi-year
  awards (duration 4: M4 0.25 vs even 0.39 vs as-obligated 0.74).
  Single-year awards are trivially easy for every method (~0.14).

The correlation comparison makes the metric argument concrete: pooled
annual correlation ranks the methods almost *inversely* to allocation
skill — as_obligated posts r = 0.24 while misallocating 0.75 of dollars,
and phase_split posts the highest r (0.39) while misallocating 0.40;
the best allocator (M4) sits at r = 0.17. Correlation rewards being big in
big years, not putting dollars in the right year.

**Residual floor.** Roughly a fifth to a quarter of dollars stay
misallocated under the best method. That is award-idiosyncratic burn-rate
variation that no attribute-based model sees — the practical ceiling for
imputation without award-level cash data.

**Limitation.** Ground truth requires completed cash stories inside the
FY2020+ reporting window, so long awards are scarce (14 of 1,189 run five
years or more). The profiles are well-estimated for 1–4-year awards; the
"$10M over five years" case rides on thin cells, and the FY2022+ mandate
era means the sample skews to recent, shorter, HHS-heavy awards.

## 5. Special cases: how awards change after they begin

The experiment classifies every award's modification history (thresholds
operational, stated in §6.4) and scores each method within class. Three
patterns get special attention:

* **Funded extensions** — period lengthened *and* new money after the
  extension. Hypothesis under test (M5): the extension behaves like a new
  award — phase 2 can be a bigger program (expansion) or a small tail
  (closeout monitoring), and pooling both phases into one even spread
  smears them together. **Verdict: directionally right, practically
  dominated.** On the 46–52 funded-extension awards, phase splitting beats
  the pooled even spread (0.32 vs 0.34) — the hypothesis is correct that an
  expansion carries its own timing — but the duration profile (0.28) and
  the lag-aware profile (0.25) beat both without any modification logic.
  The lag structure the profiles capture matters more than the phase
  structure.
* **Timeline-only extensions** — the end date moves, the money does not.
  These are the *worst* case for as_obligated (0.82: all the money booked
  early, cash stretched late) and a good case for profiles (0.27): a
  no-cost extension is precisely "cash lags plan", which is what the
  profiles encode.
* **Reductions** — material de-obligation, often with a shortened window.
  The hardest class for every method (profiles 0.29–0.32, even 0.45):
  net obligations overstate what was ever going to be spent, and the
  imputation allocates dollars the cash never delivered. Where reductions
  matter, allocating *gross positive* obligations net of the de-obligation
  year's information — or simply flagging `reduced` awards for wider error
  bars — is the honest treatment.

## 6. Vocabulary

The categorical variables used in the experiment and the panel, with their
levels. Codes are the stable identifiers; the label strings in raw files
drift (the pilot carries both "DELIVERY ORDER" and "DO" for the same code) —
**always group on the code, never the label.**

### 6.1 Award group — `award_group`

The top-level split. Determines which action-type code table applies.

* **`assistance`** — money granted: grants, cooperative agreements, direct
  payments, loans, insurance. Reported through FABS.
* **`contract`** — money exchanged for goods/services: contracts and the
  indefinite-delivery vehicles above them. Reported through FPDS.

### 6.2 Award family and type — `award_family`, `award_type_code`

Family is the analytic grouping; type is the raw code.

**Assistance families:**

* **`grant`** — the core of nonprofit federal revenue.
  * `02` Block Grant — formula-allocated to states, broad purpose.
  * `03` Formula Grant — allocated by statutory formula.
  * `04` Project Grant — competitive, specific scope. *The dominant type:
    758 of 942 VUMC experiment candidates.*
  * `05` Cooperative Agreement — like a project grant with substantial
    agency involvement (84 of 942).
* **`direct_payment`** — entity-level payments, often student aid moving
  *through* an institution; separable in analysis.
  * `06` Direct Payment for Specified Use.
  * `10` Direct Payment with Unrestricted Use.
* **`loan`** — never revenue; face value is the borrower's liability.
  * `07` Direct Loan.
  * `08` Guaranteed/Insured Loan.
* **`other`**
  * `09` Insurance.
  * `11` Other Financial Assistance.

**Contract families:**

* **`contract`** — an obligating award.
  * `A` BPA Call — an order against a Blanket Purchase Agreement.
  * `B` Purchase Order — simplified acquisition (19 of 942).
  * `C` Delivery Order — an order against an IDV (78 of 942; the most
    common contract type in this sample).
  * `D` Definitive Contract — a standalone contract (15 of 942).
* **`idv`** — indefinite-delivery *vehicles*: ceilings, not money. Their
  obligations flow through the delivery orders beneath them; treating an
  IDV's potential value as revenue overstates by orders of magnitude.
  * `IDV_A` GWAC, `IDV_B` IDC (+`_A` requirements / `_B` indefinite
    quantity / `_C` definite quantity), `IDV_C` FSS, `IDV_D` BOA,
    `IDV_E` BPA.

### 6.3 Action types — `action_type_code`, `action_class`

What a transaction *is*. **The codes collide across award groups** — `B`
means Continuation for assistance and Supplemental Agreement for contracts —
so classification always requires the group. `action_class` is the
package's economic rollup. Class describes *intent*, never sign: a
continuation can carry negative dollars; infer de-obligation only from the
amount's sign.

**Assistance (FABS ActionType)** — VUMC counts in parentheses:

* `A` **New** → class `origination` (1,558) — first obligation of the award.
* `B` **Continuation** → `continuation` (5,732) — the next budget period of
  a multi-year award; how a 5-year R01 becomes five annual obligations.
* `C` **Revision** → `revision` (3,889) — in-scope change; may add, remove,
  or move no money.
* `D` **Adjustment to Completed Award** → `adjustment` (56) — a correction
  after the award closed.

**Contracts (FPDS "reason for modification")** — the base award row has a
*blank* code (1,558 unclassified rows are mostly these), then:

* `A` Additional Work → `origination` — new work under an existing vehicle.
* `B` Supplemental Agreement Within Scope → `revision` (108).
* `C` Funding Only Action → `funding_only` (139) — money moves, nothing else
  changes; the contract analogue of a continuation.
* `D` Change Order → `revision` (22) — unilateral in-scope change.
* `G` Exercise an Option → `continuation` (108) — the pre-priced next period
  is switched on; the contract analogue of assistance `B`.
* `E` Terminate for Default / `F` for Convenience / `N` Legal Cancellation /
  `X` for Cause → `termination` — typically de-obligating.
* `K` Close Out → `closeout` (32) — administrative end; typically zero-dollar.
* `H` Definitize Letter Contract, `J` Novation, `L` Definitize Change Order,
  `M` Other Administrative (148), `P`/`R` Re-representation, `S` Change
  PIID, `T` Transfer, `V` Vendor DUNS Change, `W` Vendor Address Change →
  `administrative` — should be zero-dollar; a non-zero one is flagged
  (`money_on_admin_action`).

### 6.4 Modification pattern — `mod_class` (defined by this experiment)

One label per award, from its whole transaction history. Operational
thresholds in brackets; priority order as listed (first match wins).

* **`reduced`** — material de-obligation [negative obligations exceed 5% of
  gross positive]. Often accompanies a shortened window. 100 of 942 VUMC
  candidates.
* **`extension_funded`** — the period of performance was extended
  [final `pop_end_date` > first reported `pop_end_date` + 90 days] *and*
  material new money arrived at or after the extension event [> 5% of prior
  positive obligations]. The "phase 2" case: could be program expansion or
  a funded closeout tail. 92 of 942.
* **`extension_timeline`** — extended as above, but without material new
  money: more time for the same dollars (no-cost extension). 126 of 942.
* **`multi_year_incremental`** — obligations in more than one fiscal year,
  no material extension or reduction: the planned annual-continuation
  rhythm. The modal multi-year pattern.
* **`single_year`** — all obligations in one fiscal year, unmodified
  thereafter.

Booleans `extended`, `funded_ext`, `reduced` are also kept, since an award
can qualify for several (the label takes the priority order above).

### 6.5 Outlay coverage — `outlay_coverage` (from `us_add_outlays()`)

Why a given award's cash column can or cannot be trusted:

* **`complete`** — first activity FY2022+, File C linked, outlays reported.
* **`truncated_pre_FY2022`** — linked and reporting, but the award predates
  the monthly mandate: early cash was never reported; lifetime outlays are
  a floor.
* **`unlinked`** — File C obligations disagree with the award's own ledger
  by more than the tolerance; values kept but flagged.
* **`no_outlay_rows`** — File C records exist but carry no outlays.
* **`no_file_c`** — no account-level records at all (VA and DoD portfolios,
  mostly).
* **`fetch_failed`** — the request errored; never read as an empty result.

### 6.6 Money columns (the ones this experiment touches)

* **`federal_action_obligation`** — signed dollars committed by one action.
  The panel measure. Negative = de-obligation.
* **`transaction_obligated_amount`** (File C) — account-level obligations,
  incremental per reporting period. Sums directly.
* **`gross_outlay_amount`** (File C) — account-level cash, **cumulative
  within each fiscal year** per account cell, resetting at the FY boundary.
  Annual outlay = last reported value per cell per FY, summed over cells —
  never the period sum.
* **`total_outlayed_amount_for_overall_award`** — lifetime-to-date snapshot
  stamped on award records; no annual form; undercounts pre-mandate awards.
* **`pop_start_date` / `pop_end_date`** — period of performance. The end
  date *moves*; the first reported value vs the final value is how
  extensions and shortenings are detected.

## 7. In the package

The winning configuration ships as package features:
`us_outlay_features()` (the taxonomy in §6.4 as code),
`us_outlay_training()` (the §1 truth screens), `us_impute_fit()` /
`us_impute_eval()` (M6 fitting and this experiment's two metrics), and
`us_impute_outlays()` / `us_add_imputed_outlays()` (imputation with an
explicit even-spread fallback outside the model's support envelope — never
`NA` dollars). The bundled `outlay_model` is M6 fitted on this ground
truth; `outlay_training` is the ground truth itself. See
`vignette("imputation")` for the approach with worked graphical cases and
`vignette("imputation-fitting")` for refitting on your own portfolio.

## 8. Reproduction

```
data-raw/outlay-imputation-experiment.R   dataset + methods + scoring
data-raw/outlay-timing-analysis.R         coverage and lag probe behind 2.4
data-raw/make-outlay-model.R              fits and bundles outlay_model/_training
data-raw/outlay-imputation-results.rds    scored results (grid, score, slev, gt)
```

Both scripts fetch via `us_fetch_outlays()`; set `FUNDING_RDS` /
`PILOT_FUNDING_RDS` / `PILOT_TX_RDS` to reuse prefetched pulls. Sustained
pulls beyond ~1,000 requests can trigger a temporary host-level block; the
fetch scripts run in resumable slices at 1 request/second.
