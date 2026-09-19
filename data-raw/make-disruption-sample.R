## Builds `disruption_sample`, the bundled data behind vignette("disruption").
##
## Source: a 1,000-UEI test database (the first 1,000 rows of the npmatch
## 2025NOV crosswalk), pulled 2026-09-18 via the API path for FY2008-FY2026,
## plus File C funding for 3,325 recent awards. Built by the stage scripts in
## C:/Users/jdlec/Documents/USASPEND/scripts (01_extract.R, 03_impute_test.R).
## The raw CSVs are re-harmonized here so the disruption fields
## (transaction_description, ceiling change, office, potential end date) are
## present -- the stored extract predates them.
##
## Everything bundled is an aggregate or a short case ledger; no full ledger.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
root <- Sys.getenv("USASPEND_ROOT", "C:/Users/jdlec/Documents/USASPEND")
T0 <- as.Date("2025-01-20")

## ---- ledger ------------------------------------------------------------------
xw <- fread(file.path(root, "sample_crosswalk_1000.csv"), colClasses = "character")
dirs <- list.dirs(file.path(root, "raw"), recursive = FALSE)
tx <- rbindlist(lapply(dirs, function(d) read_download_dir(d)$transactions), use.names = TRUE, fill = TRUE)
tx <- suppressMessages(us_normalize_transactions(tx, requested_uei = xw$uei))
tx <- tx[recipient_uei %in% xw$uei & !is.na(action_date)]
f <- us_disruption_flags(tx)
DATA_END <- max(f$action_date)

agency_group <- function(x) fcase(
  x %like% "International Development", "USAID", x %like% "Department of State", "State",
  x %like% "Health and Human", "HHS", x %like% "Department of Education", "Education",
  x %like% "Housing and Urban", "HUD", x %like% "Department of Defense", "DoD",
  x %like% "Agriculture", "USDA", x %like% "Environmental Protection", "EPA",
  x %like% "Veterans", "VA", default = "Other")
## an award belongs to the agency that originated it (first action), so a
## USAID award moved to State stays in the USAID series
orig <- f[, .(agency = agency_group(first(awarding_agency_name))), by = award_key]
f <- merge(f, orig, by = "award_key", sort = FALSE)
f[, `:=`(cy = year(action_date), mo = month(action_date), fy = action_fiscal_year)]
f[, fm := (mo + 2L) %% 12L + 1L]                       # fiscal month, Oct = 1
setorder(f, award_key, action_date, modification_number)

## supply delivery orders edit dates and cancel routinely; not disruption
supply <- f[award_group == "contract" & (awarding_sub_agency_name %like% "Defense Logistics" |
            grepl("^[^0-9A-Z]*[0-9]{8,}!", toupper(fcoalesce(transaction_description, "")))), unique(award_key)]

## ---- 1. ten-year trend ---------------------------------------------------------
## Oct-Aug of each fiscal year, so FY2026 (data to mid-September) is comparable
trend_fy <- f[fy >= 2016 & fm <= 11, .(
  gross_obligations = sum(pmax(federal_action_obligation, 0), na.rm = TRUE),
  net_obligations   = sum(federal_action_obligation, na.rm = TRUE),
  new_awards = uniqueN(award_key[(award_group == "assistance" & action_type_code == "A") |
                                 (award_group == "contract" & modification_number == "0")]),
  n_actions = .N), by = .(fy, agency)][order(agency, fy)]
trend_month <- f[action_date >= as.Date("2015-10-01") & action_date < as.Date("2026-09-01"), .(
  gross_obligations = sum(pmax(federal_action_obligation, 0), na.rm = TRUE),
  deobligations = -sum(pmin(federal_action_obligation, 0), na.rm = TRUE),
  n_actions = .N), by = .(month = as.Date(format(action_date, "%Y-%m-01")))][order(month)]

## ---- 2. signal rates, Feb-Aug of each year ----------------------------------------
win <- f[mo %in% 2:8 & cy >= 2019 & !award_key %in% supply]
signals <- win[, .(
  gross_obligations = sum(pmax(federal_action_obligation, 0), na.rm = TRUE),
  new_awards = uniqueN(award_key[(award_group == "assistance" & action_type_code == "A") |
                                 (award_group == "contract" & modification_number == "0")]),
  n_actions = .N,
  term_code = sum(dsr_term_code), term_text = sum(dsr_term_text), rescinded = sum(dsr_rescinded),
  closeout = sum(dsr_closeout),
  early_deob = sum(dsr_early_deob),
  early_deob_dollars = -sum(federal_action_obligation[dsr_early_deob], na.rm = TRUE),
  deob_dollars = -sum(pmin(federal_action_obligation, 0), na.rm = TRUE),
  end_cut = sum(dsr_end_cut), end_cut_no_deob = sum(dsr_end_cut & federal_action_obligation >= 0, na.rm = TRUE),
  ceiling_cut = sum(dsr_ceiling_cut), ceiling_cut_dollars = -sum(pmin(ceiling_change, 0), na.rm = TRUE),
  extension = sum(dsr_extension), stop_work = sum(dsr_stop_work), admin = sum(dsr_admin),
  zero_dollar = sum(is_zero_dollar, na.rm = TRUE),
  novation = sum(dsr_novation), transfer = sum(dsr_transfer),
  agency_change = sum(dsr_agency_change), recipient_change = sum(dsr_recipient_change)), by = .(year = cy)][order(year)]
