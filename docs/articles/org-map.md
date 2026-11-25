# Organizations, UEIs and the crosswalk

``` r
library(usaspend)
library(data.table)
```

USAspending records money against a **UEI** — a SAM.gov registration.
The panel is about **organizations**. The two are not the same thing:
one organization can hold several registrations, a registration can be
the subsidiary of another, and the API itself blurs the line by
returning a parent’s subsidiaries when you ask for the parent. This
vignette covers how the package maps UEIs to organizations — the
**crosswalk** — and the kinds of relationship that map has to represent.

In short:

- Every UEI whose own history was extracted is **in sample**. Everything
  else in the extract is kept for inspection but left out of the panel.
- `us_panel(org_map = )` assigns each in-sample UEI an `org_id`.
  Unlisted UEIs are their own organization, and subsidiaries follow
  their parent.
- [`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
  finds subsidiaries on its own. With `subsidiaries = FALSE` (the
  default) it records them and tells you it has not pulled them; with
  `subsidiaries = TRUE` it pulls their full histories and counts them as
  part of their parent.

## The default: one UEI, one organization

With no crosswalk, each requested UEI is its own organization and its
`org_id` is the UEI itself:

``` r
ex <- us_sample_extract()
us_org_map(ex$meta$uei)
#>             uei       org_id
#>          <char>       <char>
#> 1: CFFMYPABYAG3 CFFMYPABYAG3
#> 2: FG8QB99NF8K3 FG8QB99NF8K3
#> 3: H7LMD1ANJNN4 H7LMD1ANJNN4
```

## Several registrations, one organization

Large nonprofits hold several SAM registrations, and USAspending splits
their awards across them: NYU has three UEIs, holding 2,687, 4,721 and 9
awards in the pilot. Request all of them and supply a crosswalk mapping
them to one `org_id` — an EIN, say. Every table downstream is then keyed
on the organization:

``` r
# for illustration only: treat two of the sample's UEIs as one organization
om <- data.table(uei    = ex$meta$uei,
                 org_id = c("ORG-1", "ORG-1", "ORG-2"))
p <- suppressWarnings(us_panel(ex, org_map = om))
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
p$panel[, .(awards = uniqueN(award_key), net = sum(obligation_net)), by = org_id]
#>    org_id awards      net
#>    <char>  <int>    <num>
#> 1:  ORG-1     12  3171166
#> 2:  ORG-2      6 22212225
```

The crosswalk can only label data that was pulled. Rows for UEIs not in
the extract are ignored, with a message saying so. **Listing a UEI in
`org_map` does not add it to the sample; requesting it in
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
does.**

## Parents and subsidiaries

SAM records a parent for many registrations, and USAspending carries it
on every transaction as `recipient_parent_uei`. That matters because of
how the API filters.

### The API returns a parent’s subsidiaries — partially

The bulk download filters on `recipient_search_text`, and **that filter
matches the parent UEI as well as the recipient UEI** (see
[`?us_download_submit`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_download_submit.md)).
So a query for a parent also returns its subsidiaries’ transactions —
but only those filed while the queried UEI was *recorded* as their
parent.

The measured case: querying RTI International (`JJHCMK4NT5N3`) returned
transactions of International Resources Group (`R29FEFR7P8H9`), which
RTI acquired in 2017. A download by award ID for one IRG contract found
14 transactions, all with IRG as recipient. The RTI extract held only
the 2 filed with RTI as parent. The other 12, filed under IRG’s earlier
parents L-3 and Engility, never came back. **A subsidiary arrives with
its history cut off at the date the parent relationship began.**

The effect is routine, not a corner case. In a 1,000-organization test
pull, every one of the 4,727 unrequested transactions came in this way:
18 subsidiary UEIs under 10 requested organizations. And “subsidiary” in
SAM covers more than acquisitions:

| kind | example from the test pull | parent-matched transactions |
|----|----|----|
| acquired firm | International Resources Group (acquired 2017) and Masimax Resources, under RTI | 317 |
| affiliated entities | CommonBond Housing, Skyline Tower of St. Paul LP and CB Meadow Village LLC, under CommonBond Communities | 95 |
| other registrations of the same institution | two Harding University UEIs recorded as children of the requested one | 4,006 |
| related operating units | four Ingenium Schools UEIs under a requested Ingenium UEI that has no awards of its own | 7 |

The Harding case shows how much can hang on this. The requested UEI
holds 66 transactions of its own, and its two child registrations hold
4,006. Leave the children out and most of the institution’s federal
money is missing from its panel.

Whether each belongs in “the organization” is an analytic question, and
the package cannot answer it for you. What it does is make sure the
question is visible rather than answered by accident.

### What the extract records: the crosswalk

[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
records every UEI it saw in a crosswalk, `extract$org_map`: requested
UEIs, plus every unrequested recipient whose recorded parent is a
requested UEI. The sample has none, so the rest of this section
simulates one. It takes an award from the sample and re-attributes it to
IRG’s UEI, with a requested UEI as the recorded parent — exactly what
the API returns for a subsidiary.

``` r
KEY <- "ASST_NON_HDTRA12310001_097"
sim <- us_sample_extract()
tx  <- sim$transactions
k   <- tx$award_key == KEY
parent <- tx$recipient_uei[which(k)[1]]
tx$recipient_parent_uei[k] <- parent
tx$recipient_uei[k] <- "R29FEFR7P8H9"
sim$transactions <- tx

us_find_subsidiaries(sim)[, .(uei, relationship, parent_uei, root_uei,
                              extracted, n_parent_matched)]
#>             uei relationship   parent_uei     root_uei extracted n_parent_matched
#>          <char>       <char>       <char>       <char>    <lgcl>            <int>
#> 1: R29FEFR7P8H9   subsidiary H7LMD1ANJNN4 H7LMD1ANJNN4     FALSE                8
```

The columns:

| column | meaning |
|----|----|
| `relationship` | `"requested"` or `"subsidiary"` |
| `parent_uei` | the parent recorded on the subsidiary’s transactions |
| `root_uei` | the requested UEI at the top of the chain. A subsidiary’s own subsidiaries, found when it is pulled, share its root |
| `org_id` | the organization it rolls up to. Until [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md) applies your crosswalk, this is the root UEI |
| `extracted` | whether the UEI’s **own** history is in the extract |
| `n_parent_matched` | transactions that arrived through the parent match |

[`us_find_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_find_subsidiaries.md)
works on any extract, including ones made before the crosswalk existed.
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
stores the same table as `extract$org_map`.

