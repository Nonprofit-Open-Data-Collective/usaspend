# The panel: reading, rolling up, and deflating the output

Everything in this vignette runs offline, on the bundled sample extract
— a real three-UEI pull from USAspending kept verbatim in
`inst/extdata/sample/`.

``` r
library(usaspend)
ex <- us_sample_extract()
p  <- us_panel(ex)
#> Warning: No outbound subawards present -- pass-through cannot be netted out.
#> ℹ Bulk downloads match on the subawardee. Use `us_fetch_subawards_out()` to fetch
#>   pass-through by prime award.
p
```

## What `us_panel()` returns

A `usaspend_panel` is a list of tables, not just the panel itself:

| element | grain | what it is |
|----|----|----|
| `panel` | org × award × year | **the deliverable** |
| `awards` | prime award | the spine: agency, type, CFDA/NAICS, lifetime totals |
| `transactions` | award action | the normalized ledger the panel was netted from |
| `subawards` | FSRS report line | normalized subawards, with direction |
| `subawards_in` | org × year | subaward dollars *received* — see below |
| `org_map` | UEI | the crosswalk used: `org_id`, relationship, and which UEIs are in sample — see [`vignette("org-map")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/org-map.md) |
| `meta` | — | period, measure, de-obligation policy, build time |

``` r
names(p)
#> [1] "panel"        "awards"       "transactions" "subawards"    "subawards_in"
#> [6] "org_map"      "meta"
p$panel[1:3, .(org_id, award_key, year, obligation_net, net_revenue)]
#>          org_id                                          award_key  year obligation_net
#>          <char>                                             <char> <int>          <num>
#> 1: CFFMYPABYAG3 CONT_AWD_HT009023FG0570037_9700_W81K0219A0012_9700  2023          14206
#> 2: CFFMYPABYAG3          CONT_AWD_W81K0209P0001_9700_-NONE-_-NONE-  2008          27370
#> 3: CFFMYPABYAG3          CONT_AWD_W81K0209P0001_9700_-NONE-_-NONE-  2009          17370
#> 1 variable not shown: [net_revenue <num>]
```

## How to read the dollar columns

Five rules cover most misreadings of the panel.

### 1. Obligations are commitments, not cash

`obligation_net` is the net federal obligation booked to the
organization-award-year: money the government *committed* by signing
award actions dated in that year. Federal award data carries no annual
disbursement figure at all, so an obligations panel is the closest thing
to annual revenue the source supports. On multi-year awards, obligations
and cash differ by years of timing.

### 2. Net revenue is obligations minus pass-through

An organization does not keep every dollar obligated to it. Money it is
obliged to pay onward to subrecipients — pass-through — is someone
else’s revenue. The panel nets it out:

    net_revenue = obligation_net − subaward_out_amount

But outbound subawards are only present if the extract fetched them
(`subawards = "out"` or `"both"` in
[`us_extract()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_extract.md)
— they require a separate API pass, one call per prime award). When they
were not fetched, the panel says so rather than letting a zero pass for
a measured zero:

``` r
unique(p$panel$flags)
#> [1] "subawards_out_not_fetched"
p$meta$subawards_out_fetched
#> [1] FALSE
```

On this sample `net_revenue` equals `obligation_net` — true for any
recipient-filtered pull until the outbound pass runs.

### 3. Negatives are real; gross and net travel together

De-obligations — claw-backs, downward revisions, recoveries at closeout
— are ordinary federal award activity, and they arrive under every
action-type label, including `CONTINUATION`. The panel keeps them, which
means an org-award-year can legitimately net negative. It also always
carries the gross components, because \$1M net from +\$5M and −\$4M is a
different fact than \$1M from a single clean award:

``` r
p$panel[obligation_negative < 0,
        .(award_key, year, obligation_positive, obligation_negative, obligation_net)]
#>                                                    award_key  year obligation_positive
#>                                                       <char> <int>               <num>
#> 1:                 CONT_AWD_W81K0209P0001_9700_-NONE-_-NONE-  2009               27370
#> 2:                 CONT_AWD_W81K0209P0001_9700_-NONE-_-NONE-  2013                7000
#> 3:                 CONT_AWD_W81K0214P0076_9700_-NONE-_-NONE-  2019                   0
#> 4: CONT_AWD_HHSD2002007200320001_7523_HHSD200200720032I_7523  2019                   0
#> 5: CONT_AWD_HHSD2002007200320002_7523_HHSD200200720032I_7523  2019                   0
#> 6: CONT_AWD_HHSD2002007200320004_7523_HHSD200200720032I_7523  2019                   0
#> 7:                                     ASST_NON_D8732143_075  2024                   0
#> 2 variables not shown: [obligation_negative <num>, obligation_net <num>]
```

