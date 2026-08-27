## Thin httr2 wrapper around the USAspending REST API.
##
## Every call is throttled and retried. Two failure modes are treated
## differently on purpose:
##   * transport / 5xx  -> retried, then surfaced as a condition
##   * a swallowed error -> never. A failed request must not be readable as
##     "this recipient has no awards", which is the single most dangerous bug
##     in this pipeline.

us_url <- function(path) paste0(sub("/$", "", us_opt("base_url")), "/", sub("^/", "", path))

us_req <- function(path) {
  httr2::request(us_url(path)) |>
    httr2::req_user_agent("usaspend R package (https://github.com/Nonprofit-Open-Data-Collective/usaspend)") |>
    httr2::req_timeout(us_opt("timeout")) |>
    httr2::req_throttle(rate = us_opt("throttle")) |>
    httr2::req_retry(max_tries = us_opt("max_tries"), backoff = function(i) 3 * 2^i)
}

#' Call the USAspending API
#'
#' Low-level access, exported so that endpoints this package does not wrap are
#' still reachable without hand-rolling a client.
#'
#' @param path Endpoint path below `/api/v2`, e.g. `"search/spending_by_award_count/"`.
#' @param body Named list sent as JSON. If `NULL`, a GET is performed.
#' @param query Named list of query-string parameters (GET only).
#' @return The parsed JSON response as a list.
#' @export
#' @examples
#' \dontrun{
#' us_api("search/spending_by_award_count/", body = list(
#'   filters = list(recipient_search_text = I("CFFMYPABYAG3"))
#' ))
#' }
us_api <- function(path, body = NULL, query = NULL) {
  req <- us_req(path)
  if (!is.null(body))  req <- httr2::req_body_json(req, body)
  if (!is.null(query)) req <- httr2::req_url_query(req, !!!query)
  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp)
}

## Like us_api() but returns a structured outcome instead of throwing, so that
## batch loops can record failures explicitly (see gotcha 8 in EXTRACT-PLAN.md).
us_api_try <- function(path, body = NULL, query = NULL) {
  out <- tryCatch(
    list(ok = TRUE, result = us_api(path, body, query), error = NA_character_),
    error = function(e) list(ok = FALSE, result = NULL, error = conditionMessage(e))
  )
  out
}

## Page through an endpoint that uses {page, limit} + page_metadata$hasNext.
us_api_pages <- function(path, body, limit = 100, max_pages = Inf) {
  acc <- list(); page <- 1L
  repeat {
    b <- utils::modifyList(body, list(page = page, limit = limit))
    r <- us_api(path, body = b)
    res <- r$results %||% list()
    acc[[length(acc) + 1L]] <- res
    has_next <- isTRUE(r$page_metadata$hasNext)
    if (!has_next || length(res) == 0L || page >= max_pages) break
    page <- page + 1L
  }
  do.call(c, acc)
}

## Coerce a list-of-lists API payload into a data.table without letting NULLs
## collapse rows (rbindlist drops them; we want explicit NA).
rows_to_dt <- function(x, cols = NULL) {
  if (length(x) == 0L) {
    if (is.null(cols)) return(data.table::data.table())
    return(stats::setNames(
      data.table::as.data.table(rep(list(character(0)), length(cols))), cols))
  }
  flat <- lapply(x, function(r) lapply(r, function(v) if (is.null(v)) NA else if (length(v) > 1L) paste(unlist(v), collapse = "|") else v))
  data.table::rbindlist(flat, fill = TRUE, use.names = TRUE)
}
