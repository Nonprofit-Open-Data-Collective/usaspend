# usaspend — vignette plan

What the package documentation has to teach, and the measured material to teach
it with. Written 2026-08-27; numbers are from the 50-nonprofit pilot (302,025
prime transactions, 39,243 subaward rows) unless marked otherwise.

This is the content bank behind `vignettes/`: the facts a reader has to be
told, in the order that makes them land, so the arguing is done before the
user-facing text is written. All nine vignettes now exist; §1 tracks status.

Companion documents: `ACCOUNTING.md` (the rules), `PLAN.md` (the pipeline).

---

## 1. The planned set

Status as of 2026-08-28: **all nine vignettes are written** and render
offline from `us_sample_extract()`. `VignetteBuilder: knitr` is in
`DESCRIPTION`; the pkgdown `articles` index groups them ("The data" /
"The pipeline", with `usaspend.Rmd` as the Get-started page). This file
remains the content bank behind them.

| vignette | status | question it answers | depends on |
|---|---|---|---|
| `structure.Rmd` | **written** | package architecture: the layers, the canonical schema boundary, and a mermaid diagram of the function-call workflow | — |
| `acquisition.Rmd` | **written** | API download jobs (cost scales with UEIs) vs annual archives (cost fixed in fiscal years); the measured constraints; `us_extract_plan()` and the ~2,900-UEI crossover; why outbound subawards always cost an extra pass | — |
| `panel.Rmd` | **written** | reading the normalized output: obligations ≠ cash, `net_revenue = obligation_net − subaward_out_amount`, the not-fetched flag, negatives kept, loans/student aid separable, inbound subawards as a separate org-year table; demos of `us_org_year()`, `us_rollup()` (incl. `total_net`), and `us_adjust_inflation()` | — |
| `usaspend.Rmd` (intro) | **written** | UEIs in, panel out — the ten-line path | nothing |
| `data-model.Rmd` | **written** | **How USAspending is structured**: transaction vs award vs subaward, and why the annual panel can only be built from transactions | §2, §3 below |
| `award-types.Rmd` | **written** | What is actually in the data: grants, contracts, IDVs, direct payments, loans — and which of them are revenue | §3 below, `ACCOUNTING.md` §2, §5.6 |
| `subawards.Rmd` | **written** | What "subaward" means here, why direction is the whole problem, and what the data cannot see | §2 below, `ACCOUNTING.md` §6 |
| `accounting.Rmd` | **written** | Modifications, de-obligations, the year a claw-back belongs to | `ACCOUNTING.md` §5 |
| `reconciliation.Rmd` | **written** | Why 72% is a good number, and how to read a break | `ACCOUNTING.md` §8 |

The set is complete. Overlaps are handled by linking: `panel.Rmd` carries
the loan/direct-payment treatment in depth, `acquisition.Rmd` the measured
path comparison, and the others cross-reference rather than repeat.

Teaching order matters more than completeness. A reader who has not yet
internalised "an award is a ledger of modifications, not a payment" will
misread every number in every other vignette, so the intro vignette must carry
the worked eight-modification example from `ACCOUNTING.md` §1 before it shows a
single aggregate.

---

## 2. What "subaward" means here

**The definition to lead with:** a subaward row is an organization receiving
part of an award from the *prime recipient*. These are FSRS (FFATA Subaward
Reporting System) records. The prime awardee reports each first-tier
subrecipient once a subaward crosses the **$30,000** reporting threshold. Both
parties — prime and sub — are named with UEIs on every row, which is what makes
direction recoverable at all.

### 2.1 What it is not

It is **not** the federal → state → local chain. When CMS pays a state Medicaid
agency and the state pays a hospital, USAspending sees only the federal → state
prime award. The state's onward payment is not a subaward record: states are not
required to file FSRS on those flows the same way, and Medicaid provider
payments never appear at all.

This is the single most common misreading of the data and the vignette should
say it in the first paragraph, before the reader builds a mental model that has
to be dismantled later.

### 2.2 The partial exception, which is worth showing

The pass-through *does* surface where the pass-through entity is itself a
federal prime grantee that files FSRS. The pilot's inbound subawards make this
concrete: the largest primes paying the 50 orgs are state agencies passing
federal grant money down —