### 4. Loans and student aid are separable, and loan face value is never revenue

Every row carries `award_family` (`grant`, `contract`, `direct_payment`,
`loan`, `other`, `idv`). Direct loans book their face value in
`loan_face_value` — a liability of the borrower, not income of the
organization — and their obligation is typically \$0. Direct payments to
universities are mostly student aid (Pell, work-study) flowing *through*
the institution; filter on `award_family` to include or exclude them
explicitly.

### 5. Inbound subawards are additional revenue — and they live in a separate table

A recipient-filtered pull returns subawards where your organization is
the **subawardee**: money received from another organization’s federal
award, which appears nowhere in prime award data. It is real revenue,
but it is reported by the prime under the prime’s award key, so it
cannot sit on this organization’s award rows. It is aggregated per
organization-year in `subawards_in`:

``` r
p$subawards_in
#>           org_id  year subaward_in_amount n_subawards_in
#>           <char> <int>              <num>          <int>
#>  1: CFFMYPABYAG3  2024         13678698.9              7
#>  2: CFFMYPABYAG3  2025         46245625.4              3
#>  3: CFFMYPABYAG3  2023           186411.2              1
#>  4: CFFMYPABYAG3  2016            30000.0              1
#>  5: H7LMD1ANJNN4  2023           819166.0              5
#>  6: H7LMD1ANJNN4  2021           232707.0              1
#>  7: H7LMD1ANJNN4  2022           906776.0              4
#>  8: H7LMD1ANJNN4  2024          1665812.0              5
#>  9: H7LMD1ANJNN4  2025          1680678.0              4
#> 10: H7LMD1ANJNN4  2020           575000.0              1
```

The sample makes the stakes concrete: compare prime obligations with
inbound subawards for the first organization —

``` r
merge(
  p$panel[, .(prime_net = sum(obligation_net)), by = org_id],
  p$subawards_in[, .(inbound = sum(subaward_in_amount)), by = org_id],
  all.x = TRUE
)
#> Key: <org_id>
#>          org_id prime_net  inbound
#>          <char>     <num>    <num>
#> 1: CFFMYPABYAG3    222421 60140736
#> 2: FG8QB99NF8K3   2948745       NA
#> 3: H7LMD1ANJNN4  22212225  5880139
```

`CFFMYPABYAG3` shows roughly \$220k of prime obligations against \$60M
received as a subrecipient. Judged on prime awards alone, this
organization barely exists as a federal recipient; nearly all of its
federal money arrives as pass-through from other primes’ awards.

## Rolling up: `us_org_year()` and `us_rollup()`

Most analyses do not need award detail.
[`us_org_year()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_org_year.md)
collapses the panel to organization × year (optionally by an extra panel
column):

``` r
us_org_year(p)[1:5]
#> Key: <org_id, year>
#>          org_id  year n_awards n_transactions obligation_positive obligation_negative
#>          <char> <int>    <num>          <num>               <num>               <num>
#> 1: CFFMYPABYAG3  2008        1              1               27370                   0
#> 2: CFFMYPABYAG3  2009        1              4               27370              -10000
#> 3: CFFMYPABYAG3  2010        1              2               15000                   0
#> 4: CFFMYPABYAG3  2011        1              2               27370                   0
#> 5: CFFMYPABYAG3  2012        1              2               27370                   0
#> 6 variables not shown: [obligation_net <num>, loan_face_value <num>, subaward_out_amount <num>, net_revenue <num>, subaward_in_amount <num>, n_subawards_in <num>]
us_org_year(p, by = "award_family")[1:5]
#>          org_id  year award_family n_awards n_transactions obligation_positive
#>          <char> <int>       <char>    <int>          <int>               <num>
#> 1: CFFMYPABYAG3  2008     contract        1              1               27370
#> 2: CFFMYPABYAG3  2009     contract        1              4               27370
#> 3: CFFMYPABYAG3  2010     contract        1              2               15000
#> 4: CFFMYPABYAG3  2011     contract        1              2               27370
#> 5: CFFMYPABYAG3  2012     contract        1              2               27370
#> 5 variables not shown: [obligation_negative <num>, obligation_net <num>, loan_face_value <num>, subaward_out_amount <num>, net_revenue <num>]
```

[`us_rollup()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_rollup.md)
is the general aggregator: each dimension is a toggle, and it folds the
inbound table in so both directions of money end up in one row.

