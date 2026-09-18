# Roll the panel up across grouping dimensions

Aggregates every award in the panel to the chosen grain, carrying both
directions of money: prime obligations, outflows (pass-through subawards
paid), and inflows (subawards received, which never appear in prime
data).

## Usage

``` r
us_rollup(panel, org_id = TRUE, year = NULL, state = NULL)
```

## Arguments

- panel:

  A `usaspend_panel` from
  [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md).

- org_id:

  Group by organization. Default `TRUE`.

- year:

  Group by year. Default `NULL` (aggregate across years); `TRUE`
  produces a trend tabulation.

- state:

  Group by recipient state. Default `NULL`.

## Value

A `data.table` at the requested grain, sorted by the grouping keys.

## Details

Each dimension is a toggle: `TRUE` groups by it, `NULL` (or `FALSE`)
aggregates over it.

- `org_id = TRUE, year = NULL`:

  (default) one row per organization, totalled across all years.

- `year = TRUE`:

  a trend tabulation – org x year, or year alone if `org_id = FALSE`.

- `state = TRUE`:

  groups prime flows by the award's registered recipient state. Inbound
  subawards are organization-level, so they are assigned to the
  organization's dominant state (largest share of absolute net
  obligations).

All three `FALSE`/`NULL` returns a single grand-total row.

## Columns

Counts (`n_awards`, `n_transactions`, `n_subawards_out`,
`n_subawards_in`) and dollars: gross positive / negative / net
obligations, loan face value, `subaward_out_amount`,
`subaward_in_amount`, `net_revenue`
(`obligation_net - subaward_out_amount`) and `total_net`
(`obligation_net + subaward_in_amount - subaward_out_amount`) – the
fullest single measure of net federal dollars flowing to the group.

Inflows come from the panel's organization-level `subawards_in` table,
not from the panel rows (panel rows carry inbound amounts only in the
rare case where an organization is prime and subawardee on the same
award).

## Examples