signals_agency <- win[cy >= 2022, .(
  gross_obligations = sum(pmax(federal_action_obligation, 0), na.rm = TRUE),
  terminations = sum(dsr_term_code | dsr_term_text), end_cut = sum(dsr_end_cut),
  early_deob = sum(dsr_early_deob), ceiling_cut = sum(dsr_ceiling_cut)), by = .(year = cy, agency)][order(agency, year)]
action_types <- dcast(win[cy >= 2021, .N, by = .(award_group, action_type_label, year = cy)],
                      award_group + action_type_label ~ year, value.var = "N", fill = 0)

## ---- 3. terminations table -----------------------------------------------------------
ev <- rbind(
  f[action_date >= T0 & (dsr_term_code | dsr_term_text), .(t_date = min(action_date), kind = "formal"), by = award_key],
  f[action_date >= T0 & dsr_end_cut, .(t_date = min(action_date), kind = "quiet_truncation"), by = award_key])
ev <- ev[order(award_key, kind)][, .SD[1], by = award_key][!award_key %in% supply]
tt <- merge(f, ev, by = "award_key")
terminations <- tt[, {
  at <- action_date == t_date; after <- action_date > t_date
  .(kind = kind[1], t_date = t_date[1], agency = agency[1],
    awarding_agency = last(awarding_agency_name), sub_agency = last(awarding_sub_agency_name),
    office = last(awarding_office_name), recipient = last(recipient_name),
    award_group = award_group[1], award_type = last(award_type_label),
    how = paste(c(if (any(dsr_term_code[at])) "action_code", if (any(dsr_term_text[at])) "description",
                  if (any(dsr_end_cut[action_date >= t_date])) "end_date_cut"), collapse = "+"),
    first_action = min(action_date),
    obligated_before = sum(federal_action_obligation[action_date < t_date], na.rm = TRUE),
    change_at_notice = sum(federal_action_obligation[at], na.rm = TRUE),
    deobligated_since = sum(pmin(federal_action_obligation[after], 0), na.rm = TRUE),
    new_money_since = sum(pmax(federal_action_obligation[after], 0), na.rm = TRUE),
    ceiling_cut = sum(pmin(ceiling_change[action_date >= t_date], 0), na.rm = TRUE),
    end_before = sched_end[at][1], end_now = last(pop_end_date),
    rescinded = any(dsr_rescinded[after]),
    agency_changed = any(dsr_agency_change),
    first_deob_after = suppressWarnings(min(action_date[after & federal_action_obligation < 0])),
    notice_text = substr(transaction_description[at][1], 1, 160))
}, by = award_key]
terminations[is.infinite(first_deob_after), first_deob_after := NA]
terminations[, status := fcase(
  rescinded, "rescinded",
  deobligated_since + pmin(change_at_notice, 0) < 0, "de-obligated",
  new_money_since > 0, "new money since",
  default = "still obligated")]

## same-recipient successor candidates (identity evidence required)
tok <- function(s) { w <- unique(strsplit(gsub("[^A-Z0-9 ]", " ", toupper(s)), "\\s+")[[1]]); w[nchar(w) >= 4] }
jac <- function(a, b) if (!length(a) || !length(b)) 0 else length(intersect(a, b)) / length(union(a, b))
base <- f[, .(first_action = min(action_date), recipient_uei = first(recipient_uei),
              agency = first(awarding_agency_name), office = first(awarding_office_name),
              code = fcoalesce(first(cfda_number), first(psc_code)), award_id = first(award_id),
              desc = first(transaction_description), text = paste(toupper(transaction_description), collapse = " "),
              obligated = sum(federal_action_obligation, na.rm = TRUE)), by = award_key]
