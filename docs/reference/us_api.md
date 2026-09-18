# Call the USAspending API

Low-level access, exported so that endpoints this package does not wrap
are still reachable without hand-rolling a client.

## Usage

``` r
us_api(path, body = NULL, query = NULL)
```

## Arguments

- path:

  Endpoint path below `/api/v2`, e.g.
  `"search/spending_by_award_count/"`.

- body:

  Named list sent as JSON. If `NULL`, a GET is performed.

- query:

  Named list of query-string parameters (GET only).

## Value

The parsed JSON response as a list.

## Examples

``` r
if (FALSE) { # \dontrun{
us_api("search/spending_by_award_count/", body = list(
  filters = list(recipient_search_text = I("CFFMYPABYAG3"))
))
} # }
```
