# Internal HTTP client for the EliteForm v2 API: auth, paging, rate limits, errors and row conversion.

ef_page_size <- 1000
ef_max_attempts <- 4
# A 429 from the per-minute window is worth waiting out; the hourly and daily ones are not.
ef_max_wait_seconds <- 120

# Objects flattened into columns, listed here because a null object says nothing about its fields.
ef_flattened_objects <- list(
  target = c("metric", "basis", "min", "max"),
  classification = c("id", "name")
)

ef_date <- function(date) {
  parsed <- tryCatch(
    as.Date(date, tryFormats = c("%m/%d/%Y", "%m-%d-%Y", "%m%d%Y",
                                 "%Y/%m/%d", "%Y-%m-%d", "%Y%m%d")),
    error = function(e) NA
  )
  if (length(parsed) != 1 || is.na(parsed)) {
    stop("Invalid date. Please use a recognizable format like YYYY-MM-DD or MM/DD/YYYY.", call. = FALSE)
  }
  parsed
}

ef_check_filters <- function(filters) {
  if (length(filters) > 0 && (is.null(names(filters)) || any(names(filters) == ""))) {
    stop("Filters passed through ... must be named, e.g. athleteId = 6.", call. = FALSE)
  }
  filters
}

# The API takes a window on the workout day, so one day is that day up to (not including) the next.
ef_date_window <- function(date, filters) {
  bounds <- intersect(c("dateAfter", "dateBefore"), names(filters))
  if (length(bounds) > 0) {
    if (!identical(date, "")) {
      stop("Pass either date or dateAfter/dateBefore, not both.", call. = FALSE)
    }
    return(filters)
  }
  day <- if (identical(date, "")) Sys.Date() else ef_date(date)
  filters$dateAfter <- day
  filters$dateBefore <- day + 1
  filters
}

ef_team_filter <- function(token, filters) {
  if (is.null(filters$teamId) && !is.na(token@TEAM_ID)) {
    filters$teamId <- token@TEAM_ID
  }
  filters
}

ef_query_value <- function(name, value) {
  if (name %in% c("dateAfter", "dateBefore", "asOf")) {
    return(format(ef_date(value), "%Y-%m-%d"))
  }
  if (is.logical(value)) {
    return(tolower(as.character(value)))
  }
  if (is.numeric(value)) {
    value <- format(value, scientific = FALSE, trim = TRUE)
  }
  paste(value, collapse = ",")
}

ef_query <- function(filters) {
  filters <- filters[!vapply(filters, is.null, logical(1))]
  stats::setNames(lapply(names(filters), function(name) ef_query_value(name, filters[[name]])), names(filters))
}

ef_request <- function(token, path, query) {
  response <- httr::GET(
    url = paste0(token@url, path),
    query = query,
    httr::add_headers(Authorization = paste("Bearer", token@api_key), Accept = "application/json")
  )
  list(
    status = httr::status_code(response),
    retry_after = httr::headers(response)[["retry-after"]],
    body = httr::content(response, as = "text", encoding = "UTF-8")
  )
}

ef_error_message <- function(response) {
  problem <- tryCatch(jsonlite::fromJSON(response$body, simplifyVector = FALSE), error = function(e) list())
  detail <- if (is.list(problem)) problem$detail else NULL
  if (is.null(detail)) {
    detail <- "The API returned no further detail."
  }
  request <- if (is.list(problem) && !is.null(problem$instance)) paste0(" (", problem$instance, ")") else ""
  paste0("EliteForm API error ", response$status, ": ", detail, request)
}

ef_get <- function(token, path, query = list()) {
  for (attempt in seq_len(ef_max_attempts)) {
    response <- ef_request(token, path, query)
    if (response$status != 429) {
      break
    }
    wait <- suppressWarnings(as.numeric(response$retry_after))
    if (length(wait) != 1 || is.na(wait) || wait > ef_max_wait_seconds || attempt == ef_max_attempts) {
      break
    }
    message("EliteForm rate limit reached, waiting ", wait, " seconds.")
    Sys.sleep(wait)
  }
  if (response$status >= 400) {
    stop(ef_error_message(response), call. = FALSE)
  }
  jsonlite::fromJSON(response$body, simplifyVector = FALSE)
}

# Follows page.nextCursor to the end and returns every row as one data frame.
ef_get_all <- function(token, path, filters = list()) {
  query <- ef_query(filters)
  if (is.null(query[["page[size]"]])) {
    query[["page[size]"]] <- format(ef_page_size, scientific = FALSE)
  }
  pages <- list()
  repeat {
    page <- ef_get(token, path, query)
    pages[[length(pages) + 1]] <- page$data
    if (!isTRUE(page$page$hasMore)) {
      break
    }
    query[["page[after]"]] <- page$page$nextCursor
  }
  ef_rows_to_df(do.call(c, pages))
}

ef_scalar_column <- function(values) {
  unlist(lapply(values, function(value) if (is.null(value)) NA else value))
}

ef_rows_to_df <- function(rows) {
  if (length(rows) == 0) {
    return(data.frame())
  }
  df <- data.frame(row.names = seq_along(rows))
  for (field in names(rows[[1]])) {
    values <- lapply(rows, function(row) row[[field]])
    if (field %in% names(ef_flattened_objects)) {
      for (part in ef_flattened_objects[[field]]) {
        name <- paste0(field, toupper(substr(part, 1, 1)), substr(part, 2, nchar(part)))
        df[[name]] <- ef_scalar_column(lapply(values, function(value) value[[part]]))
      }
    } else if (any(vapply(values, is.list, logical(1)))) {
      df[[field]] <- lapply(values, ef_rows_to_df)
    } else {
      df[[field]] <- ef_scalar_column(values)
    }
  }
  df
}

ef_collapse_names <- function(tables) {
  vapply(tables, function(table) {
    if (nrow(table) == 0) NA_character_ else paste(table$name, collapse = ", ")
  }, character(1))
}
