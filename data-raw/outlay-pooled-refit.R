## Copied from the 1,000-organization test database (scripts/11_pooled_refit.R),
## run 2026-09-18. Needs that database: set `root` below. See IMPUTATION.md 7.
## Stage 11: pool the pilot truth (bundled outlay_training) with the 1,000-UEI
## sample's truth and fit one model, with the implausible-pop_end fix
## (us_outlay_features(max_pop_years = 10)) applied to both populations.
##
##   models   bundled   as shipped (pilot, pre-fix features)
##            pilot     refit on pilot truth, fix replayed on stored features
##            sample    refit on sample truth ("all records" screens), fix on
##            pooled    refit on pilot + sample
##   scoring  5-fold CV over the union of award keys: every refit is scored
##            only on awards outside its training folds. Reported separately
##            on pilot awards and sample awards. The bundled model is
##            in-sample on pilot awards (flagged), out-of-sample on sample.
suppressPackageStartupMessages({ library(usaspend); library(data.table) })
root <- "C:/Users/jdlec/Documents/USASPEND"
options(usaspend.cache_dir = root)
od <- file.path(root, "outlay_refit")
set.seed(20260918)
as_of <- 2026L
MAXPOP <- 10L
stopifnot("max_pop_years" %in% names(formals(us_outlay_features)))
cat("usaspend", as.character(packageVersion("usaspend")), "with implausible-pop_end fix\n")

## ---- sample truth, rebuilt with the fix ------------------------------------
read_stage <- function(dir) {
  fcl <- lapply(list.files(dir, "^funding_[0-9]+[.]rds$", full.names = TRUE), readRDS)
  fund <- rbindlist(lapply(fcl, `[[`, "funding"), use.names = TRUE, fill = TRUE)
  keys <- unlist(lapply(fcl, `[[`, "keys"))
  failed <- unlist(lapply(fcl, `[[`, "failed"))
  rf <- file.path(dir, "retry.rds")
  if (file.exists(rf)) {
    rt <- readRDS(rf)
    fund <- rbindlist(list(fund, rt$funding), use.names = TRUE, fill = TRUE)
    failed <- rt$failed
  }
  list(funding = fund, keys = keys, failed = failed)
}
s3  <- read_stage(file.path(root, "imputation_test", "filec"))
s10 <- read_stage(file.path(od, "filec"))
funding <- unique(rbindlist(list(s3$funding, s10$funding), use.names = TRUE, fill = TRUE))
fetched <- union(s3$keys, s10$keys)
failed  <- union(s3$failed, s10$failed)

p  <- readRDS(file.path(od, "panel_fiscal_v2.rds"))
tx <- p$transactions[award_key %in% p$awards[(in_sample), award_key] & award_key %in% fetched]
trS <- suppressMessages(us_outlay_training(tx, funding = funding, min_first_fy = 2017L,
                                           min_oblig = 0, as_of = as_of))
trS$awards[award_key %in% failed, tier := NA_character_]
trS$grid <- trS$grid[!award_key %in% failed]
cat(sprintf("Sample truth (with fix): %d awards; %d candidates flagged pop_end_implausible\n",
            trS$awards[!is.na(tier), .N], trS$awards[, sum(pop_end_implausible, na.rm = TRUE)]))

## ---- pilot truth, fix replayed on the stored features ----------------------
trP <- outlay_training
trP$awards <- copy(outlay_training$awards)
trP$grid <- copy(outlay_training$grid)
pa <- trP$awards
pa[, pop_end_fy_reported := pop_end_fy]
pa[, pop_end_implausible := !is.na(pop_end_fy) & pop_end_fy - last_oblig_fy > MAXPOP]
hit <- pa[(pop_end_implausible), award_key]
hit_truth <- pa[(pop_end_implausible) & !is.na(tier), award_key]
pa[(pop_end_implausible), pop_end_fy := NA_integer_]
## duration and bin exactly as us_outlay_features() derives them
pa[, duration := pmax(pop_end_fy - first_fy + 1L, last_oblig_fy - first_fy + 1L, 1L)]
pa[is.na(duration), duration := last_oblig_fy - first_fy + 1L]
dur_before <- outlay_training$awards[, .(award_key, dur_bin_old = dur_bin)]
pa[, dur_bin := pmin(duration, 6L)]
## tier depends on pop_end_fy only through the shape_complete screen
pas <- trP$meta$as_of
pa[, tier := fcase(
  linked & oblig > 0 & outlay_total >= 0.9 * oblig &
    outlay_total <= 1.1 * oblig & sh_cur <= 0.10,        "reconciled",
  linked & oblig > 0 & first_fy >= 2022L & !is.na(pop_end_fy) &
    pop_end_fy < pas & outlay_total >= 0.25 * oblig &
    sh_cur <= 0.05 & sh_prev <= 0.20,                     "shape_complete",
  default = NA_character_)]
