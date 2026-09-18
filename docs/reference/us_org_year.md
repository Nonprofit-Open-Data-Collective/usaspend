# Roll the award panel up to organization x year

Convenience aggregation over
[`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
output for analyses that do not need award detail. Includes inbound
subaward revenue, which exists only at organization level.

## Usage

``` r
us_org_year(panel, by = NULL)
```

## Arguments

- panel:

  A `usaspend_panel`.

- by:

  Extra grouping columns from the panel, e.g. `"award_family"` or
  `"awarding_agency_name"`.

## Value

A `data.table` at organization x year (x `by`) grain.

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
us_org_year(p)
#> Key: <org_id, year>
#>           org_id  year n_awards n_transactions obligation_positive
#>           <char> <int>    <num>          <num>               <num>
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
#>           <char> <int>    <num>          <num>               <num>
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
#>     net_revenue subaward_in_amount n_subawards_in
#>           <num>              <num>          <num>
#>  1:    27370.00                0.0              0
#>  2:    17370.00                0.0              0
#>  3:    15000.00                0.0              0
#>  4:    27370.00                0.0              0
#>  5:    27370.00                0.0              0
#>  6:   -13284.00                0.0              0
#>  7:    47740.00                0.0              0
#>  8:    27370.00                0.0              0
#>  9:    28758.00            30000.0              1
#> 10:     1277.00                0.0              0
#> 11:    54842.00                0.0              0
#> 12:   -52968.00                0.0              0
#> 13:        0.00                0.0              0
#> 14:        0.00                0.0              0
#> 15:    14206.00           186411.2              1
#> 16:        0.00         13678698.9              7
#> 17:        0.00         46245625.4              3
#> 18:        0.00                0.0              0
#> 19:   282621.00                0.0              0
#> 20:   390951.00                0.0              0
#> 21:  1818651.00                0.0              0
#> 22:        0.00                0.0              0
#> 23:   293531.00                0.0              0
#> 24:        0.00                0.0              0
#> 25:    28978.00                0.0              0
#> 26:   135755.00                0.0              0
#> 27:    -1741.71                0.0              0
#> 28:   324763.00                0.0              0
#> 29:  1934698.00                0.0              0
#> 30:  2939142.00                0.0              0
#> 31:  2335590.00           575000.0              1
#> 32:  2327120.00           232707.0              1
#> 33:  5467555.00           906776.0              4
#> 34:  2063893.00           819166.0              5
#> 35:  4450585.00          1665812.0              5
#> 36:   368879.00          1680678.0              4
#>     net_revenue subaward_in_amount n_subawards_in
#>           <num>              <num>          <num>
us_org_year(p, by = "award_family")
#>           org_id  year award_family n_awards n_transactions obligation_positive
#>           <char> <int>       <char>    <int>          <int>               <num>
#>  1: CFFMYPABYAG3  2008     contract        1              1               27370
#>  2: CFFMYPABYAG3  2009     contract        1              4               27370
#>  3: CFFMYPABYAG3  2010     contract        1              2               15000
#>  4: CFFMYPABYAG3  2011     contract        1              2               27370
#>  5: CFFMYPABYAG3  2012     contract        1              2               27370
#>  6: CFFMYPABYAG3  2013     contract        1              4                7000
#>  7: CFFMYPABYAG3  2014     contract        1              4               47740
#>  8: CFFMYPABYAG3  2015     contract        1              2               27370
#>  9: CFFMYPABYAG3  2016     contract        1              4               28758
#> 10: CFFMYPABYAG3  2017     contract        1              2                1277
#> 11: CFFMYPABYAG3  2018     contract        1              3               54842
#> 12: CFFMYPABYAG3  2019     contract        1              1                   0
#> 13: CFFMYPABYAG3  2019          idv        1              1                   0
#> 14: CFFMYPABYAG3  2020          idv        1              1                   0
#> 15: CFFMYPABYAG3  2022          idv        1              1                   0
#> 16: CFFMYPABYAG3  2023     contract        1              1               14206
#> 17: CFFMYPABYAG3  2024          idv        1              1                   0
#> 18: FG8QB99NF8K3  2008     contract        1              1                   0
#> 19: FG8QB99NF8K3  2008          idv        1              1                   0
#> 20: FG8QB99NF8K3  2010     contract        1              2              282621
#> 21: FG8QB99NF8K3  2010          idv        1              1                   0
#> 22: FG8QB99NF8K3  2011     contract        3              4              390951
#> 23: FG8QB99NF8K3  2011          idv        1              1                   0
#> 24: FG8QB99NF8K3  2012     contract        3              6             1818651
#> 25: FG8QB99NF8K3  2012          idv        1              1                   0
#> 26: FG8QB99NF8K3  2013     contract        3              4                   0
#> 27: FG8QB99NF8K3  2013          idv        1              1                   0
#> 28: FG8QB99NF8K3  2014     contract        3              3              293531
#> 29: FG8QB99NF8K3  2014          idv        1              1                   0
#> 30: FG8QB99NF8K3  2015     contract        2              2                   0
#> 31: FG8QB99NF8K3  2016     contract        1              1               28978
#> 32: FG8QB99NF8K3  2017     contract        1              1              135755
#> 33: FG8QB99NF8K3  2019     contract        4              5                   0
#> 34: FG8QB99NF8K3  2019          idv        1              1                   0
#> 35: H7LMD1ANJNN4  2017     contract        1              1              324763
#> 36: H7LMD1ANJNN4  2018     contract        1              3             1934698
#> 37: H7LMD1ANJNN4  2019     contract        2              3             2939142
#> 38: H7LMD1ANJNN4  2020     contract        2              2             2335590
#> 39: H7LMD1ANJNN4  2021     contract        2              3             2327120
#> 40: H7LMD1ANJNN4  2022     contract        3             14             5157900
#> 41: H7LMD1ANJNN4  2022        grant        1              2              309655
#> 42: H7LMD1ANJNN4  2023     contract        2              5             2063893
#> 43: H7LMD1ANJNN4  2024     contract        2              5             4071239
#> 44: H7LMD1ANJNN4  2024        grant        2              4              690345
#> 45: H7LMD1ANJNN4  2025     contract        2              3               68879
#> 46: H7LMD1ANJNN4  2025        grant        1              3              300000
#>           org_id  year award_family n_awards n_transactions obligation_positive
#>           <char> <int>       <char>    <int>          <int>               <num>
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
#> 15:                0.00           0.00               0                   0
#> 16:                0.00       14206.00               0                   0
#> 17:                0.00           0.00               0                   0
#> 18:                0.00           0.00               0                   0
#> 19:                0.00           0.00               0                   0
#> 20:                0.00      282621.00               0                   0
#> 21:                0.00           0.00               0                   0
#> 22:                0.00      390951.00               0                   0
#> 23:                0.00           0.00               0                   0
#> 24:                0.00     1818651.00               0                   0
#> 25:                0.00           0.00               0                   0
#> 26:                0.00           0.00               0                   0
#> 27:                0.00           0.00               0                   0
#> 28:                0.00      293531.00               0                   0
#> 29:                0.00           0.00               0                   0
#> 30:                0.00           0.00               0                   0
#> 31:                0.00       28978.00               0                   0
#> 32:                0.00      135755.00               0                   0
#> 33:            -1741.71       -1741.71               0                   0
#> 34:                0.00           0.00               0                   0
#> 35:                0.00      324763.00               0                   0
#> 36:                0.00     1934698.00               0                   0
#> 37:                0.00     2939142.00               0                   0
#> 38:                0.00     2335590.00               0                   0
#> 39:                0.00     2327120.00               0                   0
#> 40:                0.00     5157900.00               0                   0
#> 41:                0.00      309655.00               0                   0
#> 42:                0.00     2063893.00               0                   0
#> 43:                0.00     4071239.00               0                   0
#> 44:          -310999.00      379346.00               0                   0
#> 45:                0.00       68879.00               0                   0
#> 46:                0.00      300000.00               0                   0
#>     obligation_negative obligation_net loan_face_value subaward_out_amount
#>                   <num>          <num>           <num>               <num>
#>     net_revenue
#>           <num>
#>  1:    27370.00
#>  2:    17370.00
#>  3:    15000.00
#>  4:    27370.00
#>  5:    27370.00
#>  6:   -13284.00
#>  7:    47740.00
#>  8:    27370.00
#>  9:    28758.00
#> 10:     1277.00
#> 11:    54842.00
#> 12:   -52968.00
#> 13:        0.00
#> 14:        0.00
#> 15:        0.00
#> 16:    14206.00
#> 17:        0.00
#> 18:        0.00
#> 19:        0.00
#> 20:   282621.00
#> 21:        0.00
#> 22:   390951.00
#> 23:        0.00
#> 24:  1818651.00
#> 25:        0.00
#> 26:        0.00
#> 27:        0.00
#> 28:   293531.00
#> 29:        0.00
#> 30:        0.00
#> 31:    28978.00
#> 32:   135755.00
#> 33:    -1741.71
#> 34:        0.00
#> 35:   324763.00
#> 36:  1934698.00
#> 37:  2939142.00
#> 38:  2335590.00
#> 39:  2327120.00
#> 40:  5157900.00
#> 41:   309655.00
#> 42:  2063893.00
#> 43:  4071239.00
#> 44:   379346.00
#> 45:    68879.00
#> 46:   300000.00
#>     net_revenue
#>           <num>
```
