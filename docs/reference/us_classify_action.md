# Classify transaction action types

Maps an action-type code to an economic class. Because the codes collide
across families, `award_group` is required, not optional.

## Usage

``` r
us_classify_action(action_type_code, award_group)
```

## Arguments

- action_type_code:

  Character vector of action type codes.

- award_group:

  Character vector, `"contract"` or `"assistance"`, recycled to the
  length of `action_type_code`.

## Value

A `data.table` with `award_group`, `action_type_code`,
`action_type_label`, `action_class`.

## Details

Classes:

- origination:

  First obligation on a new award.

- continuation:

  A funded continuation or exercised option – new money on an existing
  award.

- revision:

  An in-scope change that may add or remove money.

- funding_only:

  An action whose sole purpose is to move money.

- adjustment:

  A correction to an award already completed.

- termination:

  Termination or cancellation; typically de-obligating.

- closeout:

  Administrative closeout; typically zero-dollar.

- administrative:

  Name, address, PIID and transfer changes; should be zero-dollar, and a
  non-zero one is worth flagging.

- unclassified:

  Code missing or unrecognized. Base contract actions legitimately have
  a blank action type, so this is not by itself an error.

`action_class` describes *intent*, not sign. A continuation can carry a
negative obligation and a termination can carry zero. Never infer a
de-obligation from the class – use the sign of the amount.

## Examples

``` r
# the same code means different things in the two families
us_classify_action(c("B", "B"), c("assistance", "contract"))
#>    award_group action_type_code                   action_type_label
#>         <char>           <char>                              <char>
#> 1:  assistance                B                        Continuation
#> 2:    contract                B Supplemental Agreement Within Scope
#>    action_class
#>          <char>
#> 1: continuation
#> 2:     revision
```
