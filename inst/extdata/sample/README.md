# Sample extract

A real three-UEI pull from `POST /api/v2/download/transactions/`, taken
2026-08-27, kept verbatim as a fixture.

    recipient_search_text = CFFMYPABYAG3, FG8QB99NF8K3, H7LMD1ANJNN4
    award_type_codes      = all 22
    time_period           = 2007-10-01 .. 2025-09-30 on action_date

152 rows across four files. It is small but it happens to contain most of the
cases the normalization rules have to handle:

- an award whose eight transactions sum exactly to its reported lifetime total
- a de-obligating REVISION of -$310,999
- zero-dollar administrative modifications (30 of 111 contract actions)
- contract IDV rows with a blank `award_type_code`
- the same award type code carrying two different description strings
  ("DELIVERY ORDER" and "DO", "PURCHASE ORDER" and "PO") in one file
- an IDV with a $40,000,000 potential value against $0 obligated
- subaward rows that are all inbound, none outbound

All of it is public federal award data.
