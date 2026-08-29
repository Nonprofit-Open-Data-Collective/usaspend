## Outlay-imputation experiment: can annual cash be recovered from obligations?
##
## Sample: VUMC (bundled) plus the 50-nonprofit pilot extract. Candidates are
## awards first obligated FY2020+ with > $50k net obligations; the pilot side
## is further screened to completed awards (final pop_end by FY2025), the
## high-yield cells for ground truth.
##
## Ground truth, two tiers (File C linkage required for both: File C lifetime
## obligations within 10% of the award's own transaction ledger):
##   tier 1 "reconciled"      lifetime outlays within 10% of lifetime
##                            obligations and cash no longer flowing -- the
##                            strict "obligations equal outlays" cases.
##   tier 2 "shape_complete"  first obligated FY2022+ (inside the monthly
##                            reporting mandate), performance ended by FY2025,
##                            outlay series plateaued. Lifetime cash may fall
##                            short of obligations, but the TIMING profile is
##                            fully observed, which is all the allocation task
##                            needs -- the metric normalizes level away.
##
## Methods
##   M0 as_obligated       cash = commitment year (the implicit status quo)
##   M1 even_pop           net obligations spread evenly over the performance
##                         window (first obligation FY -> final pop_end FY)
##   M2 profile_duration   empirical mean share profile in event time, by
##                         duration bin, learned out-of-fold (5-fold CV)
##   M3 profile_dur_type   duration x award-type cells, hierarchical fallback
##   M4 profile_dur_start  duration x late-fiscal-year-start cells
##   M5 phase_split        funded-extension awards split at the extension
##                         event, each phase spread evenly over its own window
##
## Metric: misallocation share = 0.5 * sum_y |imputed_y - actual_y| / total --
## the fraction of the award's dollars placed in the wrong fiscal year
## (imputed series normalized to the actual total, so the metric is purely
## timing). Chosen over correlation because the task is allocation: totals are
## known, correlation is scale- and level-invariant, and pooled correlations
## are dominated by between-award size variation. Correlations are reported
## descriptively for comparison.
##
## Env vars (optional): FUNDING_RDS -- prefetched VUMC File C (list with
## $funding); PILOT_FUNDING_RDS -- prefetched pilot File C state (list with
## $funding); PILOT_TX_RDS -- normalized pilot candidate transactions.
## Without them the script fetches live (thousands of requests).
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
pilot_dir <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending/pilot"

## ---- 1. transactions from both sources ------------------------------------
load("data/vumc_transactions.rda")
tx_v <- suppressMessages(us_normalize_transactions(as.data.table(vumc_transactions)))
tx_v[, source := "vumc"]

pt <- Sys.getenv("PILOT_TX_RDS")
tx_p <- if (nzchar(pt) && file.exists(pt)) {
  readRDS(pt)
} else if (dir.exists(pilot_dir)) {
  p <- read_download_dir(file.path(pilot_dir, "raw"))
  suppressMessages(us_normalize_transactions(p$transactions))
} else NULL
if (!is.null(tx_p)) {
  tx_p <- as.data.table(tx_p)[!award_key %in% unique(tx_v$award_key)]
  tx_p[, source := "pilot"]
}
tx <- rbindlist(list(tx_v, tx_p), use.names = TRUE, fill = TRUE)
tx <- tx[!is.na(award_key) & !is.na(action_fiscal_year)]
tx[, fy := action_fiscal_year]
tx[, fy_month := (month(action_date) + 2L) %% 12L + 1L]     # Oct=1 ... Sep=12

## ---- 2. award features -----------------------------------------------------
setorderv(tx, c("award_key", "action_date"), na.last = TRUE)
feat <- tx[, {
  pe <- pop_end_date[!is.na(pop_end_date)]
  pop0_end  <- if (length(pe)) pe[1] else as.Date(NA)
  pop_final <- if (length(pe)) pe[length(pe)] else as.Date(NA)
  pop_max   <- if (length(pe)) max(pe) else as.Date(NA)
  pos <- sum(federal_action_obligation[federal_action_obligation > 0], na.rm = TRUE)
  neg <- sum(federal_action_obligation[federal_action_obligation < 0], na.rm = TRUE)
  pe_all <- pop_end_date; pe_all[is.na(pe_all)] <- as.Date("1900-01-01")
  ext_i <- if (!is.na(pop0_end)) which(pe_all > pop0_end + 90)[1] else NA_integer_
  ext_date <- if (!is.na(ext_i)) action_date[ext_i] else as.Date(NA)
  after <- !is.na(ext_date) & action_date >= ext_date
  .(first_fy = min(fy), last_oblig_fy = max(fy),
    first_month = fy_month[which.min(action_date)],
    n_tx = .N, oblig = pos + neg, pos = pos, neg = neg,
    pop0_end = pop0_end, pop_final_end = pop_final,
    ext_days = as.numeric(pop_max - pop0_end),
    ext_fy = if (!is.na(ext_date)) year(ext_date) + (month(ext_date) >= 10) else NA_integer_,
    money_after_ext = sum(federal_action_obligation[after], na.rm = TRUE),
    grp = data.table::last(award_group), fam = data.table::last(award_family),
    type_code = data.table::last(award_type_code),
    agency = data.table::last(awarding_agency_name),
    source = source[1])
}, by = award_key]

