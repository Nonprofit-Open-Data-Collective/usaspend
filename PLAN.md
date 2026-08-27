# usaspend — package implementation plan

Turning a list of SAM.gov UEIs into a clean `ORG × AWARD × YEAR` panel of net
federal revenue.

Written 2026-08-27. Every API claim below was measured live against
`api.usaspending.gov`, not read off the docs. Where something is assumed rather
than measured it says so.

Companion documents:

- `ACCOUNTING.md` — the reconciliation rules the normalization layer implements
- `VIGNETTES.md` — what the user-facing documentation has to teach, and the
  measured material to teach it with
- `../npmatch/data-dev/usaspending/SUBAWARD-NOTES.md` — research note: fetching
  and tabulating subawards so they reconcile (the measured findings)
- `../npmatch/data-dev/usaspending/EXTRACT-PLAN.md` — the sampling and
  feasibility work this package is built on

---

## 1. What the package produces

Four canonical tables (`us_schema()`), plus one derived org-level table:

| table | grain | what it is |
|---|---|---|
| `transactions` | award action | the cleaned ledger; the only grain that supports an annual panel |
| `awards` | prime award | the spine — agency, type, CFDA/NAICS, period of performance, lifetime totals |
| `subawards` | FSRS report line | pass-through, in both directions |
| **`panel`** | **org × award × year** | **the deliverable** |
| `subawards_in` | org × year | subaward revenue *received* -- reported under other primes' award keys, so it cannot sit on this organization's award rows |

The panel carries, per organization-award-year: the awarding agency and
sub-agency, the award type category, gross positive and gross negative
obligations and their net, dollars passed through as subawards, and
`net_revenue = obligation_net − subaward_out_amount`.

Above the panel sit the analysis helpers: `us_org_year()` collapses to
org × year, `us_rollup()` aggregates to org/year/state grains with inbound
subawards folded in (adding `total_net = obligation_net + subaward_in −
subaward_out`), and `us_adjust_inflation()` restates any year-grained table
into constant dollars via the bundled CPI-U series (`us_price_index()`).

### One thing the panel is not

`obligation_net` is a **commitment**, not a payment. Federal award data carries
no annual cash figure at all — `total_outlayed_amount_for_overall_award` exists
but is award-lifetime and mostly blank before FY2017. Annual disbursements live
in the account-level File B/C extracts, which the award endpoints do not expose.

This is the single most consequential thing to state plainly in the
documentation, because "obligations" and "revenue received" differ by years of
timing on multi-year awards. The package handles it three ways: `us_money_column("outlay")`
raises an error rather than substituting something close; `us_reconcile()` reports
the lifetime obligation-to-outlay ratio per award so the size of the gap is
visible; and the panel column is named `obligation_net`, never `revenue`.

---

## 2. Architecture

```
                    us_extract()
                   /            \
          source = "api"    source = "archive"
                   |              |
    POST /download/transactions/  FY####_All_{Assistance,Contracts}_Full.zip
    us_download_run()             us_archive_manifest/download/filter()
    us_download_fetch()           duckdb scan, filter on recipient_uei
                   \            /
                    \          /
              us_harmonize_transactions()      <- CANONICAL SCHEMA BOUNDARY
              us_harmonize_subawards()
                         |
              us_normalize_transactions()      dedupe, corrections, deletes,
              us_normalize_subawards()         aggregate records, flags
              us_normalize_awards()
                         |
              us_ledger()                      signed, classified
                         |
              us_net_by_year()   us_subaward_by_year()
                         \          /
                       us_panel()  ->  panel + reconciliation
                        /          \
         us_reconcile()              us_org_year()  us_rollup()
         us_audit()                  org x year; org/year/state grains,
                                     inbound subawards folded in
                                            |
                                     us_adjust_inflation()
                                     constant dollars (bundled CPI-U)
```

Everything above the canonical schema boundary is acquisition and knows about
HTTP, zip files and duckdb. Everything below is accounting and knows nothing
about where a row came from. That boundary is what makes the two acquisition
paths interchangeable, and it is enforced by test, not by convention.

---

## 3. Acquisition: two paths, one output

### Path A — REST API, for one organization or a small batch

```r
ex <- us_extract("CFFMYPABYAG3", years = 2015:2025)
```

Submits jobs to `POST /api/v2/download/transactions/`, polls, fetches, unzips,
harmonizes. Returns prime transactions plus — as a by-product — subawards.

Constraints, all measured:

