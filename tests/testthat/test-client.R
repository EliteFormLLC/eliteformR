test_token <- function(team = 7) {
  EF_UpdateTokenTeam(EF_CreateAPIToken("ef_live_ABC_secret", "https://api.test/"), team)
}

json_page <- function(rows, cursor = NULL) {
  list(status = 200, retry_after = NULL, body = jsonlite::toJSON(
    list(data = rows, page = list(hasMore = !is.null(cursor), nextCursor = cursor)),
    auto_unbox = TRUE, null = "null"
  ))
}

# Answers each request with the next response and records the queries it was sent.
fake_api <- function(...) {
  responses <- list(...)
  calls <- list()
  list(
    request = function(token, path, query) {
      calls[[length(calls) + 1]] <<- list(path = path, query = query)
      response <- responses[[length(calls)]]
      if (is.character(response)) json_page(list()) else response
    },
    calls = function() calls
  )
}

test_that("the token takes a v2 key and refuses the old argument order", {
  token <- EF_CreateAPIToken("ef_live_ABC_secret")
  expect_equal(token@url, "https://api.eliteform.com")
  expect_true(is.na(token@TEAM_ID))
  expect_equal(test_token()@url, "https://api.test")
  expect_error(EF_CreateAPIToken("https://your.eliteform.com", "ef_live_ABC_secret"), "starts with 'ef_'")
  expect_error(EF_CreateAPIToken("legacy-key"), "starts with 'ef_'")
})

test_that("dates are read in every format v1 accepted", {
  for (date in c("07/28/2025", "07-28-2025", "07282025", "2025/07/28", "2025-07-28", "20250728")) {
    expect_equal(ef_date(date), as.Date("2025-07-28"))
  }
  expect_equal(ef_date(as.Date("2025-07-28")), as.Date("2025-07-28"))
  expect_error(ef_date("not a date"), "Invalid date")
})

test_that("query values are what the strict API expects", {
  query <- ef_query(list(hasResults = TRUE, teamId = 100000, athleteId = c(6, 13),
                         dateAfter = "07/28/2025", gone = NULL))
  expect_equal(query, list(hasResults = "true", teamId = "100000", athleteId = "6,13", dateAfter = "2025-07-28"))
})

test_that("every page is followed and joined", {
  api <- fake_api(json_page(list(list(id = 1, name = "A")), cursor = "next"),
                  json_page(list(list(id = 2, name = "B"))))
  local_mocked_bindings(ef_request = api$request)

  teams <- EF_GetTeamsList(test_token())

  expect_equal(teams, data.frame(id = c(1L, 2L), name = c("A", "B"), row.names = 1:2))
  calls <- api$calls()
  expect_equal(calls[[1]]$path, "/teams")
  expect_equal(calls[[1]]$query[["page[size]"]], "1000")
  expect_null(calls[[1]]$query[["page[after]"]])
  expect_equal(calls[[2]]$query[["page[after]"]], "next")
})

test_that("a row with no target or reps survives next to one that has them", {
  rep <- list(id = 9, repNumber = 1)
  rows <- list(
    list(id = 1, weight = NULL, target = NULL, reps = list()),
    list(id = 2, weight = 225.5, target = list(metric = "avgVelocity", basis = "absolute", min = 0.5, max = NULL),
         reps = list(rep))
  )

  df <- ef_rows_to_df(rows)

  expect_equal(df$weight, c(NA, 225.5))
  expect_equal(df$targetMetric, c(NA, "avgVelocity"))
  expect_equal(df$targetMax, c(NA, NA))
  expect_equal(nrow(df$reps[[1]]), 0)
  expect_equal(df$reps[[2]]$repNumber, 1)
})

test_that("a page with no targets still has the target columns", {
  df <- ef_rows_to_df(list(list(id = 1, target = NULL)))
  expect_named(df, c("id", "targetMetric", "targetBasis", "targetMin", "targetMax"))
})

