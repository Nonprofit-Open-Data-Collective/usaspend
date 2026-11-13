## Helpers for the disruption report articles. The charts are plain SVG drawn
## in the browser from tables in data/ (copied from the nonprofit report
## pipeline by data-raw/report_articles.R); everything is inlined, so the built
## page has no extra files to ship.
rf <- function(f) paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
raw_html <- function(x) knitr::asis_output(paste0("\n```{=html}\n", x, "\n```\n"))

report_style <- function(extra = "") raw_html(paste0("<style>\n", rf("report.css"), "\n", extra, "\n</style>"))

## data: named vector, JS constant -> JSON file in data/
report_script <- function(page, data) {
  json <- vapply(data, function(f) gsub("</", "<\\/", rf(file.path("data", f)), fixed = TRUE), "")
  raw_html(paste0("<script>\n(function(){\n",
                  paste0("const ", names(data), " = ", json, ";", collapse = "\n"), "\n",
                  rf("js/common.js"), "\n", rf(file.path("js", paste0(page, ".js"))),
                  "\n})();\n</script>"))
}
