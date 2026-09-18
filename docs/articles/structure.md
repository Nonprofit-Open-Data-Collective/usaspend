# Package architecture

usaspend turns a list of SAM.gov UEIs into a clean **organization ×
award × year** panel of net federal award activity. The package is
organized as a pipeline with one hard internal boundary, and every
exported function has a fixed place in it.

## The shape of the pipeline

Four layers:

1.  **Acquisition** — get raw transaction CSVs from USAspending, by
    either of two interchangeable paths (REST API download jobs, or the
    bulk annual archives). This layer knows about HTTP, zip files, and
    duckdb.
2.  **Harmonization** — map both paths’ raw columns onto one canonical
    schema. This is the boundary: everything below it never learns where
    a row came from.
3.  **Normalization and accounting** — de-duplicate, apply corrections
    and deletes, classify award and action types, net de-obligations by
    year, resolve subaward direction. The rules are specified in the
    project’s `ACCOUNTING.md` and implemented one function per section.
4.  **Assembly and analysis** — build the panel, roll it up, deflate it,
    reconcile it against USAspending’s independently computed lifetime
    totals.

## The workflow, as function calls

A typical session touches four verbs — plan, extract, panel, rollup —
and each expands into the calls below. Solid arrows are data flow; the
dashed arrow is a recommendation.

``` mermaid
flowchart TD
    plan["us_extract_plan()"] -. "recommends a path" .-> extract
    extract["us_extract()"]

    extract -- "source = 'api'" --> api["us_download_run()
us_download_fetch()"]
    extract -- "source = 'archive'" --> arch["us_archive_manifest()
us_archive_download()
us_archive_filter()"]
    extract -- "subawards = 'out'" --> subout["us_fetch_subawards_out()
us_fetch_subawards_batch()"]

    api --> harm["us_harmonize_transactions()
us_harmonize_subawards()"]
    arch --> harm
    subout --> harm

    harm == "canonical schema boundary" ==> ntx

    subgraph panelfn ["us_panel()"]
        direction TB
        ntx["us_normalize_transactions()"] --> naw["us_normalize_awards()"]
        ntx --> ledger["us_ledger()"]
        ledger --> net["us_net_by_year()"]
        nsb["us_normalize_subawards()"] --> sby["us_subaward_by_year()"]
        net --> asm(["assemble: org × award × year"])
        sby --> asm
        naw --> asm
    end

    asm --> recon["us_reconcile()
us_audit()"]
    asm --> orgyr["us_org_year()"]
    asm --> roll["us_rollup()"]
    roll --> infl["us_adjust_inflation()"]
    orgyr --> infl
```

*The diagram above requires JavaScript (and an internet connection for
the mermaid renderer); the layer tables below carry the same
information.*

In practice you call the top and the bottom of the diagram;
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
runs its interior for you:

``` r
ex <- us_extract(ueis, years = 2008:2025, subawards = "out")
p  <- us_panel(ex)
us_reconcile(p)
us_rollup(p, year = TRUE) |> us_adjust_inflation(target_year = 2025)
```

## Why the boundary matters

The two acquisition paths return different raw files: the API path
serves per-job CSVs named by USAspending’s download service; the archive
path serves whole-fiscal-year files with (nominally) the same columns.
[`us_harmonize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_harmonize_transactions.md)
and
[`us_harmonize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_harmonize_transactions.md)
map both onto one canonical schema
([`us_schema()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_schema.md)),
and **everything downstream is written against that schema only**. That
is what makes the paths interchangeable — you can extract a pilot over
the API today and re-extract at scale from the archives next month, and
the accounting layer cannot tell the difference. The boundary is
enforced by test, not by convention.

## Function inventory, by layer

**Planning**

| function | role |
|----|----|
| [`us_extract_plan()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract_plan.md) | cost both paths from measured constants; recommend one |
| [`us_award_counts()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_award_counts.md) | pre-screen a UEI’s award volume |
| [`us_validate_uei()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_validate_uei.md) | shape-check UEIs |
| [`us_org_map()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_map.md) | UEI → organization crosswalk |

**Acquisition**

| function | role |
|----|----|
| [`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md) | the single entry point; dispatches to a path |
| [`us_download_submit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md) / [`us_download_status()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_status.md) / [`us_download_fetch()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_fetch.md) / [`us_download_run()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_run.md) | API bulk-download job machinery |
| [`us_archive_manifest()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_manifest.md) / [`us_archive_size()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_size.md) / [`us_archive_download()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_download.md) / [`us_archive_filter()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_archive_filter.md) | annual-archive machinery (duckdb) |
| [`us_fetch_subawards_out()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_out.md) / [`us_fetch_subawards_batch()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_subawards_batch.md) / [`us_fetch_award()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_fetch_award.md) | outbound subawards, queried per prime award |
| [`us_cache_dir()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_cache_dir.md) / [`us_cache_status()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_cache_dir.md) / [`us_cache_clear()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_cache_dir.md) | download cache |

**Harmonization (the schema boundary)**

| function | role |
|----|----|
| [`us_harmonize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_harmonize_transactions.md) / [`us_harmonize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_harmonize_transactions.md) | raw columns → canonical schema |
| [`us_schema()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_schema.md) / [`us_empty()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_schema.md) | the canonical table definitions |

**Normalization and accounting**

| function | role |
|----|----|
| [`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md) | de-duplicate; corrections and deletes; aggregate records; anomaly flags |
| [`us_normalize_awards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_awards.md) | the award spine; latest-non-missing attributes |
| [`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md) | direction; de-duplicate FSRS restatements |
| [`us_classify_award_type()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_classify_award_type.md) / [`us_classify_action()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_classify_action.md) / [`us_award_type_codes()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_award_type_codes.md) | code tables (labels come from codes, never description strings) |
| [`us_ledger()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_ledger.md) / [`us_money_column()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_money_column.md) | the signed ledger; which dollar column counts |
| [`us_net_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_net_by_year.md) | net by year, under a chosen de-obligation policy |
| [`us_subaward_by_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_subaward_by_year.md) | subaward flows by direction and year |

**Assembly and analysis**

| function | role |
|----|----|
| [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md) | the deliverable: org × award × year |
| [`us_org_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_year.md) | collapse to org × year |
| [`us_rollup()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_rollup.md) | general aggregation, folding inbound subawards in |
| [`us_adjust_inflation()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_adjust_inflation.md) / [`us_price_index()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_price_index.md) | constant dollars |
| [`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md) / [`us_audit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_audit.md) | external and structural checks |
| [`us_sample_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_sample_extract.md) | the bundled offline fixture all documentation runs on |

## Where the rules are written down

Each normalization function’s help page states *what* it does; the *why*
— with the measured evidence — lives in the project’s `ACCOUNTING.md`
(accounting rules, one numbered section per function) and `PLAN.md`
(architecture and measured API behaviour), in the [package
repository](https://github.com/Nonprofit-Open-Data-Collective/usaspend).
