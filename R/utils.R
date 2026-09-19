`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

## cli evaluates {} interpolation in .envir, which defaults to the caller of
## cli_abort() -- that is, this wrapper. Without forwarding the real caller's
## frame, every message referencing a local variable fails at format time.
us_abort <- function(msg, ..., class = NULL, .envir = parent.frame()) {
  cli::cli_abort(msg, ..., class = c(class, "usaspend_error"), .envir = .envir)
}

#' Signal that a function is a documented placeholder
#'
#' Normalization and accounting functions are specified in `ACCOUNTING.md` but
#' not yet implemented -- they are being written against the 50-nonprofit pilot
#' extract. Each stub validates its arguments and then calls this, so callers
#' fail loudly and early rather than silently receiving an empty result.
#'
#' @param fn Function name.
#' @param section Section of `ACCOUNTING.md` holding the specification.
#' @noRd
us_todo <- function(fn, section) {
  us_abort(
    c("{.fn {fn}} is a placeholder and is not implemented yet.",
      "i" = "Its accounting rules are specified in ACCOUNTING.md {section}.",
      "i" = "It will be implemented against the 50-nonprofit pilot extract."),
    class = "usaspend_not_implemented"
  )
}

## --- coercion helpers -------------------------------------------------------
## USAspending CSVs are read as character so that nothing is silently mangled
## on the way in; every cast is explicit and failures become NA, never errors.

## Read a USAspending CSV as all-character. The files are RFC 4180: comma
## separated, free text double-quoted, embedded quotes doubled, and embedded
## newlines allowed inside quotes (subaward descriptions routinely have them).
## fread gets two things wrong on these:
##   1. Its dialect sniffer is fooled when a file has few rows and a quoted
##      multi-line field whose continuation lines contain commas -- it reports
##      "improper quoting", finds 2 columns, and returns garbage or stops early.
##      Pinning sep/quote is not enough on its own, so the result is checked
##      against the header's field count and any warning, and on failure the
##      file is re-read with utils::read.csv, which parses RFC 4180 correctly.
##   2. It never un-escapes doubled quotes: `"say ""hi"""` comes back as
##      `say ""hi""`. In a correctly quoted file a literal `""` can only be an
##      escaped quote, so collapsing them afterwards is exact.
us_read_csv <- function(f) {
  if (!file.size(f)) return(data.table::data.table())
  n_hdr <- length(scan(f, what = "", sep = ",", quote = "\"", nlines = 1L,
                       quiet = TRUE, encoding = "UTF-8"))
  warned <- FALSE
  dt <- tryCatch(withCallingHandlers(
    data.table::fread(f, sep = ",", quote = "\"", header = TRUE, fill = FALSE,
                      colClasses = "character", encoding = "UTF-8",
                      showProgress = FALSE),
    warning = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }), error = function(e) NULL)

  if (is.null(dt) || warned || ncol(dt) != n_hdr) {
    dt <- data.table::as.data.table(utils::read.csv(
      f, colClasses = "character", check.names = FALSE, encoding = "UTF-8",
      strip.white = TRUE))  # as fread: trims unquoted fields only
    if (ncol(dt) != n_hdr) {
      us_abort("Could not parse {.file {f}}: header has {n_hdr} field{?s}, data has {ncol(dt)}.")
    }
    return(dt[])
  }
  for (j in which(vapply(dt, function(x) any(grepl("\"\"", x, fixed = TRUE)), TRUE))) {
    data.table::set(dt, j = j, value = gsub("\"\"", "\"", dt[[j]], fixed = TRUE))
  }
  dt[]
}

as_num <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  x <- trimws(as.character(x))
  x[x == "" | x == "NA"] <- NA_character_
  suppressWarnings(as.numeric(gsub("[$,]", "", x)))
}

as_int <- function(x) {
  v <- as_num(x)
  suppressWarnings(as.integer(round(v)))
}

as_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  x <- trimws(as.character(x))
  x[x == "" | x == "NA"] <- NA_character_
  as.Date(substr(x, 1L, 10L), format = "%Y-%m-%d")
}

as_chr <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x
}

## Uppercase, whitespace-stripped UEI. USAspending is case-inconsistent and the
## crosswalk is not, so every join key goes through this.
clean_uei <- function(x) {
  x <- toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
  x[x == ""] <- NA_character_
  x
}

#' Validate a vector of UEIs
#'
#' A SAM.gov Unique Entity Identifier is 12 alphanumeric characters. This checks
#' shape only -- it cannot tell you whether an entity exists.
#'
#' @param uei Character vector of UEIs.
#' @param strict If `TRUE` (default), malformed UEIs raise an error. If `FALSE`,
#'   they are returned as `NA` with a warning.
#' @return Character vector of cleaned UEIs, same length as `uei`.
#' @export
#' @examples
#' us_validate_uei("cffmypabyag3")
us_validate_uei <- function(uei, strict = TRUE) {
  x <- clean_uei(uei)
  bad <- !is.na(x) & nchar(x) != 12L
  bad <- bad | (is.na(x) & !is.na(uei))
  if (any(bad)) {
    offenders <- unique(uei[bad])
    if (strict) {
      us_abort(c("{sum(bad)} UEI{?s} {?is/are} not 12 alphanumeric characters.",
                 "x" = "{.val {utils::head(offenders, 5)}}"),
               class = "usaspend_bad_uei")
    }
    cli::cli_warn("Dropping {sum(bad)} malformed UEI{?s}: {.val {utils::head(offenders, 5)}}")
    x[bad] <- NA_character_
  }
  x
}

## Split a vector into chunks of at most `size`.
chunk <- function(x, size) {
  if (length(x) == 0L) return(list())
  unname(split(x, ceiling(seq_along(x) / size)))
}

## Fiscal year for a date (federal FY starts 1 October).
fiscal_year <- function(d) {
  d <- as_date(d)
  as.integer(format(d, "%Y")) + (as.integer(format(d, "%m")) >= 10L)
}

calendar_year <- function(d) as.integer(format(as_date(d), "%Y"))
