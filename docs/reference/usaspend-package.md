# usaspend: Normalized Federal Award Panels from USAspending

Takes a list of SAM.gov Unique Entity Identifiers (UEIs) and returns a
clean, normalized panel of federal award activity from USAspending.gov.
Acquisition runs either through the REST API (best for one organization
or a small batch) or through the bulk Award Data Archive (best for large
batches), with both paths landing on one canonical transaction schema.
Normalization applies accounting rules to the raw transaction ledger –
de-duplication, correction and delete handling, action-type
classification, de-obligation netting, and subaward pass-through – to
produce organization x award x year records carrying the awarding
agency, award type, net federal obligation received, and dollars passed
through as subawards.

## See also

Useful links:

- <https://nonprofit-open-data-collective.github.io/usaspend/>

- <https://github.com/Nonprofit-Open-Data-Collective/usaspend>

- Report bugs at
  <https://github.com/Nonprofit-Open-Data-Collective/usaspend/issues>

## Author

**Maintainer**: Jesse Lecy <jdlecy@gmail.com>

Other contributors:

- Nonprofit Open Data Collective \[copyright holder\]