feat <- feat[first_fy >= 2020 & abs(oblig) > 50000]
feat[, extended   := !is.na(ext_days) & ext_days > 90]
feat[, funded_ext := extended & money_after_ext > 0.05 * pmax(pos, 1)]
feat[, reduced    := neg < -0.05 * pmax(pos, 1)]
feat[, mod_class := fcase(
  reduced,                  "reduced",
  funded_ext,               "extension_funded",
  extended,                 "extension_timeline",
  last_oblig_fy > first_fy, "multi_year_incremental",
  default =                 "single_year")]
feat[, pop_end_fy  := year(pop_final_end) + (month(pop_final_end) >= 10)]
feat[, pop0_end_fy := year(pop0_end) + (month(pop0_end) >= 10)]
feat[, duration := pmax(pop_end_fy - first_fy + 1L, last_oblig_fy - first_fy + 1L, 1L)]
feat[is.na(duration), duration := last_oblig_fy - first_fy + 1L]
feat[, dur_bin := pmin(duration, 6L)]
feat[, late_start := first_month >= 7L]                     # first obligated Apr-Sep
feat[, type_cell := fcase(type_code == "04", "project_grant",
                          type_code == "05", "coop_agreement",
                          grp == "contract", "contract",
                          default = "other_assistance")]

## ---- 3. File C outlays -----------------------------------------------------
read_funding <- function(env) {
  f <- Sys.getenv(env)
  if (nzchar(f) && file.exists(f)) {
    obj <- readRDS(f)
    if (is.data.frame(obj$funding)) as.data.table(obj$funding)
    else rbindlist(obj$funding, fill = TRUE)
  } else NULL
}
fund_v <- read_funding("FUNDING_RDS")
fund_p <- read_funding("PILOT_FUNDING_RDS")
if (is.null(fund_v)) fund_v <- us_fetch_outlays(feat[source == "vumc"]$award_key)
if (is.null(fund_p) && any(feat$source == "pilot")) {
  fund_p <- us_fetch_outlays(feat[source == "pilot"]$award_key)
}
funding <- rbindlist(list(fund_v,
                          if (!is.null(fund_p)) fund_p[!award_key %in% unique(fund_v$award_key)]),
                     use.names = TRUE, fill = TRUE)
ann <- us_outlays_by_year(funding)
ann <- ann[award_key %in% feat$award_key]

obl_fy <- tx[award_key %in% feat$award_key,
             .(oblig_fy = sum(federal_action_obligation, na.rm = TRUE)),
             by = .(award_key, fy)]

## ---- 4. ground truth, two tiers -------------------------------------------
life <- merge(
  ann[, .(filec = sum(filec_obligation), outlay_total = sum(outlay, na.rm = TRUE),
          last_outlay_fy = {
            ok <- !is.na(outlay) & outlay > 0
            if (any(ok)) max(fiscal_year[ok]) else NA_integer_
          },
          sh25 = sum(outlay[fiscal_year == 2025], na.rm = TRUE),
          sh26 = sum(outlay[fiscal_year >= 2026], na.rm = TRUE)), by = award_key],
  feat, by = "award_key")
life[, sh25 := sh25 / pmax(outlay_total, 1)]
life[, sh26 := sh26 / pmax(outlay_total, 1)]
life[, linked := abs(filec - oblig) <= pmax(0.10 * abs(oblig), 1000)]
life[, tier1 := linked & oblig > 0 &
                outlay_total >= 0.9 * oblig & outlay_total <= 1.1 * oblig &
                sh26 <= 0.10]
life[, tier2 := linked & oblig > 0 & !tier1 &
                first_fy >= 2022 & !is.na(pop_end_fy) & pop_end_fy <= 2025 &
                outlay_total >= 0.25 * oblig & sh26 <= 0.05 & sh25 <= 0.20]
life[, tier := fcase(tier1, "reconciled", tier2, "shape_complete",
                     default = NA_character_)]
truth_keys <- life[!is.na(tier)]$award_key

cat("candidates with File C:", uniqueN(ann$award_key),
    "| linked:", sum(life$linked),
    "| tier1 reconciled:", sum(life$tier1),
    "| tier2 shape-complete:", sum(life$tier2),
    "| ground truth:", length(truth_keys), "\n")
