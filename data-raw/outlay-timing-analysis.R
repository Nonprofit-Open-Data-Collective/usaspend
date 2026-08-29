## Measures the obligation-vs-outlay gap cited in ACCOUNTING.md 2.4 and
## vignette("data-model"). Two questions, both answered on the bundled VUMC
## sample (run 2026-08-28):
##
##   1. COVERAGE. Which awards carry any lifetime outlay
##      (total_outlayed_amount_for_overall_award), by era x family x agency?
##      Finding: era matters (33% -> 78% -> 91% of assistance awards across
##      pre-FY2017 / FY2017-21 / FY2022+ first actions) but agency matters as
##      much: post-FY2022 HHS 98% vs VA contracts 0% and DoD 2%.
##
##   2. TIMING. Where annual outlays exist at all -- the account-level File C
##      records behind POST /awards/funding/, complete only from the FY2022
##      monthly mandate -- do within-year obligations track within-year
##      outlays? Finding: no. On FY2022+ awards whose File C obligations
##      reconcile with their award transactions, obligations put a median 90%
##      of an award's dollars in its first fiscal year, outlays 2%; cash lags
##      commitment by ~1 year; ~two-thirds of dollars land in a different year
##      under the two measures (half-L1 distance between annual shares).
##
## Requires network access for part 2 (72 stratified awards, ~250 requests).
suppressMessages(library(data.table))
suppressMessages(library(httr2))
`%||%` <- function(a, b) if (is.null(a)) b else a
load("data/vumc_transactions.rda")
x <- as.data.table(vumc_transactions)
x[, fy := year(action_date) + (month(action_date) >= 10)]

## ---- 1. coverage of the lifetime outlay field ------------------------------
lastval <- function(v) { v <- v[!is.na(v)]; if (length(v)) v[length(v)] else v[NA_integer_] }
setorderv(x, c("award_key", "action_date"), na.last = TRUE)
aw <- x[!is.na(award_key), .(
  total_outlayed = lastval(award_total_outlayed),
  grp            = lastval(award_group),
  agency         = lastval(awarding_agency_name),
  first_fy       = suppressWarnings(min(fy, na.rm = TRUE)),
  oblig          = sum(federal_action_obligation, na.rm = TRUE)
), by = award_key][is.finite(first_fy)]
aw[, era := fifelse(first_fy >= 2022, "c_FY2022+",
             fifelse(first_fy >= 2017, "b_FY2017-21", "a_pre-2017"))]
aw[, has_outlay := !is.na(total_outlayed) & total_outlayed != 0]

cat("== coverage by era x award group ==\n")
print(dcast(aw[, .(pct = round(100 * mean(has_outlay), 1)), by = .(era, grp)],
            grp ~ era, value.var = "pct"))
cat("\n== FY2022+ coverage by agency (n >= 5) ==\n")
print(aw[era == "c_FY2022+", .(n = .N, pct = round(100 * mean(has_outlay), 1)),
         by = agency][n >= 5][order(-n)])

## ---- 2. within-year obligations vs File C outlays --------------------------
samp_frame <- aw[first_fy >= 2017 & oblig > 100000,
                 .(award_key, grp, agency, first_fy,
                   era = fifelse(first_fy >= 2022, "FY2022+",
                          fifelse(first_fy >= 2020, "FY2020-21", "FY2017-19")))]
set.seed(20260828)
samp <- samp_frame[, .SD[sample(.N, min(.N, 12L))], by = .(grp, era)]

fetch_funding <- function(key, max_pages = 40L) {
  acc <- list(); page <- 1L
  repeat {
    r <- tryCatch(
      request("https://api.usaspending.gov/api/v2/awards/funding/") |>
        req_body_json(list(award_id = key, page = page, limit = 100,
                           sort = "reporting_fiscal_date", order = "asc")) |>
        req_timeout(60) |>
        req_retry(max_tries = 4, backoff = function(i) 3 * 2^i) |>
        req_perform() |> resp_body_json(),
      error = function(e) NULL)
    if (is.null(r)) return(NULL)
    acc[[length(acc) + 1L]] <- r$results %||% list()
    if (!isTRUE(r$page_metadata$hasNext) || page >= max_pages) break
    page <- page + 1L; Sys.sleep(0.25)
  }
  do.call(c, acc)
}

