# Build a signed accounting ledger

Adds the accounting interpretation to a normalized transaction ledger:
each row's bookable amount, its sign class, and whether it belongs in
the revenue measure at all.

## Usage

``` r
us_ledger(transactions, measure = c("obligation", "pragmatic"))
```

## Arguments

- transactions:

  A normalized ledger from
  [`us_normalize_transactions()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_transactions.md).

- measure:

  Money measure, see
  [`us_money_column()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_money_column.md).

## Value

The ledger with `amount` (the bookable amount under `measure`),
`amount_sign` (`"positive"`, `"negative"`, `"zero"`), and `in_revenue`.

## Rules, as measured on the pilot

- **The sign is the truth.** 25,993 pilot transactions (8.6%) carry a
  negative obligation, and they arrive under every action class – 6,344
  assistance CONTINUATIONs are negative, as are 3,276 contract FUNDING
  ONLY actions. The action class describes intent; the sign describes
  money.

- **Loans are excluded from revenue.** Direct loans (type 07) carry
  `federal_action_obligation = 0` on all 6,496 pilot rows while
  `face_value_of_loan` sums to \$626bn. Face value is a liability, not
  income; the obligation column already handles this correctly by being
  zero, and the face value and subsidy cost travel in their own columns.

- **Direct payments (06, 10) are includable but separable.** In the
  pilot these are real entity-level payments (e.g. campus-based student
  aid). They stay in the ledger with `in_revenue = TRUE` but keep their
  family so
  [`us_panel()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_panel.md)
  output can be filtered.

## Examples

``` r
tx <- us_normalize_transactions(us_sample_extract()$transactions)
#> Normalized 120 -> 120 transactions.
#> • 0 duplicates, 0 deleted, 0 aggregate records
#> • 8 rows flagged
lg <- us_ledger(tx)
lg[, .(n = .N, total = sum(amount)), by = amount_sign]
#>    amount_sign     n      total
#>         <char> <int>      <num>
#> 1:    positive    54 25779384.0
#> 2:        zero    59        0.0
#> 3:    negative     7  -395992.7
```