``` r
p <- us_panel(us_sample_extract())
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
#> Normalized 32 -> 32 subaward rows (0 duplicates removed).
#> • in=32
#> Warning: No outbound subawards present -- pass-through cannot be netted out.
#> ℹ Bulk downloads match on the subawardee. Use `us_fetch_subawards_out()` to
#>   fetch pass-through by prime award.
us_rollup(p)                             # one row per org, all years
#> Key: <org_id>
#>          org_id n_awards n_transactions obligation_positive obligation_negative
#>          <char>    <int>          <int>               <num>               <num>
#> 1: CFFMYPABYAG3        5             36              305673           -83252.00
#> 2: FG8QB99NF8K3        7             36             2950487            -1741.71
#> 3: H7LMD1ANJNN4        6             48            22523224          -310999.00
#>    obligation_net loan_face_value subaward_out_amount n_subawards_out
#>             <num>           <num>               <num>           <int>
#> 1:         222421               0                   0               0
#> 2:        2948745               0                   0               0
#> 3:       22212225               0                   0               0
#>    subaward_in_amount n_subawards_in net_revenue total_net
#>                 <num>          <int>       <num>     <num>
#> 1:           60140736             12      222421  60363157
#> 2:                  0              0     2948745   2948745
#> 3:            5880139             20    22212225  28092364
us_rollup(p, year = TRUE)                # org x year trend
#> Key: <org_id, year>
#>           org_id  year n_awards n_transactions obligation_positive
#>           <char> <int>    <int>          <int>               <num>
#>  1: CFFMYPABYAG3  2008        1              1               27370
#>  2: CFFMYPABYAG3  2009        1              4               27370
#>  3: CFFMYPABYAG3  2010        1              2               15000
#>  4: CFFMYPABYAG3  2011        1              2               27370
#>  5: CFFMYPABYAG3  2012        1              2               27370
#>  6: CFFMYPABYAG3  2013        1              4                7000
#>  7: CFFMYPABYAG3  2014        1              4               47740
#>  8: CFFMYPABYAG3  2015        1              2               27370
#>  9: CFFMYPABYAG3  2016        1              4               28758
#> 10: CFFMYPABYAG3  2017        1              2                1277
#> 11: CFFMYPABYAG3  2018        1              3               54842
#> 12: CFFMYPABYAG3  2019        2              2                   0
#> 13: CFFMYPABYAG3  2020        1              1                   0
#> 14: CFFMYPABYAG3  2022        1              1                   0
#> 15: CFFMYPABYAG3  2023        1              1               14206
#> 16: CFFMYPABYAG3  2024        1              1                   0
#> 17: CFFMYPABYAG3  2025        0              0                   0
#> 18: FG8QB99NF8K3  2008        2              2                   0
#> 19: FG8QB99NF8K3  2010        2              3              282621
#> 20: FG8QB99NF8K3  2011        4              5              390951
#> 21: FG8QB99NF8K3  2012        4              7             1818651
#> 22: FG8QB99NF8K3  2013        4              5                   0
#> 23: FG8QB99NF8K3  2014        4              4              293531
#> 24: FG8QB99NF8K3  2015        2              2                   0
#> 25: FG8QB99NF8K3  2016        1              1               28978
#> 26: FG8QB99NF8K3  2017        1              1              135755
#> 27: FG8QB99NF8K3  2019        5              6                   0
#> 28: H7LMD1ANJNN4  2017        1              1              324763
#> 29: H7LMD1ANJNN4  2018        1              3             1934698
#> 30: H7LMD1ANJNN4  2019        2              3             2939142
#> 31: H7LMD1ANJNN4  2020        2              2             2335590
#> 32: H7LMD1ANJNN4  2021        2              3             2327120
#> 33: H7LMD1ANJNN4  2022        4             16             5467555
#> 34: H7LMD1ANJNN4  2023        2              5             2063893
#> 35: H7LMD1ANJNN4  2024        4              9             4761584
#> 36: H7LMD1ANJNN4  2025        3              6              368879
#>           org_id  year n_awards n_transactions obligation_positive
#>           <char> <int>    <int>          <int>               <num>
#>     obligation_negative obligation_net loan_face_value subaward_out_amount
#>                   <num>          <num>           <num>               <num>
#>  1:                0.00       27370.00               0                   0
#>  2:           -10000.00       17370.00               0                   0
#>  3:                0.00       15000.00               0                   0
#>  4:                0.00       27370.00               0                   0
#>  5:                0.00       27370.00               0                   0
#>  6:           -20284.00      -13284.00               0                   0
#>  7:                0.00       47740.00               0                   0
#>  8:                0.00       27370.00               0                   0
#>  9:                0.00       28758.00               0                   0
#> 10:                0.00        1277.00               0                   0
#> 11:                0.00       54842.00               0                   0
#> 12:           -52968.00      -52968.00               0                   0
#> 13:                0.00           0.00               0                   0
#> 14:                0.00           0.00               0                   0
#> 15:                0.00       14206.00               0                   0
#> 16:                0.00           0.00               0                   0
#> 17:                0.00           0.00               0                   0
#> 18:                0.00           0.00               0                   0
#> 19:                0.00      282621.00               0                   0
#> 20:                0.00      390951.00               0                   0
#> 21:                0.00     1818651.00               0                   0
#> 22:                0.00           0.00               0                   0
#> 23:                0.00      293531.00               0                   0
#> 24:                0.00           0.00               0                   0
#> 25:                0.00       28978.00               0                   0
#> 26:                0.00      135755.00               0                   0
#> 27:            -1741.71       -1741.71               0                   0
#> 28:                0.00      324763.00               0                   0
#> 29:                0.00     1934698.00               0                   0
#> 30:                0.00     2939142.00               0                   0
#> 31:                0.00     2335590.00               0                   0
#> 32:                0.00     2327120.00               0                   0
#> 33:                0.00     5467555.00               0                   0
#> 34:                0.00     2063893.00               0                   0
#> 35:          -310999.00     4450585.00               0                   0
#> 36:                0.00      368879.00               0                   0
#>     obligation_negative obligation_net loan_face_value subaward_out_amount
#>                   <num>          <num>           <num>               <num>
#>     n_subawards_out subaward_in_amount n_subawards_in net_revenue   total_net
#>               <int>              <num>          <int>       <num>       <num>
#>  1:               0                0.0              0    27370.00    27370.00
#>  2:               0                0.0              0    17370.00    17370.00
#>  3:               0                0.0              0    15000.00    15000.00
#>  4:               0                0.0              0    27370.00    27370.00
#>  5:               0                0.0              0    27370.00    27370.00
#>  6:               0                0.0              0   -13284.00   -13284.00
#>  7:               0                0.0              0    47740.00    47740.00
#>  8:               0                0.0              0    27370.00    27370.00
#>  9:               0            30000.0              1    28758.00    58758.00
#> 10:               0                0.0              0     1277.00     1277.00
#> 11:               0                0.0              0    54842.00    54842.00
#> 12:               0                0.0              0   -52968.00   -52968.00
#> 13:               0                0.0              0        0.00        0.00
#> 14:               0                0.0              0        0.00        0.00
#> 15:               0           186411.2              1    14206.00   200617.17
#> 16:               0         13678698.9              7        0.00 13678698.90
#> 17:               0         46245625.4              3        0.00 46245625.43
#> 18:               0                0.0              0        0.00        0.00
#> 19:               0                0.0              0   282621.00   282621.00
#> 20:               0                0.0              0   390951.00   390951.00
#> 21:               0                0.0              0  1818651.00  1818651.00
#> 22:               0                0.0              0        0.00        0.00
#> 23:               0                0.0              0   293531.00   293531.00
#> 24:               0                0.0              0        0.00        0.00
#> 25:               0                0.0              0    28978.00    28978.00
#> 26:               0                0.0              0   135755.00   135755.00
#> 27:               0                0.0              0    -1741.71    -1741.71
#> 28:               0                0.0              0   324763.00   324763.00
#> 29:               0                0.0              0  1934698.00  1934698.00
#> 30:               0                0.0              0  2939142.00  2939142.00
#> 31:               0           575000.0              1  2335590.00  2910590.00
#> 32:               0           232707.0              1  2327120.00  2559827.00
#> 33:               0           906776.0              4  5467555.00  6374331.00
#> 34:               0           819166.0              5  2063893.00  2883059.00
#> 35:               0          1665812.0              5  4450585.00  6116397.00
#> 36:               0          1680678.0              4   368879.00  2049557.00
#>     n_subawards_out subaward_in_amount n_subawards_in net_revenue   total_net
#>               <int>              <num>          <int>       <num>       <num>
us_rollup(p, org_id = FALSE, year = TRUE)  # sector-wide trend
#> Key: <year>
#>      year n_awards n_transactions obligation_positive obligation_negative
#>     <int>    <int>          <int>               <num>               <num>
#>  1:  2008        3              3               27370                0.00
#>  2:  2009        1              4               27370           -10000.00
#>  3:  2010        3              5              297621                0.00
#>  4:  2011        5              7              418321                0.00
#>  5:  2012        5              9             1846021                0.00
#>  6:  2013        5              9                7000           -20284.00
#>  7:  2014        5              8              341271                0.00
#>  8:  2015        3              4               27370                0.00
#>  9:  2016        2              5               57736                0.00
#> 10:  2017        3              4              461795                0.00
#> 11:  2018        2              6             1989540                0.00
#> 12:  2019        9             11             2939142           -54709.71
#> 13:  2020        3              3             2335590                0.00
#> 14:  2021        2              3             2327120                0.00
#> 15:  2022        5             17             5467555                0.00
#> 16:  2023        3              6             2078099                0.00
#> 17:  2024        5             10             4761584          -310999.00
#> 18:  2025        3              6              368879                0.00
#>     obligation_net loan_face_value subaward_out_amount n_subawards_out
#>              <num>           <num>               <num>           <int>
#>  1:          27370               0                   0               0
#>  2:          17370               0                   0               0
#>  3:         297621               0                   0               0
#>  4:         418321               0                   0               0
#>  5:        1846021               0                   0               0
#>  6:         -13284               0                   0               0
#>  7:         341271               0                   0               0
#>  8:          27370               0                   0               0
#>  9:          57736               0                   0               0
#> 10:         461795               0                   0               0
#> 11:        1989540               0                   0               0
#> 12:        2884432               0                   0               0
#> 13:        2335590               0                   0               0
#> 14:        2327120               0                   0               0
#> 15:        5467555               0                   0               0
#> 16:        2078099               0                   0               0
#> 17:        4450585               0                   0               0
#> 18:         368879               0                   0               0
#>     subaward_in_amount n_subawards_in net_revenue total_net
#>                  <num>          <int>       <num>     <num>
#>  1:                  0              0       27370     27370
#>  2:                  0              0       17370     17370
#>  3:                  0              0      297621    297621
#>  4:                  0              0      418321    418321
#>  5:                  0              0     1846021   1846021
#>  6:                  0              0      -13284    -13284
#>  7:                  0              0      341271    341271
#>  8:                  0              0       27370     27370
#>  9:              30000              1       57736     87736
#> 10:                  0              0      461795    461795
#> 11:                  0              0     1989540   1989540
#> 12:                  0              0     2884432   2884432
#> 13:             575000              1     2335590   2910590
#> 14:             232707              1     2327120   2559827
#> 15:             906776              4     5467555   6374331
#> 16:            1005577              6     2078099   3083676
#> 17:           15344511             12     4450585  19795096
#> 18:           47926303              7      368879  48295182
us_rollup(p, state = TRUE, org_id = FALSE) # state totals
#> Key: <state>
#>     state n_awards n_transactions obligation_positive obligation_negative
#>    <char>    <int>          <int>               <num>               <num>
#> 1:     CA        1              1                   0                0.00
#> 2:     HI        4             35              305673           -83252.00
#> 3:     PA        6             48            22523224          -310999.00
#> 4:     VA        7             36             2950487            -1741.71
#>    obligation_net loan_face_value subaward_out_amount n_subawards_out
#>             <num>           <num>               <num>           <int>
#> 1:              0               0                   0               0
#> 2:         222421               0                   0               0
#> 3:       22212225               0                   0               0
#> 4:        2948745               0                   0               0
#>    subaward_in_amount n_subawards_in net_revenue total_net
#>                 <num>          <int>       <num>     <num>
#> 1:                  0              0           0         0
#> 2:           60140736             12      222421  60363157
#> 3:            5880139             20    22212225  28092364
#> 4:                  0              0     2948745   2948745
```