gt <- life[award_key %in% truth_keys]
cat("\nground truth composition:\n")
print(gt[, .N, by = .(tier, mod_class)][order(tier, -N)])
print(gt[, .N, keyby = .(tier, dur_bin)])

## ---- 5. per-award actual and imputed series -------------------------------
win <- gt[, .(award_key, y0 = first_fy,
              y1 = pmax(pop_end_fy, last_outlay_fy, last_oblig_fy, na.rm = TRUE))]
grid <- win[, .(fy = seq(y0, y1)), by = award_key]
grid <- merge(grid, ann[!is.na(outlay), .(award_key, fy = fiscal_year, actual = outlay)],
              by = c("award_key", "fy"), all.x = TRUE)
grid <- merge(grid, obl_fy, by = c("award_key", "fy"), all.x = TRUE)
for (cc in c("actual", "oblig_fy")) grid[is.na(get(cc)), (cc) := 0]
grid <- merge(grid, gt[, .(award_key, first_fy, last_oblig_fy, pop_end_fy,
                           pop0_end_fy, ext_fy, dur_bin, type_cell, late_start,
                           mod_class, tier, oblig, outlay_total, funded_ext)],
              by = "award_key")
grid[, t := fy - first_fy]
grid[, actual_share := actual / outlay_total]

misalloc <- function(imputed, actual) {
  tot <- sum(actual)
  if (tot <= 0) return(NA_real_)
  imp <- if (sum(imputed) > 0) imputed * tot / sum(imputed) else imputed
  0.5 * sum(abs(imp - actual)) / tot
}

## M0: as obligated (negative years floored for allocation, then rescaled)
grid[, m0 := pmax(oblig_fy, 0)]
## M1: even over the performance window
grid[, in_pop := fy <= pmax(pop_end_fy, last_oblig_fy, first_fy, na.rm = TRUE)]
grid[, m1 := as.numeric(in_pop) / sum(in_pop), by = award_key]

## M2-M4: out-of-fold empirical share profiles
set.seed(20260829)
folds <- gt[, .(award_key, fold = sample(rep_len(1:5, .N)))]
grid <- merge(grid, folds, by = "award_key")

profile_impute <- function(g, cells, min_cell = 8L, target = "actual_share") {
  out <- rep(NA_real_, nrow(g))
  g <- data.table::copy(g)[, ".tgt" := get(target)]
  for (f in sort(unique(g$fold))) {
    tr <- g[fold != f]
    te_i <- which(g$fold == f)
    p_cell <- tr[, .(sh = mean(.tgt), n = uniqueN(award_key)), by = c(cells, "t")]
    p_dur  <- tr[, .(sh_dur = mean(.tgt)), by = .(dur_bin, t)]
    p_glob <- tr[, .(sh_glob = mean(.tgt)), by = t]
    te <- g[te_i]
    te <- merge(te, p_cell, by = c(cells, "t"), all.x = TRUE, sort = FALSE)
    te <- merge(te, p_dur, by = c("dur_bin", "t"), all.x = TRUE, sort = FALSE)
    te <- merge(te, p_glob, by = "t", all.x = TRUE, sort = FALSE)
    te[, imp := fifelse(!is.na(sh) & n >= min_cell, sh,
                 fifelse(!is.na(sh_dur), sh_dur,
                  fifelse(!is.na(sh_glob), sh_glob, 0)))]
    data.table::setorderv(te, c("award_key", "fy"))
    ord <- order(g$award_key[te_i], g$fy[te_i])
    out[te_i[ord]] <- te$imp
  }
  out
}
grid[, m2 := profile_impute(grid, c("dur_bin"))]
grid[, m3 := profile_impute(grid, c("dur_bin", "type_cell"))]
grid[, m4 := profile_impute(grid, c("dur_bin", "late_start"))]

## M6: liquidation curve -- level AND timing in one object: the share of NET
## OBLIGATIONS outlaid in event-year t (not the share of the actual outlay
## total), so the curve's sum encodes the outlay/obligation ratio and its
## shape encodes the lag. Cells as in M4, out-of-fold as everywhere.
grid[, oblig_share := actual / oblig]
grid[, m6 := profile_impute(grid, c("dur_bin", "late_start"),
                            target = "oblig_share") * oblig]

