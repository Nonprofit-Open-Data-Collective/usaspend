# Get started: UEIs in, panel out

usaspend turns a list of SAM.gov Unique Entity Identifiers (UEIs) into a
clean **organization × award × year** panel of net federal award
activity from USAspending.gov. The whole path is three calls:

``` r
library(usaspend)
ex <- us_extract(c("CFFMYPABYAG3", "FG8QB99NF8K3"),   # your UEIs
                 years = 2008:2025, subawards = "both")
p  <- us_panel(ex)                                     # normalize + net
us_rollup(p, year = TRUE)                              # analyze
```

Everything below runs offline, on the bundled sample extract — a real
three-UEI pull kept verbatim.

``` r
library(usaspend)
ex <- us_sample_extract()
p  <- us_panel(ex)
p
```

## The one idea everything else depends on

**A federal award is not a payment. It is a running ledger of promises,
written in modifications.** Here is a real award from the sample — eight
actions across four calendar years, three of them zero-dollar:

``` r
p$transactions[award_key == "ASST_NON_HDTRA12310001_097",
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

The panel books each action’s dollars to the year it happened:

``` r
p$panel[award_key == "ASST_NON_HDTRA12310001_097",
  .(year, n_transactions, obligation_net)]
#>     year n_transactions obligation_net
#>    <int>          <int>          <num>
#> 1:  2022              2         309655
#> 2:  2024              3         690345
#> 3:  2025              3         300000
```

And the check that the whole pipeline is right: the years must sum back
to the award’s reported lifetime total, which USAspending computes in a
different system than the transactions —

``` r
sum(p$panel[award_key == "ASST_NON_HDTRA12310001_097"]$obligation_net)
#> [1] 1300000
p$awards[award_key == "ASST_NON_HDTRA12310001_097"]$award_total_obligated
#> NULL
```

That identity, checked across every award by
[`us_reconcile()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_reconcile.md),
is what makes the panel trustworthy rather than merely plausible. A
reader who has internalized the ledger idea — actions, signs, years, and
a lifetime total to reconcile against — can predict most of the
package’s design.

## Where everything is explained

| vignette | what it covers |
|----|----|
| [`vignette("data-model")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/data-model.md) | how USAspending is structured: transactions, awards, subawards — and why the panel can only be built from transactions |
| [`vignette("award-types")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/award-types.md) | grants, contracts, IDVs, loans, direct payments — and which of them are revenue |
| [`vignette("acquisition")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/acquisition.md) | the two ways to fetch: API jobs vs annual archives, measured |
| [`vignette("accounting")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/accounting.md) | the reconciliation rules: de-duplication, corrections, de-obligations, and which year a claw-back belongs to |
| [`vignette("subawards")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/subawards.md) | pass-through and subrecipient revenue: what FSRS sees, and direction |
| [`vignette("panel")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/panel.md) | reading the output; rollups; inflation adjustment |
| [`vignette("reconciliation")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/reconciliation.md) | the checks: the lifetime identity, and how to read a break |
| [`vignette("structure")`](https://nonprofit-open-data-collective.github.io/usaspend/articles/structure.md) | package architecture and the function-call workflow |