trP$awards <- pa
g <- trP$grid[award_key %in% pa[!is.na(tier), award_key]]
g[, dur_bin := NULL]
g <- merge(g, pa[, .(award_key, dur_bin)], by = "award_key")
## the cash window no longer runs to a placeholder end date
win <- pa[!is.na(tier), .(award_key, y1 = pmax(pop_end_fy, last_outlay_fy, last_oblig_fy, na.rm = TRUE))]
g <- merge(g, win, by = "award_key")[fy <= y1][, y1 := NULL]
trP$grid <- g
chg <- merge(pa[!is.na(tier), .(award_key, dur_bin)], dur_before, by = "award_key")[dur_bin != dur_bin_old]
cat(sprintf(paste0("Pilot truth (fix replayed): %d awards; %d candidates had an implausible end date,\n",
                   "  %d of them truth awards; %d truth awards changed duration bin; truth %d -> %d\n"),
            pa[!is.na(tier), .N], length(hit), length(hit_truth), nrow(chg),
            outlay_training$awards[!is.na(tier), .N], pa[!is.na(tier), .N]))

## ---- pooled training set ---------------------------------------------------
keysP <- pa[!is.na(tier) & oblig > 0, award_key]
keysS <- trS$awards[!is.na(tier) & oblig > 0, award_key]
overlap <- intersect(keysP, keysS)
keysP <- setdiff(keysP, overlap)          # overlapping awards: keep the newer sample record
cols <- intersect(names(trP$awards), names(trS$awards))
pool <- trS
pool$awards <- rbindlist(list(trS$awards[, ..cols], pa[award_key %in% keysP, ..cols]), use.names = TRUE)
gcols <- intersect(names(trP$grid), names(trS$grid))
pool$grid <- rbindlist(list(trS$grid[, ..gcols], trP$grid[award_key %in% keysP, ..gcols]), use.names = TRUE)
pool$awards[, population := fifelse(award_key %in% keysP, "pilot", "sample")]
cat(sprintf("Pooled truth: %d pilot + %d sample = %d awards (%d overlapping kept once, as sample)\n",
            length(keysP), length(keysS), length(keysP) + length(keysS), length(overlap)))

## ---- CV over the union ------------------------------------------------------
K <- 5L
allk <- c(keysP, keysS)
folds <- data.table(award_key = allk, fold = sample(rep_len(seq_len(K), length(allk))))
fit_on <- function(tr, keys) { t2 <- tr; t2$grid <- tr$grid[award_key %in% keys]; us_impute_fit(t2) }
feat_of <- function(keys) pool$awards[award_key %in% keys]
pred <- list(pilot = list(), sample = list(), pooled = list())
for (f in seq_len(K)) {
  out <- folds[fold == f, award_key]
  inn <- folds[fold != f, award_key]
  mods <- list(pilot  = fit_on(pool, intersect(inn, keysP)),
               sample = fit_on(pool, intersect(inn, keysS)),
               pooled = fit_on(pool, inn))
  for (nm in names(mods)) {
    pred[[nm]][[f]] <- usaspend:::impute_from_features(feat_of(out), mods[[nm]])
  }
}
pred <- lapply(pred, rbindlist)
pred$bundled <- usaspend:::impute_from_features(feat_of(allk), outlay_model)

