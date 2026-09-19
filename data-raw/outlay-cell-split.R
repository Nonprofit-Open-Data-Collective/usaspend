## Copied from the 1,000-organization test database (scripts/12_cell_split.R),
## run 2026-09-18. Needs that database: set `root` below. See IMPUTATION.md 7.
## Stage 12: does splitting the liquidation-curve cells for short awards help?
##
## The pooled model (stage 11) lost 0.018 on the pilot's own awards, all of it
## in 1-2 year awards: the pooled short-award curves are the sample's (502 vs
## 27 one-year awards), and the two portfolios pay short awards out
## differently. Test whether an award feature known at imputation time
## explains the difference better than the population label does.
##
##   candidates  fam      award family (grant / contract / other)
##               agency   awarding agency group (agencies with >= 100 truth awards, else other)
##               size     net obligation band (< $100K, $100K-1M, >= $1M)
##               modc     modification class
##   variants    short    split only dur_bin <= 2 (longer awards keep today's cells)
##               all      split every duration
##   scoring     pooled 5-fold CV over the union of pilot + sample truth,
##               scored per population; min_cell fallback unchanged (8)
##   adopt if    overall timing gain has a bootstrap CI excluding 0 and
##               neither population is worse by more than 0.005
suppressPackageStartupMessages({ library(usaspend); library(data.table) })
root <- "C:/Users/jdlec/Documents/USASPEND"
od <- file.path(root, "outlay_refit")
set.seed(20260918)

pool <- readRDS(file.path(od, "results_pooled.rds"))$pooled_training
aw <- pool$awards
keys <- aw[!is.na(tier) & oblig > 0, award_key]
aw <- aw[award_key %in% keys]

## ---- derived cell features --------------------------------------------------
aw[, fam := fcase(award_family == "grant", "grant",
                  award_family == "contract", "contract",
                  default = "other")]
ag_n <- aw[, .N, by = awarding_agency_name]
big <- ag_n[N >= 100, awarding_agency_name]
aw[, agency := fifelse(awarding_agency_name %in% big, awarding_agency_name, "other")]
aw[, size := fcase(oblig < 1e5, "a_<100K", oblig < 1e6, "b_100K-1M", default = "c_>=1M")]
aw[, modc := mod_class]
cat("Agency groups:", paste(c(big, "other"), collapse = " | "), "\n")

## ---- diagnosis: what differs in short awards ---------------------------------
cat("\n== Short awards (dur_bin <= 2) by population ==\n")
sh <- aw[dur_bin <= 2L]
for (v in c("fam", "agency", "size", "modc")) {
  x <- dcast(sh[, .N, by = c("population", v)], as.formula(paste(v, "~ population")), value.var = "N", fill = 0)
  x[, pilot_pct := round(100 * pilot / sum(pilot))][, sample_pct := round(100 * sample / sum(sample))]
  print(x)
}

## ---- CV --------------------------------------------------------------------
K <- 5L
folds <- data.table(award_key = keys, fold = sample(rep_len(seq_len(K), length(keys))))
feats <- c("fam", "agency", "size", "modc")
configs <- c(list(base = NULL),
             setNames(lapply(feats, function(v) list(var = v, short = TRUE)), paste0(feats, "_short")),
             setNames(lapply(feats, function(v) list(var = v, short = FALSE)), paste0(feats, "_all")))

with_split <- function(d, cfg) {
  d <- copy(d)
  if (is.null(cfg)) return(d)
  v <- d[[cfg$var]]
  d[, split := if (cfg$short) fifelse(dur_bin <= 2L, v, "_") else v]
  d
}
cells_of <- function(cfg) if (is.null(cfg)) c("dur_bin", "late_start") else c("dur_bin", "late_start", "split")