- **`recipient_search_text` caps near 20 values.** 20 succeeds, 25 fails. The
  cap is undocumented. In practice large recipients time out server-side well
  below it, so the default batch is **5** and failed batches are retried one UEI
  at a time; a single oversized recipient otherwise poisons its whole batch.
- **The job state machine is `ready → running → finished | failed`.** `ready` is
  a queue state. Treating anything other than `running` as terminal reads a
  freshly-queued job as done and throws the download away.
- **`spending_by_award` is capped at 10,000 records**, silently. Use the
  download endpoint, never the search endpoint, for extraction.
- **Sustained single-recipient calls get rate-limited.** Throttle at 2 req/s
  with exponential backoff, and record failures explicitly — a swallowed error
  looks exactly like a recipient with no awards.
- **Search is floored at 2007-10-01.** FY2001–FY2007 needs the Custom Award
  Download or the full database.

### Path B — annual Award Data Archive, for large batches

```r
man <- us_archive_manifest(2008:2025) |> us_archive_download()
tx  <- us_archive_filter(ueis, man$csv_dir[1], group = "assistance")
```

Downloads whole-fiscal-year files and filters them locally with duckdb. Cost is
fixed in the number of fiscal years rather than the number of recipients.

Measured: `list_monthly_files` serves exactly two types, `assistance` and
`contracts` (direct payments, loans and "other" are folded into assistance).
`FY2024_All_Assistance_Full` is 1.37 GB compressed and unpacks to six CSV parts.
Each fiscal year also has a `Delta` file covering changes since the last full
refresh.

**Prime transactions only. There is no bulk subaward archive** — see §4.

### Choosing

`us_extract_plan()` computes the comparison from measured constants and
recommends a path; `us_extract(source = "auto")` follows it.

| input | API path | archive path |
|---|---|---|
| 1 org (3 UEIs), 18 FY | ~1 min | ~4 hours |
| 1,364 UEIs, 18 FY | ~110 min | ~4 hours |
| 126,784 UEIs, 18 FY | ~140 hours | ~4 hours |

Crossover is around **2,900 UEIs** at 18 fiscal years. The top-1,000 sample
(1,364 UEIs) sits below it, which is why `EXTRACT-PLAN.md` recommends the API
for that run; extending to the full crosswalk flips the recommendation.

### API vs archive: the measured comparison — **[measured 2026-08-27]**

The schema assumption was settled by downloading real archives (FY2015, both
types; archives generated 2026-08-06) and comparing them row-by-row against
the same-window slice of the pilot's API pull (2026-08-27), restricted to the
same 130 UEIs. Results:

1. **Column names match exactly.** All 32 mapped assistance columns and all
   26 mapped contract columns are present in the archives.
   `us_archive_verify_schema()` confirms this in one call.

2. **The row universes are identical, and vintage skew is measurably tiny.**
   All four cells, archive vs same-window API slice:

   | cell | rows | one-sided keys | obligation diff |
   |---|---|---|---|
   | FY2015 assistance | 8,795 = 8,795 | 0 | $0 |
   | FY2015 contracts | 2,947 = 2,947 | 0 | $0 |
   | FY2024 assistance | 17,225 vs 17,224 | 1 | −$4,125.69 |
   | FY2024 contracts | 2,487 = 2,487 | 0 | $0 |

   The single one-sided row is the vintage mechanism caught in the act: a
   NASA de-obligation modified 2026-08-21, fifteen days *after* the archive
   was generated. Three weeks of skew at the leading edge amounts to one row
   in 17,000 and $4.1k in $4.9bn (0.00008%), plus re-corrected fields on six
   common rows. Settled years show zero. The annual `Delta` files exist for
   exactly this residual.

3. **But archive *contract* files transpose two (code, description) column
   pairs.** In the archive layout, `action_type_code` carries the description
   (`FUNDING ONLY ACTION`) and `action_type` carries the code (`C`); likewise
   `idv_type_code` carries the mnemonic (`IDC`, `BPA`, `FSS`, `BOA`) and
   `idv_type` the letter (`B`, `E`, `C`, `D`). Column-name verification cannot
   see this — the names match; the values are swapped. Before the fix it
   silently misclassified 78% of contract actions and every IDV.
   `us_harmonize_transactions()` now detects the transposition from the value
   shapes and un-swaps it (either layout harmonizes identically; regression
   test in `test-schema.R`), and `us_archive_verify_schema()` warns when it
   samples a transposed archive. Assistance files are not affected.