score_awards <- function(training, pr, keys) {
  g  <- training$grid[oblig > 0 & award_key %in% keys]
  aw <- training$awards[award_key %in% g$award_key]
  ev <- merge(g[, .(award_key, fy, actual, oblig_fy)],
              pr[award_key %in% g$award_key, .(award_key, fy, outlay_imputed)],
              by = c("award_key", "fy"), all = TRUE)
  ev <- merge(ev, aw[, .(award_key, first_fy, pop_end_fy, last_oblig_fy)], by = "award_key")
  for (cc in c("actual", "oblig_fy", "outlay_imputed")) ev[is.na(get(cc)), (cc) := 0]
  ev[, "pop_n" := pmax(pmax(pop_end_fy, last_oblig_fy, na.rm = TRUE) - first_fy + 1L, 1L)]
  ev[, "in_pop" := fy >= first_fy & fy < first_fy + pop_n]
  sc <- ev[, {
    even <- sum(oblig_fy) * as.numeric(in_pop) / max(sum(in_pop), 1)
    .(timing = us_misallocation(outlay_imputed, actual),
      level = us_misallocation(outlay_imputed, actual, normalize = FALSE),
      timing_as_obligated = us_misallocation(pmax(oblig_fy, 0), actual),
      timing_even_spread = us_misallocation(even, actual))
  }, by = award_key]
  merge(sc, aw[, .(award_key, oblig, dur_bin, mod_class, population)], by = "award_key")
}
sc <- rbindlist(lapply(names(pred), function(nm) score_awards(pool, pred[[nm]], allk)[, model := nm]))

tab <- sc[, .(n = .N,
              timing = round(mean(timing, na.rm = TRUE), 3),
              timing_dw = round(sum(timing * oblig, na.rm = TRUE) / sum(oblig[!is.na(timing)]), 3),
              level = round(mean(level, na.rm = TRUE), 3),
              level_dw = round(sum(level * oblig, na.rm = TRUE) / sum(oblig[!is.na(level)]), 3)),
          by = .(population, model)]
refs <- sc[model == "pooled", .(model = c("even_spread", "as_obligated"),
                                timing = round(c(mean(timing_even_spread, na.rm = TRUE),
                                                 mean(timing_as_obligated, na.rm = TRUE)), 3)),
           by = population]
tab[, note := fcase(model == "bundled" & population == "pilot", "IN-SAMPLE (fit on these awards)",
                    model == "pilot" & population == "sample", "external",
                    model == "sample" & population == "pilot", "external",
                    default = "out-of-fold")]
cat("\n== Misallocation by population (lower is better) ==\n")
print(tab[order(population, timing)])
cat("\nReference rules (timing mean):\n"); print(refs)

## paired differences with bootstrap CIs
wide <- dcast(sc, award_key + population + oblig + dur_bin ~ model, value.var = c("timing", "level"))
boot_diff <- function(a, b, w, B = 2000) {
  ok <- !is.na(a) & !is.na(b); a <- a[ok]; b <- b[ok]; w <- w[ok]
  st <- function(i, ww) sum((a[i] - b[i]) * ww[i]) / sum(ww[i])
  one <- rep(1, length(a))
  e1 <- st(seq_along(a), one); e2 <- st(seq_along(a), w)
  b1 <- replicate(B, { i <- sample.int(length(a), replace = TRUE); c(st(i, one), st(i, w)) })
  data.table(n = length(a), per_award = round(e1, 3),
             ci = sprintf("[%.3f, %.3f]", quantile(b1[1, ], .025), quantile(b1[1, ], .975)),
             dollar = round(e2, 3),
             ci_dollar = sprintf("[%.3f, %.3f]", quantile(b1[2, ], .025), quantile(b1[2, ], .975)))
}
cmp <- rbindlist(list(
  cbind(population = "sample", comparison = "bundled - pooled", metric = "timing",
        wide[population == "sample", boot_diff(timing_bundled, timing_pooled, oblig)]),
  cbind(population = "sample", comparison = "sample - pooled", metric = "timing",
        wide[population == "sample", boot_diff(timing_sample, timing_pooled, oblig)]),
  cbind(population = "pilot", comparison = "pilot - pooled", metric = "timing",
        wide[population == "pilot", boot_diff(timing_pilot, timing_pooled, oblig)]),
  cbind(population = "pilot", comparison = "sample - pooled", metric = "timing",
        wide[population == "pilot", boot_diff(timing_sample, timing_pooled, oblig)]),
  cbind(population = "sample", comparison = "bundled - pooled", metric = "level",
        wide[population == "sample", boot_diff(level_bundled, level_pooled, oblig)]),
  cbind(population = "pilot", comparison = "pilot - pooled", metric = "level",
        wide[population == "pilot", boot_diff(level_pilot, level_pooled, oblig)])))
cat("\n== Paired differences (positive = pooled better), 95% bootstrap CI ==\n"); print(cmp)