run_cfg <- function(cfg) {
  a <- with_split(aw, cfg)
  g <- merge(pool$grid[award_key %in% keys],
             a[, intersect(c("award_key", "split"), names(a)), with = FALSE], by = "award_key")
  tr <- pool; tr$awards <- a; tr$grid <- g
  rbindlist(lapply(seq_len(K), function(f) {
    t2 <- tr; t2$grid <- g[award_key %in% folds[fold != f, award_key]]
    m <- us_impute_fit(t2, cells = cells_of(cfg))
    usaspend:::impute_from_features(a[award_key %in% folds[fold == f, award_key]], m)
  }))
}

score <- function(pr) {
  g <- pool$grid[award_key %in% keys]
  ev <- merge(g[, .(award_key, fy, actual)], pr[, .(award_key, fy, outlay_imputed)],
              by = c("award_key", "fy"), all = TRUE)
  ev[is.na(actual), actual := 0][is.na(outlay_imputed), outlay_imputed := 0]
  sc <- ev[, .(timing = us_misallocation(outlay_imputed, actual),
               level = us_misallocation(outlay_imputed, actual, normalize = FALSE)), by = award_key]
  merge(sc, aw[, .(award_key, population, dur_bin, oblig)], by = "award_key")
}

res <- rbindlist(lapply(names(configs), function(nm) {
  cat(sprintf("%s  fitting %s\n", format(Sys.time(), "%H:%M:%S"), nm)); flush.console()
  score(run_cfg(configs[[nm]]))[, config := nm]
}))

summ <- function(d) d[, .(timing = mean(timing, na.rm = TRUE), level = mean(level, na.rm = TRUE),
                          timing_dw = sum(timing * oblig, na.rm = TRUE) / sum(oblig[!is.na(timing)]))]
tab <- rbindlist(list(
  res[, summ(.SD), by = config][, scope := "all"],
  res[, summ(.SD), by = .(config, population)][, scope := population][, population := NULL],
  res[dur_bin <= 2L, summ(.SD), by = .(config, population)][, scope := paste0(population, " short")][, population := NULL]),
  use.names = TRUE)
wide <- dcast(tab, config ~ scope, value.var = "timing")
base_row <- wide[config == "base"]
for (cc in setdiff(names(wide), "config")) wide[, (cc) := round(get(cc), 4)]
cat("\n== Mean timing misallocation by config (lower is better) ==\n")
print(wide[order(all)])

## ---- paired test of the best config against base ------------------------------
pw <- dcast(res, award_key + population + dur_bin + oblig ~ config, value.var = "timing")
boot <- function(d, a, b, B = 2000) {
  x <- d[[a]] - d[[b]]; x <- x[!is.na(x)]
  bs <- replicate(B, mean(sample(x, replace = TRUE)))
  data.table(n = length(x), gain = round(mean(x), 4),
             lo = round(quantile(bs, .025), 4), hi = round(quantile(bs, .975), 4))
}
cand <- setdiff(wide[order(all)]$config, "base")
tests <- rbindlist(lapply(cand, function(cf) {
  rbind(cbind(config = cf, scope = "all", boot(pw, "base", cf)),
        cbind(config = cf, scope = "pilot", boot(pw[population == "pilot"], "base", cf)),
        cbind(config = cf, scope = "sample", boot(pw[population == "sample"], "base", cf)))
}))
cat("\n== Gain over base (base minus config; positive = config better), 95% bootstrap CI ==\n")
print(tests)

ok <- tests[, .(overall_sig = lo[scope == "all"] > 0,
                worst_pop = min(gain[scope != "all"]),
                gain_all = gain[scope == "all"]), by = config]
ok[, adopt := overall_sig & worst_pop >= -0.005]
cat("\n== Decision rule ==\n"); print(ok[order(-gain_all)])
winner <- ok[(adopt)][order(-gain_all)][1]$config
cat("\nWINNER:", if (length(winner) && !is.na(winner)) winner else "none (keep base)", "\n")

saveRDS(list(results = res, table = tab, tests = tests, decision = ok, winner = winner,
             agency_groups = big, folds = folds),
        file.path(od, "results_cell_split.rds"))
cat("CELL SPLIT COMPLETE\n")