### `subsidiaries = FALSE`: recorded, not pulled

This is the default. The subsidiaries go into the crosswalk with
`extracted = FALSE`, and when the extract finishes it tells you so:

``` r
sim$org_map <- usaspend:::extract_crosswalk(sim)
usaspend:::report_subsidiaries(sim$org_map)   # what us_extract() prints
#> ! 1 subsidiary UEI of 1 requested organization was added to the crosswalk (`$org_map`),
#>   but its full transactions have not been extracted.
#> ℹ The API matches parent UEIs, so the extract holds only the 8 transactions they filed
#>   while a requested UEI was recorded as parent -- not their earlier history.
#> ℹ Their awards are left out of the panel, and `us_reconcile()` labels them
#>   "out_of_sample": with truncated histories they could not reconcile to the awards'
#>   lifetime totals.
#> → To count them as part of their parents, pass the extract to `us_add_subsidiaries()` or
#>   extract with `subsidiaries = TRUE`.
#> → See `vignette("org-map", package = "usaspend")`.
```

Their transactions stay in the extract but are **out of sample**:

``` r
p <- us_panel(sim)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 16 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
#> Dropping 8 transactions on 1 UEI outside the organization map.
p$org_map[, .(uei, relationship, org_id, in_sample)]
#>             uei relationship       org_id in_sample
#>          <char>       <char>       <char>    <lgcl>
#> 1: CFFMYPABYAG3    requested CFFMYPABYAG3      TRUE
#> 2: FG8QB99NF8K3    requested FG8QB99NF8K3      TRUE
#> 3: H7LMD1ANJNN4    requested H7LMD1ANJNN4      TRUE
#> 4: R29FEFR7P8H9   subsidiary H7LMD1ANJNN4     FALSE
KEY %in% p$panel$award_key            # left out of the panel
#> [1] FALSE
p$awards[award_key == KEY, in_sample] # kept in the spine, flagged
#> [1] FALSE
```

They are left out because the history is truncated. The award’s reported
lifetime total counts every action, but the extract holds only the ones
filed under the requested parent. So
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
does not report the gap as an unexplained break. It gives the award its
own label, tested before any other:

``` r
r <- us_reconcile(p)
#> Reconciled 18 awards: 14 exact (78%).
#> • ok=14 no_reported_total=2 break=1 out_of_sample=1
#> 1 award held only by UEIs outside the organization map: "out_of_sample" (typically
#> subsidiaries matched through a parent UEI, histories truncated).
r[award_key == KEY, .(tx_sum, total_obligated, status)]
#>     tx_sum total_obligated        status
#>      <num>           <num>        <char>
#> 1: 1300000         1300000 out_of_sample
```

In the 1,000-organization test, 370 of 15,420 awards were out of sample,
and 41 of them had previously been counted as unexplained breaks (\$232M
of gap).

### `subsidiaries = TRUE`: pulled in full, counted with the parent

``` r
ex <- us_extract(uei, years = 2008:2025, subsidiaries = TRUE)

# or, on an extract you already have, without repeating the main pull:
ex <- us_add_subsidiaries(ex)
```

Each subsidiary UEI is then queried **in its own right**. A query on its
own UEI matches `recipient_uei`, so it returns the whole history, not
only the slice filed under the parent. The UEI joins the extracted set
(`ex$meta$uei`; the original request stays in `ex$meta$uei_requested`)
and is marked `extracted = TRUE`. A subsidiary’s own pull can reveal
subsidiaries of its own; they are pulled in further rounds
(`max_rounds`, default 3). Rows that arrived through the parent match
are not duplicated. With `subawards = "out"` or `"both"`, the
subsidiaries’ awards get pass-through fetched too.