## M5: phase split for funded extensions -- even spread per phase
grid[, m5 := m1]
ext <- grid[funded_ext == TRUE & !is.na(ext_fy) & !is.na(pop0_end_fy)]
if (nrow(ext)) {
  ph <- ext[, {
    p1_oblig <- sum(oblig_fy[fy < ext_fy[1]])
    p2_oblig <- sum(oblig_fy[fy >= ext_fy[1]])
    p1_years <- fy >= first_fy[1] & fy <= max(pop0_end_fy[1], first_fy[1])
    p2_years <- fy >= ext_fy[1] & fy <= max(pop_end_fy[1], ext_fy[1])
    w <- pmax(p1_oblig, 0) * p1_years / pmax(sum(p1_years), 1) +
         pmax(p2_oblig, 0) * p2_years / pmax(sum(p2_years), 1)
    .(fy = fy, m5x = w)
  }, by = award_key]
  grid[ph, m5 := i.m5x, on = c("award_key", "fy")]
}

## ---- 6. score --------------------------------------------------------------
methods <- c(as_obligated = "m0", even_pop = "m1", profile_duration = "m2",
             profile_dur_type = "m3", profile_dur_start = "m4", phase_split = "m5",
             liquidation_curve = "m6")
score <- grid[, lapply(methods, function(m) misalloc(get(m), actual)), by = award_key]
data.table::setnames(score, c("award_key", names(methods)))
score <- merge(score, gt[, .(award_key, tier, mod_class, dur_bin, oblig, funded_ext)],
               by = "award_key")

## level-aware scoring: NO rescaling of the imputed series, so a method is
## charged for missing the cash LEVEL as well as its timing. Share methods
## (m1-m4) allocate net obligations, so scale them by oblig first.
level_l1 <- function(imputed, actual) {
  tot <- sum(actual)
  if (tot <= 0) return(NA_real_)
  0.5 * sum(abs(imputed - actual)) / tot
}
dollar_methods <- c(as_obligated = "m0", phase_split = "m5", liquidation_curve = "m6")
share_methods  <- c(even_pop = "m1", profile_duration = "m2",
                    profile_dur_type = "m3", profile_dur_start = "m4")
slev <- grid[, c(lapply(dollar_methods, function(m) level_l1(get(m), actual)),
                 lapply(share_methods,  function(m) level_l1(get(m) * oblig, actual))),
             by = award_key]
data.table::setnames(slev, c("award_key", names(dollar_methods), names(share_methods)))
slev <- merge(slev, gt[, .(award_key, tier, oblig)], by = "award_key")

summarize <- function(s, by = NULL) {
  s[, c(list(n = .N), lapply(.SD, function(v) round(mean(v, na.rm = TRUE), 3))),
    by = by, .SDcols = names(methods)]
}
cat("\n== misallocation share (mean; fraction of dollars in the wrong year) ==\n")
print(summarize(score))
cat("\n-- median --\n")
print(score[, lapply(.SD, function(v) round(stats::median(v, na.rm = TRUE), 3)),
            .SDcols = names(methods)])
cat("\n-- dollar-weighted mean --\n")
print(score[, lapply(.SD, function(v)
        round(sum(v * oblig, na.rm = TRUE) / sum(oblig[!is.na(v)]), 3)),
      .SDcols = names(methods)])
cat("\n== by tier ==\n");     print(summarize(score, "tier"))
cat("\n== by modification class ==\n")
print(summarize(score, "mod_class")[order(mod_class)])
cat("\n== by duration ==\n"); print(summarize(score, "dur_bin")[order(dur_bin)])
cat("\n== funded extensions: phase split vs alternatives ==\n")
print(summarize(score[funded_ext == TRUE])[, c("n", "as_obligated", "even_pop",
      "profile_duration", "phase_split"), with = FALSE])

cat("\n== LEVEL + TIMING (no rescaling): half-L1 / actual cash total ==\n")
lv_methods <- c(names(dollar_methods), names(share_methods))
print(slev[, c(list(n = .N), lapply(.SD, function(v) round(mean(v, na.rm = TRUE), 3))),
           .SDcols = lv_methods])
cat("-- median --\n")
print(slev[, lapply(.SD, function(v) round(stats::median(v, na.rm = TRUE), 3)),
           .SDcols = lv_methods])
cat("-- by tier --\n")
print(slev[, c(list(n = .N), lapply(.SD, function(v) round(mean(v, na.rm = TRUE), 3))),
           by = tier, .SDcols = lv_methods])

cat("\n== why not correlation ==\n")
for (i in seq_along(methods)) {
  cat(sprintf("%-18s pooled annual r = %6.3f   mean misallocation = %.3f\n",
              names(methods)[i], grid[, cor(get(methods[i]), actual)],
              mean(score[[names(methods)[i]]], na.rm = TRUE)))
}

saveRDS(list(grid = grid, score = score, slev = slev, gt = gt, life = life,
             feat = feat),
        "data-raw/outlay-imputation-results.rds")
cat("\nsaved data-raw/outlay-imputation-results.rds\n")
