## Builds the two bundled imputation objects:
##   outlay_training -- File C ground truth pooled from two populations
##     pilot   VUMC + the 50-nonprofit pilot (the original training set:
##             1,184 truth awards, first FY2020+, |oblig| > $50K)
##     sample  a 1,000-organization sample pulled 2026-09-18 (1,611 truth
##             awards, first FY2017+, any size; File C fetched for every
##             in-sample award active FY2017+)
##   outlay_model    -- the default liquidation-curve model fitted on it
##                      (cells: duration x late start x short_family)
##
## Inputs, both snapshots in data-raw/ so the build is reproducible offline:
##   outlay-truth-pilot.rds       the pilot training set as bundled before the
##                                pooling. Its raw pulls are no longer on disk;
##                                the implausible-end-date rule touches none of
##                                its awards (checked), so it is used as is.
##   outlay-truth-sample1000.rds  the sample training set. Rebuilt from the
##                                test database when USASPEND_ROOT is set
##                                (panel + File C chunks; see IMPUTATION.md 7),
##                                and the snapshot refreshed.
## Run from the package root, manually, when either truth set changes.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
as_of <- 2026L

## ---- pilot -------------------------------------------------------------------
pilot <- readRDS("data-raw/outlay-truth-pilot.rds")
pa <- pilot$awards
if (!"pop_end_implausible" %in% names(pa)) {
  pa[, pop_end_fy_reported := pop_end_fy]
  pa[, pop_end_implausible := !is.na(pop_end_fy) & pop_end_fy - last_oblig_fy > 10L]
  stopifnot(!any(pa$pop_end_implausible))   # else duration/tier need recomputing
}
pilot$awards <- with_cell_features(pa)
pilot$grid <- with_cell_features(pilot$grid, pilot$awards)

## ---- sample ------------------------------------------------------------------
root <- Sys.getenv("USASPEND_ROOT")
snap <- "data-raw/outlay-truth-sample1000.rds"
sample <- if (nzchar(root)) {
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
  s10 <- read_stage(file.path(root, "outlay_refit", "filec"))
  fund <- unique(rbindlist(list(s3$funding, s10$funding), use.names = TRUE, fill = TRUE))
  fetched <- union(s3$keys, s10$keys)
  failed <- union(s3$failed, s10$failed)
  p <- readRDS(file.path(root, "outlay_refit", "panel_fiscal_v2.rds"))
  in_sample <- if ("in_sample" %in% names(p$awards)) p$awards[(in_sample), award_key] else p$awards$award_key
  tx <- p$transactions[award_key %in% in_sample & award_key %in% fetched]
  tr <- us_outlay_training(tx, funding = fund, min_first_fy = 2017L, min_oblig = 0,
                           as_of = as_of)
  ## failed fetches are unknown, not "no File C" -- keep them out of the truth
  tr$awards[award_key %in% failed, tier := NA_character_]
  tr$grid <- tr$grid[!award_key %in% failed]
  saveRDS(tr, snap)
  tr
} else readRDS(snap)

## ---- pool --------------------------------------------------------------------
## an award in both sets is kept once, as its (newer) sample record
dup <- intersect(pilot$awards$award_key, sample$awards$award_key)
pilot$awards[, population := "pilot"]
sample$awards[, population := "sample"]
aw <- rbindlist(list(sample$awards, pilot$awards[!award_key %in% dup]),
                use.names = TRUE, fill = TRUE)
gr <- rbindlist(list(sample$grid, pilot$grid[!award_key %in% dup]),
                use.names = TRUE, fill = TRUE)
outlay_training <- structure(list(
  awards = aw[], grid = gr[],
  meta = list(as_of = as_of,
              sources = data.table(
                population = c("pilot", "sample"),
                description = c("VUMC + 50-nonprofit pilot", "1,000-organization sample, pulled 2026-09-18"),
                min_first_fy = c(pilot$meta$min_first_fy, sample$meta$min_first_fy),
                min_oblig = c(pilot$meta$min_oblig, sample$meta$min_oblig),
                truth_awards = c(pilot$awards[!award_key %in% dup & !is.na(tier), .N],
                                 sample$awards[!is.na(tier), .N])),
              overlap_kept_as_sample = length(dup),
              min_first_fy = min(pilot$meta$min_first_fy, sample$meta$min_first_fy),
              min_oblig = min(pilot$meta$min_oblig, sample$meta$min_oblig),
              built_at = Sys.time())),
  class = "usaspend_outlay_training")
print(outlay_training)
print(outlay_training$meta$sources)

outlay_model <- us_impute_fit(outlay_training)
print(outlay_model)

ev <- us_impute_eval(outlay_training)
cat("\nbundled-model CV performance (pooled truth):\n")
print(ev$summary)
cat("\nby population (timing, mean):\n")
print(merge(ev$scores, aw[, .(award_key, population)], by = "award_key")[
  , .(n = .N, timing = round(mean(timing_model, na.rm = TRUE), 3),
      even_spread = round(mean(timing_even_spread, na.rm = TRUE), 3),
      as_obligated = round(mean(timing_as_obligated, na.rm = TRUE), 3)), by = population])

save(outlay_training, file = "data/outlay_training.rda", compress = "xz")
save(outlay_model, file = "data/outlay_model.rda", compress = "xz")
cat("\nsaved data/outlay_training.rda and data/outlay_model.rda\n")
