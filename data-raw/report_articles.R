## Sync the nonprofit disruption report into the pkgdown articles.
##
## The three articles in vignettes/articles/ (disruption-2025, disruption-ledger,
## obligation-trends) knit from pre-computed tables, because the full nonprofit
## database they summarize is not shipped with the package. This script copies
## those tables and the chart code from the report pipeline:
##
##   tables  NONPROFIT/report/*.json   (stages 22-27, 29, 30)
##   charts  NONPROFIT/report/src/*.html, common.js, pay.js
##
## Rerun it after rebuilding any report stage, then rebuild the site.

rd  <- "C:/Users/jdlec/Documents/USASPEND/NONPROFIT/report"
out <- "vignettes/articles"
dir.create(file.path(out, "data"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(out, "js"), showWarnings = FALSE)

rl <- function(f) readLines(f, warn = FALSE, encoding = "UTF-8")
wl <- function(x, f) { con <- file(f, "w", encoding = "UTF-8"); writeLines(x, con); close(con) }

## tables
for (f in c("report_tables", "payment_tables", "visuals_tables", "trends_tables"))
  file.copy(file.path(rd, paste0(f, ".json")), file.path(out, "data", paste0(f, ".json")),
            overwrite = TRUE)

## chart code: everything in the page's second <script> after its data line
page_js <- function(page) {
  h <- rl(file.path(rd, "src", paste0(page, ".html")))
  i <- grep("^const [A-Z] = /\\*__[A-Z]+__\\*/;", h)
  j <- max(grep("^</script>", h))
  stopifnot(length(i) == 1, j > i)
  js <- h[(i + 1):(j - 1)]
  k <- grep("/*__PAYJS__*/", js, fixed = TRUE)          # main report: payment section
  if (length(k)) {
    pay <- rl(file.path(rd, "src", "pay.js"))
    pay <- pay[!grepl("^const P = /\\*__PAY__\\*/;", pay)]
    js <- c(js[seq_len(k - 1)], pay, js[-seq_len(k)])
  }
  js
}
file.copy(file.path(rd, "src", "common.js"), file.path(out, "js", "common.js"), overwrite = TRUE)
for (p in c("disruption", "visuals", "trends")) wl(page_js(p), file.path(out, "js", paste0(p, ".js")))

cat("synced", length(list.files(file.path(out, "data"))), "tables and",
    length(list.files(file.path(out, "js"))), "scripts\n")