cat("\nTiming by duration bin and population:\n")
print(dcast(sc[, .(m = round(mean(timing, na.rm = TRUE), 3), n = .N), by = .(population, dur_bin, model)],
            population + dur_bin ~ model, value.var = "m")[order(population, dur_bin)])

## ---- curves ------------------------------------------------------------------
mP <- fit_on(pool, keysP); mS <- fit_on(pool, keysS); mPool <- us_impute_fit(pool)
curve_tab <- function(m, nm) m$curves_dur[, .(level = sum(share), n = max(n)), by = dur_bin][, model := nm]
ct <- rbindlist(list(curve_tab(outlay_model, "bundled"), curve_tab(mP, "pilot"),
                     curve_tab(mS, "sample"), curve_tab(mPool, "pooled")))
cat("\n== Curves by duration: support (n) and level (curve sum) ==\n")
print(dcast(ct, dur_bin ~ model, value.var = c("n", "level"), fun.aggregate = function(v) round(v[1], 3)))
tdist <- function(m1, m2) {
  x <- merge(m1$curves_dur[, .(dur_bin, t, s1 = share)], m2$curves_dur[, .(dur_bin, t, s2 = share)],
             by = c("dur_bin", "t"), all = TRUE)
  x[is.na(s1), s1 := 0][is.na(s2), s2 := 0]
  x[, .(d = round(0.5 * sum(abs(s1 / max(sum(s1), 1e-9) - s2 / max(sum(s2), 1e-9))), 3)), by = dur_bin]
}
cat("\nCurve shape distance by duration (0 = identical, 1 = disjoint):\n")
print(Reduce(function(a, b) merge(a, b, by = "dur_bin"), list(
  setnames(tdist(outlay_model, mPool), "d", "bundled_vs_pooled"),
  setnames(tdist(mS, mPool), "d", "sample_vs_pooled"),
  setnames(tdist(mP, mPool), "d", "pilot_vs_pooled"),
  setnames(tdist(outlay_model, mP), "d", "bundled_vs_pilotfix"))))

## ---- the sample panel under each model ----------------------------------------
imp <- function(m) suppressMessages(us_add_imputed_outlays(p, model = m))$panel
pb <- imp(outlay_model); ps <- imp(mS); pp <- imp(mPool)
yr <- Reduce(function(a, b) merge(a, b, by = "year", all = TRUE), list(
  pb[, .(obligation_net = sum(obligation_net), bundled = sum(outlay_imputed)), by = year],
  ps[, .(sample = sum(outlay_imputed)), by = year],
  pp[, .(pooled = sum(outlay_imputed)), by = year]))
for (cc in names(yr)[-1]) yr[is.na(get(cc)), (cc) := 0]
cat("\n== Sample panel, imputed outlays by fiscal year ($M) ==\n")
print(yr[, lapply(.SD, function(v) round(v / 1e6, 1)), by = year][order(year)])
between <- function(a, b, lab) {
  x <- merge(a[, .(ra = sum(outlay_imputed)), by = .(award_key, year)],
             b[, .(rb = sum(outlay_imputed)), by = .(award_key, year)], by = c("award_key", "year"), all = TRUE)
  x[is.na(ra), ra := 0][is.na(rb), rb := 0]
  data.table(comparison = lab,
             cash_in_different_year = round(0.5 * sum(abs(x$rb * sum(x$ra) / sum(x$rb) - x$ra)) / sum(x$ra), 3),
             total_diff_pct = round(100 * (sum(x$rb) / sum(x$ra) - 1), 1),
             cash_after_fy2035_M = round(sum(x[year > 2035, rb]) / 1e6, 2))
}
cat("\nBetween-model divergence on the panel:\n")
print(rbind(between(pb, pp, "bundled -> pooled"), between(ps, pp, "sample -> pooled"),
            between(pb, ps, "bundled -> sample")))
cat(sprintf("Max imputed year: bundled %d | sample %d | pooled %d\n",
            max(pb$year), max(ps$year), max(pp$year)))

saveRDS(list(table = tab, refs = refs, paired = cmp, scores = sc, curves = ct, years = yr,
             models = list(pilot = mP, sample = mS, pooled = mPool),
             pooled_training = pool, pilot_fix = list(hit = hit, hit_truth = hit_truth, dur_changed = chg)),
        file.path(od, "results_pooled.rds"))
saveRDS(mPool, file.path(od, "outlay_model_pooled.rds"))
cat("\nPOOLED COMPLETE\n")
