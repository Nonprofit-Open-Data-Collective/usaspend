## Builds vignettes/data-dictionary/pilot-descriptives.csv: the 50-nonprofit
## pilot summarized by award group x family x type, with real outbound
## pass-through. Run manually when the pilot extract is refreshed; the
## data-dictionary vignette reads the CSV so it can build offline.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressMessages(library(data.table))
pilot <- "C:/Users/jdlec/Dropbox/00 - URBAN/00-GITHUB/npmatch/data-dev/usaspending/pilot"

ueis <- unique(fread(file.path(pilot, "PILOT-UEI-PULLLIST.csv"), colClasses = "character")$uei)
parts <- read_download_dir(file.path(pilot, "raw"))
sb_out <- fread(file.path(pilot, "SUBAWARDS-OUT.csv"), colClasses = "character")
num_cols <- c("subaward_amount", "prime_award_amount", "prime_award_total_outlayed")
for (cc in intersect(num_cols, names(sb_out))) sb_out[, (cc) := as.numeric(get(cc))]
date_cols <- c("subaward_action_date", "report_last_modified")
for (cc in intersect(date_cols, names(sb_out))) sb_out[, (cc) := as.Date(get(cc))]
int_cols <- c("subaward_year", "subaward_fiscal_year", "report_year", "report_month")
for (cc in intersect(int_cols, names(sb_out))) sb_out[, (cc) := as.integer(get(cc))]

ex <- list(transactions = parts$transactions,
           subawards = rbindlist(list(parts$subawards, sb_out), use.names = TRUE, fill = TRUE),
           meta = list(uei = ueis, subawards = "both"))
p <- us_panel(ex, fill_gaps = TRUE)

d <- p$panel[, .(
  n_transactions      = sum(n_transactions),
  n_awards            = uniqueN(award_key),
  obligation_positive = sum(obligation_positive),
  obligation_negative = sum(obligation_negative),
  obligation_net      = sum(obligation_net),
  subaward_out        = sum(subaward_out_amount),
  net_revenue         = sum(net_revenue)
), by = .(award_group, award_family, award_type_code, award_type_label)]
setorder(d, award_group, award_family, award_type_code)
fwrite(d, "vignettes/data-dictionary/pilot-descriptives.csv")
print(d)
cat("\nTOTAL net_revenue:", format(sum(d$net_revenue), big.mark = ","), "\n")