test_that("sets default to completed sets on one workout day", {
  api <- fake_api("empty", "empty", "empty")
  local_mocked_bindings(ef_request = api$request)
  token <- test_token()

  EF_GetAllSets(token, "07/28/2025")
  EF_GetAllSets(token, "2025-07-28", includePaperless = 0, athleteId = c(6, 13))
  EF_GetAllSets(token, dateAfter = "2025-07-01", dateBefore = "2025-08-01", hasResults = NULL)

  calls <- api$calls()
  expect_equal(calls[[1]]$path, "/sets")
  expect_equal(calls[[1]]$query$teamId, "7")
  expect_equal(calls[[1]]$query$hasResults, "true")
  expect_equal(calls[[1]]$query$dateAfter, "2025-07-28")
  expect_equal(calls[[1]]$query$dateBefore, "2025-07-29")
  expect_null(calls[[1]]$query$trackedOnly)
  expect_equal(calls[[2]]$query$trackedOnly, "true")
  expect_equal(calls[[2]]$query$athleteId, "6,13")
  expect_equal(calls[[3]]$query$dateBefore, "2025-08-01")
  expect_null(calls[[3]]$query$hasResults)
})

test_that("arguments that cannot work are refused before any request", {
  token <- test_token()
  expect_error(EF_GetAllSets(token, includePaperless = 2), "must be 1, 0")
  expect_error(EF_GetAllSets(token, "2025-07-28", dateAfter = "2025-07-01"), "not both")
  expect_error(EF_GetAllSets(token, "2025-07-28", "", 6), "must be named")
  expect_error(EF_GetAthleteInfo(EF_CreateAPIToken("ef_live_ABC_secret")), "EF_UpdateTokenTeam")
})

test_that("a key restricted to one team may leave the team out", {
  api <- fake_api("empty")
  local_mocked_bindings(ef_request = api$request)
  EF_Get1RMs(EF_CreateAPIToken("ef_live_ABC_secret"))
  expect_null(api$calls()[[1]]$query$teamId)
})

test_that("the roster reads the team's path and collapses names", {
  rows <- list(list(athleteId = 6, firstName = "Avery", lastName = "Jordan", archived = FALSE,
                    positions = list(list(id = 1, name = "WR", abbreviation = "WR"),
                                     list(id = 2, name = "KR", abbreviation = "KR")),
                    categories = list(),
                    classification = list(id = 4, name = "Junior")))
  api <- fake_api(json_page(rows))
  local_mocked_bindings(ef_request = api$request)

  roster <- EF_GetAthleteInfo(test_token(), "07/28/2025")

  expect_equal(api$calls()[[1]]$path, "/teams/7/roster")
  expect_equal(api$calls()[[1]]$query$asOf, "2025-07-28")
  expect_equal(roster$positions, "WR, KR")
  expect_equal(roster$categories, NA_character_)
  expect_equal(roster$classificationName, "Junior")
})

test_that("the deprecated reps function still answers", {
  api <- fake_api("empty")
  local_mocked_bindings(ef_request = api$request)
  expect_warning(EF_GetAllTrackedReps3(test_token(), "2025-07-28"), "deprecated")
  expect_equal(api$calls()[[1]]$path, "/reps")
})

test_that("a short 429 is waited out and a long one is not", {
  limited <- function(seconds) list(status = 429, retry_after = seconds, body = "{\"detail\":\"Rate limit exceeded.\"}")
  api <- fake_api(limited("0"), json_page(list(list(id = 1))))
  local_mocked_bindings(ef_request = api$request)
  expect_message(teams <- EF_GetTeamsList(test_token()), "waiting 0 seconds")
  expect_equal(teams$id, 1L)

  api <- fake_api(limited("3600"))
  local_mocked_bindings(ef_request = api$request)
  expect_error(EF_GetTeamsList(test_token()), "429: Rate limit exceeded")
  expect_length(api$calls(), 1)
})

test_that("API errors surface their detail, and non-JSON errors do not crash", {
  problem <- list(status = 403, retry_after = NULL,
                  body = "{\"detail\":\"Missing ReadSets.\",\"instance\":\"urn:eliteform:request:1\"}")
  api <- fake_api(problem)
  local_mocked_bindings(ef_request = api$request)
  expect_error(EF_GetTeamsList(test_token()), "403: Missing ReadSets\\. \\(urn:eliteform:request:1\\)")

  api <- fake_api(list(status = 502, retry_after = NULL, body = "<html>Bad gateway</html>"))
  local_mocked_bindings(ef_request = api$request)
  expect_error(EF_GetTeamsList(test_token()), "502")
})