- California Governor's Office of Emergency Services (FEMA)
- Florida Department of Education (ED)
- Maryland Health Benefit Exchange (CMS)

So the data gives you state-conduit flows when the state is a prime grantee and
reports — a **meaningful but incomplete** slice of intergovernmental transfer.
"Incomplete" is the operative word: any analysis that treats observed subawards
as the population of pass-through is wrong by an unmeasured amount.

### 2.3 Direction, confirmed at scale

Across all 39,243 pilot subaward rows, **every row is inbound or internal**:

| direction | rows (post-dedupe) | meaning |
|---|---|---|
| inbound | 29,319 | a pilot org is the subawardee |
| internal | 2,497 | both parties are pilot orgs (NYU → NYU School of Medicine and similar) |
| outbound | **0** | — |

(7,427 of the 39,243 raw rows were FSRS restatement duplicates.)

The reason is mechanical, not accidental: the UEI-filtered bulk download matches
on the **subawardee**, so a recipient-filtered pull can never return the rows
where your org is the prime. Outbound pass-through — the flow that must be
*subtracted* from revenue — has to be fetched per prime award via
`us_fetch_subawards_out()` / `us_fetch_subawards_batch()`. That pass **has now
run on the pilot** (2026-08-28, see `SUBAWARD-NOTES.md`): $12.6bn outbound,
147 batches × 2 families, ~65 minutes, reconciling to the dollar with
`us_panel(fill_gaps = TRUE)` — net revenue $105.9bn.

Meanwhile the inbound rows are found money: **$14.0bn** of revenue against
$118.5bn of prime obligations — money that appears nowhere in prime award data.
An organization funded purely as a subrecipient looks like a non-recipient.

The vignette should end this section on the asymmetry, because it is the thing
readers will get wrong: *inbound is free with your extract; outbound costs you a
second API pass, and only outbound changes net revenue.*

---

## 3. What is actually in the transaction data

The pilot's 302,025 prime transactions, by award type. This table is the spine
of `award-types.Rmd`.

| type | rows | dollars | what it actually is | revenue treatment |
|---|---|---|---|---|
| Project grants (04) + cooperative agreements (05) | 212k | $62.8bn | the core | revenue |
| Contracts (A–D) | 56.6k | $76.4bn | delivery order / definitive / purchase order / BPA call | revenue |
| Direct payments (06, 10) | 19.3k | $3.0bn | almost entirely Pell, work-study, SEOG — student aid flowing *through* the institution | separable by family; usually **exclude** for org revenue |
| Direct loans (07) | 6.5k | $0 obligated, **$626bn face value** | 100% Federal Direct Student Loans (CFDA 84.268); the university is a conduit, the loans are to students | face value **never** touches revenue — and the data already does this right, obligations are $0 |
| Formula/block grants (03, 02) | 2.1k | $1.6bn | mostly to the few government-affiliated orgs | revenue |
| Other / reimbursable (11) | 1.2k | $0.3bn | DOE/DOD/USDA cooperative R&D agreements | revenue-like |
| IDVs | 4.3k | ~$0.8bn obligated vs **$115bn ceiling** | contract vehicles | obligations only, **never** ceilings |
| Loan guarantees (08), insurance (09) | 0 | — | absent from this sample | — |

Two ratios in that table are the whole argument for the package, and the
vignette should put them side by side: **$626bn of loan face value** and
**$115bn of IDV ceiling**, against **$118.5bn** of actual net obligation. A
naive sum over the wrong dollar column overstates the pilot by a factor of six.

### 3.1 Two shape facts that surprise everyone

- **23% of all transactions are $0.** Administrative actions, period-of-
  performance changes. They are the majority of *modifications* and they are how
  activity gets counted — never drop them.
- **8.6% are negative.** De-obligations arrive under every action-type label,
  including `CONTINUATION`. This is the concrete case for `ACCOUNTING.md` §5.1:
  the sign is the truth, the label is context.

Together these mean roughly a third of the ledger carries no new positive money,
which is why row counts and dollar counts tell different stories and why the
panel carries gross positive, gross negative and net rather than net alone.