What this recovers, measured on a live FY2016–2018 pull for RTI: the RTI
query returned 81 IRG transactions, all dated February 2017 or later.
IRG’s own pull added 117 more, from October 2015 to February 2017, filed
under its previous parent. That is the history the parent match cannot
see.

In the panel, an extracted subsidiary takes the `org_id` of the
requested UEI it rolls up to. You do not need to list it in your
crosswalk:

``` r
# simulate the second pull: mark the subsidiary extracted
full <- sim
full$org_map <- copy(sim$org_map)[uei == "R29FEFR7P8H9", extracted := TRUE]
full$meta$uei <- c(sim$meta$uei, "R29FEFR7P8H9")

om <- data.table(uei = sim$meta$uei, org_id = c("ORG-A", "ORG-B", "ORG-C"))
p  <- us_panel(full, org_map = om)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
p$org_map[, .(uei, relationship, org_id, in_sample)]
#>             uei relationship org_id in_sample
#>          <char>       <char> <char>    <lgcl>
#> 1: CFFMYPABYAG3    requested  ORG-A      TRUE
#> 2: FG8QB99NF8K3    requested  ORG-B      TRUE
#> 3: H7LMD1ANJNN4    requested  ORG-C      TRUE
#> 4: R29FEFR7P8H9   subsidiary  ORG-C      TRUE
unique(p$panel[award_key == KEY, org_id])
#> [1] "ORG-C"
us_reconcile(p)[award_key == KEY, status]
#> Reconciled 18 awards: 15 exact (83%).
#> • ok=15 no_reported_total=2 break=1
#> [1] "ok"
```

An explicit row in `org_map` overrides this, for instance to keep a
subsidiary as an organization of its own:

``` r
om2 <- rbind(om, data.table(uei = "R29FEFR7P8H9", org_id = "IRG"))
unique(us_panel(full, org_map = om2)$panel[award_key == KEY, org_id])
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
#> [1] "IRG"
```

### Before the parent relationship began

A full history includes the years before the relationship existed. For
IRG, that is everything before RTI acquired it. With
`subsidiaries = TRUE` those years count toward the parent organization,
which is right if the question is “what does this organization’s current
footprint look like over time” and wrong if it is “what was this
organization obligated in each year”.

For the second question, drop a subsidiary’s transactions filed under
any parent outside the crosswalk before building the panel:

``` r
sub_uei <- ex$org_map[relationship == "subsidiary" & extracted == TRUE, uei]
tx <- ex$transactions
pre <- tx$recipient_uei %in% sub_uei &
  !tx$recipient_parent_uei %in% ex$org_map$uei
ex$transactions <- tx[!pre]
p <- us_panel(ex, org_map = om)
```

Expect those awards to fail reconciliation afterwards (`window_edge` if
the cut falls in the first year, otherwise
[`break`](https://rdrr.io/r/base/Control.html)). You have deliberately
cut their histories, so the identity no longer holds.

### Requested UEIs whose parent was not requested

The match only runs downward: from a requested parent to its
subsidiaries. In the test pull, 42 requested UEIs recorded a parent that
was *not* requested. The package does not follow those upward. Pulling
the parent would bring in its whole portfolio, which the request did not
ask for. To see them:

``` r
ex$transactions[recipient_uei %in% ex$meta$uei &
                  !is.na(recipient_parent_uei) &
                  recipient_parent_uei != recipient_uei &
                  !recipient_parent_uei %in% ex$meta$uei,
                .N, by = .(recipient_uei, recipient_parent_uei)]
```

## Relationships the crosswalk does not hold

Two other relationships look similar but live elsewhere, because they
belong to awards rather than to organizations:

- **An award held by several recipients.** NIH grants follow the
  principal investigator between institutions, so one award can carry
  transactions under several UEIs over its life. Both slices can be in
  sample, each belonging to its own organization. The panel grain is
  organization × award × year for this reason, and
  [`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
  labels these `multi_recipient`. An award counts as in sample if *any*
  of its transactions is on an extracted UEI.
- **Prime and subrecipient.** Money received as a subawardee is keyed
  through the subawardee UEI into `subawards_in`, not through the
  crosswalk. See
  [`vignette("subawards")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/subawards.md).

## Summary

| relationship | how it enters | in sample? | `org_id` |
|----|----|----|----|
| requested UEI | `us_extract(uei)` | yes | from `org_map`, else the UEI |
| several registrations of one org | request all, map to one `org_id` | yes | shared `org_id` |
| subsidiary, `subsidiaries = FALSE` | found through the parent match | **no**: `out_of_sample`, history truncated | parent’s, for reference |
| subsidiary, `subsidiaries = TRUE` or [`us_add_subsidiaries()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_add_subsidiaries.md) | pulled on its own UEI | yes, full history | parent’s, unless `org_map` lists it |
| `org_map` row for a UEI never pulled | — | no (ignored, with a message) | — |
| parent of a requested UEI | not followed | no | — |
| other recipients on a shared award | appear on the award’s transactions | no, unless requested | — |