keep <- c("reporting_fiscal_year", "reporting_fiscal_month",
          "transaction_obligated_amount", "gross_outlay_amount",
          "federal_account", "disaster_emergency_fund_code", "object_class",
          "program_activity_code", "funding_agency_id")
fnd <- rbindlist(lapply(samp$award_key, function(key) {
  rows <- fetch_funding(key); Sys.sleep(0.25)
  if (!length(rows)) return(NULL)
  dt <- rbindlist(lapply(rows, function(r)
    lapply(setNames(r[keep], keep), function(v) if (is.null(v)) NA else v)), fill = TRUE)
  dt[, award_key := key][]
}), fill = TRUE)
cat("\nFile C rows fetched:", nrow(fnd), "for", uniqueN(fnd$award_key),
    "of", nrow(samp), "sampled awards\n")

## gross_outlay_amount is CUMULATIVE within each fiscal year per account /
## DEFC / object-class / program-activity cell: annual outlay = last reported
## value in the FY per cell, summed over cells. transaction_obligated_amount
## is per-period incremental.
cell <- c("award_key", "federal_account", "disaster_emergency_fund_code",
          "object_class", "program_activity_code", "funding_agency_id")
for (cc in setdiff(cell, "award_key")) fnd[is.na(get(cc)), (cc) := "NA"]
ol <- fnd[!is.na(gross_outlay_amount)]
setorderv(ol, c(cell, "reporting_fiscal_year", "reporting_fiscal_month"))
ol_fy <- ol[, .(outlay = last(gross_outlay_amount)), by = c(cell, "reporting_fiscal_year")][
  , .(outlay_fy = sum(outlay)), by = .(award_key, fy = reporting_fiscal_year)]
ob_c <- fnd[!is.na(transaction_obligated_amount),
            .(filec_oblig_fy = sum(transaction_obligated_amount)),
            by = .(award_key, fy = reporting_fiscal_year)]
ob_tx <- x[award_key %in% samp$award_key & !is.na(fy),
           .(oblig_fy = sum(federal_action_obligation, na.rm = TRUE)),
           by = .(award_key, fy)]
ay <- Reduce(function(a, b) merge(a, b, by = c("award_key", "fy"), all = TRUE),
             list(ob_tx, ob_c, ol_fy))
for (cc in c("oblig_fy", "filec_oblig_fy", "outlay_fy")) ay[is.na(get(cc)), (cc) := 0]
ay <- merge(ay, samp[, .(award_key, grp, era)], by = "award_key")

## linkage screen: File C lifetime obligations must reconcile with the award
## transactions, or the two series are not describing the same money
lt <- ay[, .(oblig = sum(oblig_fy), filec = sum(filec_oblig_fy),
             outlay = sum(outlay_fy)), by = .(award_key, grp, era)]
lt[, linked := abs(filec - oblig) <= pmax(0.25 * abs(oblig), 1000)]

## clean era: first obligation FY2022+, so no pre-mandate truncation
d <- ay[award_key %in% lt[linked & oblig > 0, award_key] & era == "FY2022+"]
d[, `:=`(sh_ob = oblig_fy / sum(oblig_fy),
         sh_ol = {s <- sum(outlay_fy); if (s > 0) outlay_fy / s else NA_real_}),
  by = award_key]
cm <- d[!is.na(sh_ol), .(
  lag_years = sum(fy * pmax(outlay_fy, 0)) / sum(pmax(outlay_fy, 0)) -
              sum(fy * pmax(oblig_fy, 0))  / sum(pmax(oblig_fy, 0)),
  half_l1   = 0.5 * sum(abs(sh_ob - sh_ol)),
  ob_y1     = sum(sh_ob[fy == min(fy[oblig_fy > 0])]),
  ol_y1     = sum(sh_ol[fy == min(fy[oblig_fy > 0])])
), by = .(award_key, grp)]
cat("\n== FY2022+ linked awards: within-year divergence ==\n")
print(cm[, .(n = .N,
             median_lag_years  = round(stats::median(lag_years), 2),
             median_half_l1    = round(stats::median(half_l1), 2),
             median_oblig_yr1  = round(stats::median(ob_y1), 2),
             median_outlay_yr1 = round(stats::median(ol_y1), 2)), by = grp])
