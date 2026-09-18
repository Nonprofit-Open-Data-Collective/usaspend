# Aggregate subawards by year

Aggregate subawards by year

## Usage

``` r
us_subaward_by_year(
  subawards,
  period = c("calendar", "fiscal"),
  direction = c("out", "in")
)
```

## Arguments

- subawards:

  Normalized subawards from
  [`us_normalize_subawards()`](https://nonprofit-open-data-collective.github.io/usaspend/reference/us_normalize_subawards.md).

- period:

  `"calendar"` or `"fiscal"`.

- direction:

  Which flow to aggregate: `"out"` (pass-through paid by the
  organization as prime) or `"in"` (subawards received).

## Value

A `data.table` of `prime_award_key`, `year`, amount and count. For
`direction = "in"` the key is the *prime's* award; join to the panel
through the subawardee UEI instead.