tm <- merge(terminations[, .(award_key, t_date)], base, by = "award_key")
links <- rbindlist(lapply(seq_len(nrow(tm)), function(i) {
  t <- tm[i]
  c <- base[recipient_uei == t$recipient_uei & award_key != t$award_key & agency == t$agency &
            first_action >= t$t_date - 90 & first_action <= t$t_date + 365]
  if (!nrow(c)) return(NULL)
  oid <- gsub("[^A-Z0-9]", "", toupper(t$award_id)); tt_ <- tok(t$desc)
  c[, `:=`(desc_sim = vapply(desc, function(d) jac(tt_, tok(d)), 0),
           same_office = !is.na(office) & office == t$office,
           same_code = !is.na(code) & code == t$code,
           cites_old_id = nchar(oid) >= 6 & grepl(oid, gsub("[^A-Z0-9]", "", text), fixed = TRUE))]
  b <- c[order(-(cites_old_id * 10 + desc_sim * 6 + same_office * 2 + same_code * 2))][1]
  b[, .(award_key = t$award_key, successor = award_key, successor_start = first_action,
        successor_obligated = obligated, desc_sim = round(desc_sim, 2), same_office, same_code, cites_old_id)]
}))
links[, link := fcase(cites_old_id | desc_sim >= 0.40, "probable",
                      desc_sim >= 0.15 & (same_office | same_code), "possible", default = "weak")]
terminations <- merge(terminations, links, by = "award_key", all.x = TRUE)
terminations[is.na(link), link := "none"]
setorder(terminations, t_date)

## ---- 4. continuations: the next funding action after a multi-year anchor --------------
an <- f[award_group == "assistance" & federal_action_obligation > 0 & sched_end > action_date + 400,
        .(award_key, agency, a_date = action_date)]
nx <- f[federal_action_obligation > 0, .(award_key, n_date = action_date)]
an[, next_pos := nx[an, on = .(award_key, n_date > a_date), mult = "first", x.n_date]]
an[, due := a_date + 365]
an <- an[due + 120 <= DATA_END - 45]
an[, outcome := fcase(is.na(next_pos) | next_pos > due + 120, "missing or >120 days late",
                      next_pos > due + 30, "30-120 days late", default = "on time")]
continuations <- an[year(due) >= 2021, .N, by = .(due_year = year(due), agency, outcome)]

## ---- 5. outlays: awards scheduled active all quarter with no cash ---------------------
fund <- readRDS(file.path(root, "imputation_test", "funding.rds"))[award_key %in% f$award_key]
cell <- c("federal_account", "disaster_emergency_fund_code", "object_class", "program_activity_code", "funding_agency_id")
setorderv(fund, c("award_key", cell, "reporting_fiscal_year", "reporting_fiscal_month"))
fund[, go := fcoalesce(gross_outlay_amount, 0)]
fund[, inc := go - shift(go, fill = 0), by = c("award_key", cell, "reporting_fiscal_year")]
fund[, fq := (reporting_fiscal_month - 1L) %/% 3L + 1L]
qo <- fund[, .(outlay = sum(inc)), by = .(award_key, fy = reporting_fiscal_year, fq)]
reporters <- fund[go != 0, unique(award_key)]
qs <- CJ(award_key = reporters, fy = 2023:2026, fq = 1:4)
qs[, qstart := as.Date(sprintf("%d-%02d-01", ifelse(fq == 1, fy - 1, fy), c(10, 1, 4, 7)[fq]))]
led <- f[award_key %in% reporters, .(award_key, a_date = action_date, pop_start_date, pop_end_date)]
qs[, c("ps", "pe") := led[qs, on = .(award_key, a_date <= qstart), mult = "last",
                          .(x.pop_start_date, x.pop_end_date)]]
qs <- qs[!is.na(pe) & ps <= qstart & pe >= qstart + 90]
qs <- merge(qs, qo, by = c("award_key", "fy", "fq"), all.x = TRUE)
qs[is.na(outlay), outlay := 0]
qs <- merge(qs, orig, by = "award_key")
last_q <- fund[, max(reporting_fiscal_year * 10L + fq)]
outlay_quarters <- qs[fy * 10L + fq <= last_q, .(active = .N, no_cash = sum(outlay <= 0),
                                                  outlays = sum(outlay)), by = .(fy, fq, agency)][order(agency, fy, fq)]
outlay_last_quarter <- c(fy = last_q %/% 10L, fq = last_q %% 10L)