``` r
us_rollup(p)                                 # one row per org, all years
#> Key: <org_id>
#>          org_id n_awards n_transactions obligation_positive obligation_negative
#>          <char>    <int>          <int>               <num>               <num>
#> 1: CFFMYPABYAG3        5             36              305673           -83252.00
#> 2: FG8QB99NF8K3        7             36             2950487            -1741.71
#> 3: H7LMD1ANJNN4        6             48            22523224          -310999.00
#> 8 variables not shown: [obligation_net <num>, loan_face_value <num>, subaward_out_amount <num>, n_subawards_out <int>, subaward_in_amount <num>, n_subawards_in <int>, net_revenue <num>, total_net <num>]
us_rollup(p, org_id = FALSE, year = TRUE)[1:5]  # sector-wide trend
#> Key: <year>
#>     year n_awards n_transactions obligation_positive obligation_negative obligation_net
#>    <int>    <int>          <int>               <num>               <num>          <num>
#> 1:  2008        3              3               27370                   0          27370
#> 2:  2009        1              4               27370              -10000          17370
#> 3:  2010        3              5              297621                   0         297621
#> 4:  2011        5              7              418321                   0         418321
#> 5:  2012        5              9             1846021                   0        1846021
#> 7 variables not shown: [loan_face_value <num>, subaward_out_amount <num>, n_subawards_out <int>, subaward_in_amount <num>, n_subawards_in <int>, net_revenue <num>, total_net <num>]
```

It adds one column the panel does not have:

    total_net = obligation_net + subaward_in_amount − subaward_out_amount

— the fullest single measure of net federal dollars flowing to the
group: prime money kept, plus money received as a subrecipient. Use
`net_revenue` when the question is “what did this organization’s *prime
awards* net?”, and `total_net` when it is “how many federal dollars
ended up here?”.

`state = TRUE` groups by the award’s recipient state (inbound flows,
which are organization-level, are assigned to the organization’s
dominant state):

``` r
us_rollup(p, org_id = FALSE, state = TRUE)[, .(state, n_awards, obligation_net, total_net)]
#> Key: <state>
#>     state n_awards obligation_net total_net
#>    <char>    <int>          <num>     <num>
#> 1:     CA        1              0         0
#> 2:     HI        4         222421  60363157
#> 3:     PA        6       22212225  28092364
#> 4:     VA        7        2948745   2948745
```

## Constant dollars: `us_adjust_inflation()`

A panel spanning 2008–2025 mixes dollar vintages.
[`us_adjust_inflation()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_adjust_inflation.md)
restates every dollar column into the dollars of a target year, using
the bundled CPI-U annual averages (or any `year`/`index` table you
supply — only ratios are used, so the base year does not matter):

``` r
tail(us_price_index(), 3)
#>     year   index
#>    <int>   <num>
#> 1:  2023 304.702
#> 2:  2024 313.689
#> 3:  2025 322.561

trend   <- us_rollup(p, org_id = FALSE, year = TRUE)
trend25 <- us_adjust_inflation(trend, target_year = 2025)
#> Restated 8 columns in 2025 dollars.

cbind(trend[year %in% 2008:2010, .(year, nominal = obligation_net)],
      trend25[year %in% 2008:2010, .(real_2025 = obligation_net)])
#> Key: <year>
#>     year nominal real_2025
#>    <int>   <num>     <num>
#> 1:  2008   27370  41004.98
#> 2:  2009   17370  26116.17
#> 3:  2010  297621 440258.13
```

The adjustment records what it did:

``` r
str(attr(trend25, "usaspend_inflation"))
#> List of 4
#>  $ target_year: int 2025
#>  $ cols       : chr [1:8] "obligation_positive" "obligation_negative" "obligation_net" "loan_face_value" ...
#>  $ index_years: int [1:2] 2007 2025
#>  $ source     : chr "bundled CPI-U annual averages (BLS)"
```

Order matters: adjust **before** collapsing across years. A rollup that
has already summed 2008 dollars with 2024 dollars has no `year` column
left to deflate by, and the function refuses rather than guessing:

``` r
us_adjust_inflation(us_rollup(p))   # collapsed across years -- refuses
#> Error in `us_adjust_inflation()`:
#> ! `x` has no year column.
#> ℹ A rollup collapsed across years mixes dollar vintages -- adjust the panel first, then
#>   roll up.
```

You can also pass the whole `usaspend_panel`, which adjusts `panel` and
`subawards_in` together and notes the target year in `meta`.

## Checking a build

Every rule that produced these numbers is a choice, and choices need
checks.
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md)
tests each award’s summed transactions against the lifetime total
USAspending computes independently, and
[`us_audit()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_audit.md)
runs the structural invariants (no duplicate transactions, unique grain,
no award attributed to two organizations). Run both on every rebuild.
