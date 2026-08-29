# Outlay imputation: features, fitting, evaluation, imputation with the
# support-envelope fallback, and the panel append. Offline throughout --
# fitting uses the bundled training data.

test_that("us_outlay_features classifies the modification taxonomy", {
  tx <- us_normalize_transactions(us_sample_extract()$transactions)
  f <- us_outlay_features(tx)
  expect_true(all(c("first_fy", "duration", "dur_bin", "late_start",
                    "mod_class", "oblig") %in% names(f)))
  expect_equal(nrow(f), data.table::uniqueN(tx$award_key))
  expect_true(all(f$mod_class %in% c("reduced", "extension_funded",
                                     "extension_timeline",
                                     "multi_year_incremental", "single_year")))
  expect_true(all(f$dur_bin >= 1 & f$dur_bin <= 6))
  # net = gross positive + gross negative
  expect_equal(f$oblig, f$oblig_positive + f$oblig_negative)
})

test_that("the bundled model is coherent", {
  m <- outlay_model
  expect_s3_class(m, "usaspend_outlay_model")
  # each supported duration curve sums to a plausible liquidation ratio
  sums <- m$curves_dur[dur_bin %in% m$support[n_awards >= m$min_cell]$dur_bin,
                       .(s = sum(share)), by = dur_bin]
  expect_true(all(sums$s > 0.5 & sums$s < 1.3))
  expect_true(m$global_ratio > 0.7 && m$global_ratio < 1.1)
})

test_that("us_impute_fit reproduces the bundled model from bundled training", {
  m <- us_impute_fit(outlay_training)
  expect_equal(m$global_ratio, outlay_model$global_ratio)
  expect_equal(m$curves_dur$share, outlay_model$curves_dur$share)
})

test_that("us_misallocation behaves at the boundaries", {
  expect_equal(us_misallocation(c(10, 90), c(10, 90)), 0)
  expect_equal(us_misallocation(c(90, 10), c(10, 90)), 0.8)
  # normalization isolates timing: scaled series scores identically
  expect_equal(us_misallocation(c(5, 45), c(10, 90)), 0)
  # without normalization the level gap is charged
  expect_equal(us_misallocation(c(5, 45), c(10, 90), normalize = FALSE), 0.25)
  expect_true(is.na(us_misallocation(c(1, 1), c(0, 0))))
})

test_that("imputation uses the model inside the envelope, even spread outside", {
  tx <- us_normalize_transactions(us_sample_extract()$transactions)
  imp <- suppressMessages(us_impute_outlays(tx))
  expect_true(all(c("outlay_imputed", "imputation_method", "imputation_flags")
                  %in% names(imp)))
  # never NA dollars
  expect_false(anyNA(imp$outlay_imputed))
  f <- us_outlay_features(tx)
  sup <- outlay_model$support[n_awards >= outlay_model$min_cell]$dur_bin
  per_award <- unique(imp[, .(award_key, imputation_method)])
  m <- merge(per_award, f[, .(award_key, dur_bin, oblig)], by = "award_key")
  # positive-obligation awards with supported durations use the curve
  expect_true(all(m[oblig > 0 & dur_bin %in% sup,
                    imputation_method] == "liquidation_curve"))
  # unsupported durations fall back, flagged
  out_env <- m[oblig > 0 & !dur_bin %in% sup]
  if (nrow(out_env)) {
    expect_true(all(out_env$imputation_method == "even_spread"))
    expect_true(all(grepl("duration_outside_support",
                          imp[award_key %in% out_env$award_key, imputation_flags])))
  }
  # nonpositive obligations impute zero, not NA
  expect_true(all(imp[imputation_method == "none", outlay_imputed] == 0))
})

test_that("model totals equal curve sums; even-spread totals equal ratio x oblig", {
  tx <- us_normalize_transactions(us_sample_extract()$transactions)
  f <- us_outlay_features(tx)
  imp <- suppressMessages(us_impute_outlays(tx))
  tot <- imp[, .(imputed = sum(outlay_imputed)), by = .(award_key, imputation_method)]
  tot <- merge(tot, f[, .(award_key, oblig)], by = "award_key")
  ev <- tot[imputation_method == "even_spread"]
  expect_equal(ev$imputed, outlay_model$global_ratio * ev$oblig, tolerance = 1e-9)
  # curve totals: within the ratio's plausible band, proportional to oblig
  lc <- tot[imputation_method == "liquidation_curve"]
  expect_true(all(lc$imputed / lc$oblig > 0.4 & lc$imputed / lc$oblig < 1.3))
})

test_that("us_impute_eval returns both metrics and beats the baselines", {
  ev <- suppressMessages(us_impute_eval(outlay_training, folds = 3L))
  expect_setequal(unique(ev$summary$metric), c("timing", "level"))
  s <- ev$summary
  expect_lt(s[metric == "timing" & method == "model", mean],
            s[metric == "timing" & method == "even_spread", mean])
  expect_lt(s[metric == "level" & method == "model", mean],
            s[metric == "level" & method == "as_obligated", mean])
  expect_true(all(c("mod_class", "model", "even_spread") %in% names(ev$by_class)))
})

test_that("us_add_imputed_outlays appends without touching money measures", {
  p <- suppressMessages(us_panel(us_sample_extract(), period = "fiscal"))
  p2 <- suppressMessages(us_add_imputed_outlays(p))
  pp <- p2$panel
  expect_true(all(c("outlay_imputed", "imputation_method") %in% names(pp)))
  expect_equal(pp[flags != "imputed_outlay_only_year", sum(obligation_net)],
               p$panel[, sum(obligation_net)])
  # imputed dollars conserved between the award-level table and the panel
  imp <- suppressMessages(us_impute_outlays(p$transactions))
  expect_equal(pp[, sum(outlay_imputed)],
               imp[award_key %in% unique(p$panel$award_key), sum(outlay_imputed)],
               tolerance = 1e-9)
  expect_false(anyNA(pp$outlay_imputed))
  # calendar panels refuse
  pc <- suppressMessages(us_panel(us_sample_extract()))
  expect_error(us_add_imputed_outlays(pc), "fiscal")
})