---

## 4. API vs archive equivalence — measured 2026-08-27

Material for `acquisition.Rmd` (already written into it) and for anyone
auditing the pipeline. Real FY2015 + FY2024 archives (generated 2026-08-06)
filtered to the 130 pilot UEIs, against the same-window slice of the pilot
API pull (2026-08-27):

| cell | rows api = archive | one-sided keys | obligation diff | fields differing |
|---|---|---|---|---|
| FY2015 assistance | 8,795 = 8,795 | 0 | $0 | `award_id_uri` (22), `award_total_obligated` (17) |
| FY2015 contracts | 2,947 = 2,947 | 0 | $0 | none (after un-swap fix) |
| FY2024 assistance | 17,225 vs 17,224 | 1 | −$4,125.69 | vintage: `award_total_obligated` (430), `award_id_uri` (530), re-corrected rows (6), `recipient_parent_uei` (3) |
| FY2024 contracts | 2,487 = 2,487 | 0 | $0 | `last_modified_date` (30), `award_total_obligated` (4) |

Findings, in teaching order:

1. **Row universes and dollars are identical** — the paths are genuinely
   interchangeable, and archive FY membership is by `action_date` fiscal
   year, the same partition as an API `action_date` filter.
2. **Archive contract files transpose `action_type_code`/`action_type` and
   `idv_type_code`/`idv_type`** — codes and descriptions swap columns.
   Names match, values do not; a name-based schema check cannot see it.
   Before the fix, 78% of archive contract actions misclassified.
   `us_harmonize_transactions()` detects by value shape and un-swaps
   (regression test in `test-schema.R`); `us_archive_verify_schema()` warns.
3. **Award-level derived stamps drift with generation date** —
   `award_total_obligated` (lifetime figure, recomputed per file; diffs
   concentrated in NIH/PI-transfer awards) and `award_id_uri` (generated
   suffix, not stable across systems — never key on it). Transaction facts
   barely drift: three weeks of vintage skew at FY2024 produced exactly one
   one-sided row (a NASA de-obligation modified 15 days after archive
   generation; −\,125.69 of \.9bn, 0.00008%) and re-corrected fields on
   six common rows -- the mechanism the annual `Delta` files exist for.
   Settled years show zero.
4. **`utils::download.file` truncates GB-scale files at R's 60s default
   timeout, and a truncated zip then looks like a cache hit** — fixed in
   `us_archive_download()` (raised timeout, zip validation, partial-file
   cleanup). Found because the first real archive pull failed exactly this
   way.
5. **The archives carry no subawards in either direction and nothing before
   FY2008.** Outbound: append from either path with `subawards = "out"`.
   Inbound: requires the API (bulk-download by-product).

---

## 5. Notes for whoever writes these

- Every number above is reproducible from the pilot extract. When the vignettes
  are written, they should be **computed in the `.Rmd`** from
  `us_sample_extract()` where the fixture supports it, and quoted as measured
  pilot figures where it does not — not hard-coded silently.
- The fixture (`inst/extdata/sample/`, 152 rows, three UEIs) already contains a
  reconciling eight-modification award, a −$310,999 revision, 30 zero-dollar
  administrative actions, and a $40M IDV ceiling against $0 obligated. That is
  enough to demonstrate §3.1 and most of `ACCOUNTING.md` §5 live, without a
  network call. Vignettes must build offline.
- Packaging is done: `VignetteBuilder: knitr` is in `DESCRIPTION` (`knitr` and
  `rmarkdown` were already in `Suggests`), and `_pkgdown.yml` carries an
  `articles` index ordering structure -> acquisition -> panel.
- The fixture also demonstrates the inbound-subaward asymmetry live:
  `CFFMYPABYAG3` shows ~$220k of prime obligations against ~$60M received as
  a subrecipient (`panel.Rmd` uses it). An organization judged on prime awards
  alone can barely exist as a federal recipient.
- `structure.Rmd` renders its workflow diagram with mermaid via the jsdelivr
  CDN in a raw-HTML block. Building the vignette needs no network; *viewing*
  the diagram does. If that ever bothers CRAN, pre-render the SVG and commit it.