4. **Two benign field-level differences remain, both award-level derived
   stamps, not transaction facts.** `award_total_obligated` differed on 17 of
   8,795 assistance rows (15 awards, all NIH — the PI-transfer population
   whose lifetime totals keep moving; the two files were generated three weeks
   apart). `award_id_uri` differs wherever present: its numeric suffix is a
   generated identifier that is not stable across systems — never key on it.
   The package keys on `award_key`, which matched on every row.

5. **`utils::download.file` truncates gigabyte archives at R's default
   60-second timeout**, and a truncated zip then masquerades as a cache hit.
   `us_archive_download()` now raises the timeout
   (`usaspend.download_timeout`, default 3600 s), validates every cached zip's
   central directory before trusting it, and deletes failed partials.

6. **Archive FY membership is by `action_date` fiscal year.** Every row in
   the FY2015 files has an action date inside FY2015 — the same semantics as
   an API pull with an `action_date` time period, so the two paths partition
   time identically.

What the archives structurally lack, regardless of vintage: **subawards (both
directions), and everything before FY2008.** §4 covers how subawards are
appended through API calls from either path.

---

## 4. Subawards: the correction to the original plan

`EXTRACT-PLAN.md` §2 treats subawards as "delivered alongside prime data".
Measured on 2026-08-27, that is true but misleading in a way that matters.

A three-UEI pull returned 32 subaward rows. **All 32 were inbound** — rows where
the queried UEI is the *subawardee*. Zero were outbound.

That is the opposite of what the panel needs. Netting out pass-through requires
subawards where the organization is the **prime**, and filtering on
`recipient_search_text` never returns those.

Nor is there a bulk file: `list_monthly_files` offers only `assistance` and
`contracts`, both prime transactions.

So outbound subawards have to be queried **by prime award**. Two routes, both
measured:

```
# per award (fine for a handful):
GET  /api/v2/awards/{award_key}/     -> subaward_count, total_subaward_amount
POST /api/v2/subawards/ {award_id}   -> paginated detail with action dates

# batched (the real one -- us_fetch_subawards_batch()):
POST /api/v2/search/spending_by_award/  subawards=true, award_ids=[<=~500 ids]
```

`award_ids` with `subawards = true` returns FSRS subawards *under* the named
prime awards — the outbound direction. Measured cap: 500 ids per request works,
1,000 returns HTTP 503; batches of 400 with a count-first guard against the 10k
result cap turned the pilot's 61,738 awards into under 200 requests. FAINs are
ambiguous across agencies, so results are filtered back to the exact
`prime_award_generated_internal_id`.

Verified against `ASST_NON_4482DRCAP00000001_070` (FEMA California public
assistance): $14.74 bn obligated, 2,330 subawards totalling $9.97 bn — 68 %
pass-through. Exactly the case the panel has to get right, and exactly the case
a recipient-filtered pull misses entirely.

**Both inbound and outbound matter, for different reasons.** Outbound is
subtracted from revenue. Inbound is *additional* revenue that appears nowhere in
prime data — an organization that only ever receives subawards looks like a
non-recipient. Some of the 223 zero-award organizations in `EXTRACT-PLAN.md` §6
may be exactly that, which is worth checking before concluding they are genuine
non-recipients.

Append options, from either acquisition path: `subawards = "out"` fetches
pass-through by prime award (`us_fetch_subawards_out()` /
`us_fetch_subawards_batch()`); on the archive path, `subawards = "in"`
appends inbound rows through `us_fetch_subawards_in()`, which runs the
standard API download jobs and harvests only their subaward files. A
subaward-only custom download (`bulk_download/awards/` with
`sub_award_types`) was probed live on 2026-08-27: the endpoint accepts
`recipient_search_text` and creates the job, but the build ran far longer
than a standard transactions job, so it is not the package route.

---

## 5. Normalization and accounting

Specified in full in `ACCOUNTING.md`. **All implemented and validated against the 50-nonprofit pilot** (302,025 prime
transactions, 39,243 subaward rows; pulled 2026-08-27). The full pipeline runs
the pilot end-to-end in ~1 minute and yields 168,362 org × award × year rows
netting to $118.5bn.