## ---- 6. case ledgers ------------------------------------------------------------------
pick <- function(cond, by = "obligated_before") {
  z <- terminations[eval(cond)]; if (!nrow(z)) return(NA_character_)
  z[order(-get(by))]$award_key[1]
}
case_keys <- list(
  termination_rescinded = terminations[status == "rescinded" & agency == "Education"]$award_key[1],
  termination_no_deob   = pick(quote(kind == "formal" & agency == "USAID" & status == "still obligated")),
  termination_deob      = pick(quote(kind == "formal" & status == "de-obligated" & agency == "Education")),
  ## the largest non-COVID schedule cut with the money left in place
  quiet_truncation      = pick(quote(kind == "quiet_truncation" & status == "still obligated" &
                                     agency %in% c("EPA", "HHS") & !grepl("COVID", toupper(notice_text)))),
  ## an NIH research grant (R-series) whose next year's funding never came
  missed_continuation   = an[year(due) == 2025 & outcome != "on time" & award_key %like% "^ASST_NON_R"][
                             order(a_date)]$award_key[1],
  usaid_idv             = f[award_key %like% "^CONT_IDV_7200AA19D00028"]$award_key[1],
  usaid_task_order      = f[award_key %like% "72049221F00002"]$award_key[1],
  reaward_old           = terminations[link == "probable" & grepl("YOUTH TOBACCO", toupper(notice_text) ) |
                                       (link == "probable" & award_key %in% base[grepl("YOUTH TOBACCO", toupper(desc)), award_key])]$award_key[1],
  novation              = f[dsr_novation == TRUE][order(-action_date)]$award_key[1])
case_keys$reaward_new <- terminations[award_key == case_keys$reaward_old]$successor[1]
## a ceiling cut on a contract not already used as a case, with no money withdrawn
case_keys$ceiling_cut <- f[action_date >= T0 & dsr_ceiling_cut & federal_action_obligation >= 0 &
                            !award_key %in% c(supply, unlist(case_keys))][order(ceiling_change)]$award_key[1]
case_keys <- Filter(function(k) length(k) && !is.na(k), case_keys)
keep <- c("award_key", "award_group", "modification_number", "action_date", "action_type_code", "action_type_label",
          "federal_action_obligation", "ceiling_change", "pop_end_date", "sched_end", "end_shift_days",
          "awarding_agency_name", "awarding_sub_agency_name", "awarding_office_name", "funding_agency_name",
          "recipient_name", "transaction_description", grep("^dsr_", names(f), value = TRUE))
cases <- rbindlist(lapply(names(case_keys), function(nm)
  f[award_key == case_keys[[nm]], ..keep][, case := nm]), use.names = TRUE)
setcolorder(cases, "case")
cases[, transaction_description := substr(transaction_description, 1, 200)]

## awards following an investigator to another institution (API probe of
## reconciliation breaks, scripts/04_break_probe.R)
pb <- fread(file.path(root, "break_probe.csv"))
pi_transfers <- pb[sample_recipient %like% "CEDARS" & api_other_uei_n > 0 & award_key %like% "^ASST",
                   .(award_key, recipient_in_sample = sample_recipient, reported_total = reported,
                     in_sample_total = ours_sum, api_transactions = api_n,
                     transactions_other_recipient = api_other_uei_n,
                     other_recipients = api_other_names, recipient_now = api_recipient_now)]

## ---- 7. USAID -------------------------------------------------------------------------
us <- f[agency == "USAID"]
usaid <- list(
  awards = uniqueN(us$award_key),
  active_at_T0 = us[, .(e = last(pop_end_date)), by = award_key][e >= T0, .N],
  with_action_since_T0 = us[action_date >= T0, uniqueN(award_key)],
  terminated = terminations[agency == "USAID", .N],
  terminated_deobligated = terminations[agency == "USAID" & status == "de-obligated", .N],
  moved_to_state = us[dsr_agency_change == TRUE, uniqueN(award_key)],
  actions_since_T0 = us[action_date >= T0, .N, by = .(action_type_label, awarding_agency = awarding_agency_name,
                                                        funding_agency = funding_agency_name)][order(-N)])

disruption_sample <- list(
  meta = list(sample = "First 1,000 UEIs of the npmatch 2025NOV nonprofit crosswalk (434 with federal awards)",
              pulled = as.Date("2026-09-18"), data_end = DATA_END, t0 = T0,
              n_orgs_with_awards = uniqueN(f$recipient_uei), n_awards = uniqueN(f$award_key),
              n_transactions = nrow(f), top_states = f[, .N, by = recipient_state][order(-N)][1:5]$recipient_state,
              largest_recipient_share = round(f[, .N, by = recipient_uei][, max(N) / sum(N)], 3),
              outlay_last_quarter = outlay_last_quarter),
  trend_fy = trend_fy, trend_month = trend_month,
  signals = signals, signals_agency = signals_agency, action_types = action_types,
  terminations = terminations, continuations = continuations,
  outlay_quarters = outlay_quarters, cases = cases, pi_transfers = pi_transfers, usaid = usaid)
for (nm in names(disruption_sample)) if (is.data.table(disruption_sample[[nm]])) {
  setindex(disruption_sample[[nm]], NULL); setkey(disruption_sample[[nm]], NULL)
}
usethis::use_data(disruption_sample, overwrite = TRUE, compress = "xz")
str(disruption_sample, max.level = 1)
print(names(case_keys)); print(format(object.size(disruption_sample), "Kb"))