| function | does | spec | pilot result |
|---|---|---|---|
| `us_normalize_transactions()` | dedupe, corrections/deletes, aggregate records, anomaly flags | §3 | 20,828 exact duplicates removed (6.9%); 18,447 rows flagged |
| `us_normalize_awards()` | award spine; latest-non-missing attributes; `n_recipients` | §4 | 61,738 awards; 130 legitimately span organizations |
| `us_normalize_subawards()` | direction, dedupe restatements, year basis | §6 | 7,427 restatement duplicates removed; all rows inbound or internal |
| `us_ledger()` | signed ledger; loans excluded via zero obligations | §5 | $626bn student-loan face value correctly kept out of revenue |
| `us_net_by_year()` | the core aggregation; three de-obligation policies | §5 | `restate` shifts <1%/yr except at the data's leading edge |
| `us_subaward_by_year()` | subaward flows by direction and year | §6 | $13.97bn inbound revenue identified |
| `us_panel()` | assembly | §7 | grain unique; gross/net split verified |
| `us_reconcile()` / `us_audit()` | invariants and diagnostics | §8 | 72% of awards reconcile to the dollar; breaks classified |

---

## 6. Test fixture

`inst/extdata/sample/` holds a real 152-row three-UEI pull, kept verbatim, loaded
by `us_sample_extract()`. It is small but it already contains most of the cases
the accounting rules have to handle, and it caught two live bugs during
development:

- **`idv_type_code` is a bare letter.** FPDS writes `"B"`, not `"IDV_B"`, and
  `"B"` alone reads as Purchase Order. Contract IDV rows carry a blank
  `award_type_code`, so without the prefix every IDV was silently mistyped.
- **`award_type` description strings are unstable.** The same file carries
  `"DELIVERY ORDER"` and `"DO"` for code C, `"PURCHASE ORDER"` and `"PO"` for
  code B. Grouping on the description splits one category in two.

Also present: an award whose eight transactions sum exactly to its reported
lifetime total (the reconciliation invariant, holding); a de-obligating revision
of −$310,999; 30 zero-dollar administrative modifications out of 111 contract
actions; and an IDV with a $40,000,000 ceiling against $0 obligated.

---

## 7. Roadmap

**Stage 1 — acquisition (done).** Client, job machinery, archive path, canonical
schema, code tables, fixture, 90 tests passing.

**Stage 2 — normalization (done).** Implement §3, §4 and §6 of
`ACCOUNTING.md` against real volume. Deliverable: `us_normalize_*()` and a
duplication/anomaly report over the pilot.

**Stage 3 — accounting (done).** Implement §5 and §7. Deliverable:
`us_panel()`, both de-obligation policies, and a comparison of what the choice
costs on the pilot.

**Stage 4 — reconciliation (done).** Implement §8. Deliverable: the
lifetime identity check at scale, the obligation-to-outlay gap distribution, and
subaward coverage rates.

**Stage 5 — scale.** Run the 1,364-UEI top-1000 sample on the API path. Verify
the archive schema, then run the full crosswalk on the archive path.

**Stage 6 — documentation (in progress).** Vignettes teaching the data model,
the award-type taxonomy, subaward direction, and the accounting rules. Planned
set and the measured material to build them from are in `VIGNETTES.md`. Three
are written and render offline off `us_sample_extract()`: `structure.Rmd`
(architecture + workflow diagram), `acquisition.Rmd` (API vs archive path),
`panel.Rmd` (reading the output; rollups; inflation adjustment).
`VignetteBuilder: knitr` is in `DESCRIPTION`. Still to write: data model,
award types, subaward direction, accounting rules, reconciliation.

### Settled since first written

- **The outbound subaward pass ran on the pilot** (2026-08-28; see
  `SUBAWARD-NOTES.md`): $12.6bn outbound against $118.5bn net obligations →
  net revenue $105.9bn, reconciling to the dollar with
  `us_panel(fill_gaps = TRUE)`.
- **The archive schema is verified and the paths compared row-by-row** — §3
  above. Row universes and dollar totals matched exactly at FY2015; the
  contract code-pair transposition was found and is repaired in the
  harmonizer.

### Open questions, in rough priority order

1. **Inbound subawards and the zero-award organizations.** Do any of the 223
   receive federal money purely as subrecipients? The pilot's $14.0bn of
   inbound subaward revenue says the mechanism is large enough to matter.
2. **IDV rollup.** Delivery orders are separate awards with their own keys.
   Rolling them to the parent is a modelling choice; the argument exists and
   defaults to off, but the pilot should show what it changes.
3. **De-obligation policy.** `as_posted` is the default. Measure how far
   `restate` moves the panel before committing.
4. **Parent/child UEIs.** Prime summaries carry `recipient_parent_uei`.
   USAspending may know about subsidiary registrations absent from the SAM
   crosswalk.
5. **Calendar vs fiscal year.** The panel defaults to calendar year as
   specified. Both bases are derived from `action_date` rather than trusting
   `action_date_fiscal_year`, so they are guaranteed consistent — but the
   downstream 990 comparison may want the fiscal basis.
