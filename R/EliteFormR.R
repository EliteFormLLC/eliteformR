#' Elite Form API Login
#'
#' Creates the token every other function takes. Your organization comes from the key, so there is
#' no organization URL any more. Keys issued for the original /api/v1 endpoints do not work here;
#' ask your EliteForm representative for a new one.
#' @param api_key API key string, in the form \code{ef_live_XXXXXXXXXXXX_your_secret_here}.
#' @param url API base URL. Only change this to test against another environment.
#' @return Returns an S4 Object that saves your API key and URL and acts as a token for later pulls
#' @examples
#' \dontrun{
#' # Keep the key out of your scripts, e.g. in an environment variable
#' token <- EF_CreateAPIToken(Sys.getenv("ELITEFORM_API_KEY"))
#' }
#' @importFrom methods new
#' @export
EF_CreateAPIToken <- function(api_key, url = "https://api.eliteform.com") {
  if (!is.character(api_key) || length(api_key) != 1 || !grepl("^ef_[a-z0-9]+_", api_key)) {
    stop("api_key must be an EliteForm API v2 key, which starts with 'ef_'. ",
         "The arguments changed in version 2.0.0: the key comes first and the URL is optional.",
         call. = FALSE)
  }
  new("API_TOKEN", url = sub("/+$", "", url), api_key = api_key, TEAM_ID = NA_real_)
}

#' Get List of Teams
#'
#' Get team names and IDs for the entire user account. Requires the ReadTeams scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}}).
#' @return A data frame with the following columns:
#' \describe{
#'   \item{id}{`numeric` - Team unique identifier}
#'   \item{name}{`character` - Team Name}
#' }
#' @examples
#' \dontrun{
#' teams <- EF_GetTeamsList(token)
#' }
#' @export
EF_GetTeamsList <- function(token) {
  ef_get_all(token, "/teams")
}

#' Update the Token Team Attribute
#'
#' Update the custom API Token to select the team to pull from.
#' Must be saved as the token values ie token <- EF_UpdateTokenTeam(token, 1)
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param TEAM_ID Team id referenced in \code{\link{EF_GetTeamsList}}
#' @return Custom API Token Object
#' @examples
#' \dontrun{
#' token <- EF_CreateAPIToken(Sys.getenv("ELITEFORM_API_KEY"))
#' teams <- EF_GetTeamsList(token)
#' token <- EF_UpdateTokenTeam(token, teams$id[1])
#' }
#' @export
EF_UpdateTokenTeam <- function(token, TEAM_ID) {
  token@TEAM_ID <- as.numeric(TEAM_ID)
  token
}

#' Get All Exercises
#'
#' Get the exercises defined on the token's team: the names and weight units behind the
#' \code{exerciseId} on sets, reps and maxes. Requires the ReadTeams scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param ... Other API filters and options by name, such as \code{teamId} or \code{sort}.
#' @return Returns a data frame with the following columns:
#' \describe{
#'   \item{id}{`numeric` - Unique exercise identifier}
#'   \item{teamId}{`numeric` - The team the exercise belongs to}
#'   \item{name}{`character` - Name of the exercise}
#'   \item{weightUnit}{`character` - "lb" or "kg", the unit of this exercise's weights and 1RMs}
#' }
#' @examples
#' \dontrun{
#' exercises <- EF_GetExercises(token)
#'
#' # Add exercise names to sets
#' sets <- EF_GetAllSets(token, "08/03/2026")
#' merge(sets, exercises[, c("id", "name", "weightUnit")], by.x = "exerciseId", by.y = "id", all.x = TRUE)
#' }
#' @export
EF_GetExercises <- function(token, ...) {
  filters <- ef_team_filter(token, ef_check_filters(list(...)))
  ef_get_all(token, "/exercises", filters)
}

#' Get All Tracked Reps
#'
#' Get every rep tracked at the rack for a team, on one workout day by default. Paperless sets have
#' no reps; use \code{\link{EF_GetAllSets}} for those. Requires the ReadReps or ReadSets scope.
#'
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param date The workout day, as a Date or a string such as \code{"2025-07-28"} or
#'   \code{"07/28/2025"}. Defaults to the current date.
#' @param ... Other API filters and options by name: \code{athleteId} (up to 200), \code{exerciseId},
#'   \code{sessionId}, \code{setId}, \code{sort}. For a range of days pass \code{dateAfter} and
#'   \code{dateBefore} instead of \code{date}; the end is exclusive and a range spans at most 366 days.
#'
#' @return Returns a data frame with one row per rep. Join \code{athleteId} to
#'   \code{\link{EF_GetAthleteInfo}} and \code{exerciseId} to \code{\link{EF_GetExercises}} for names.
#' \describe{
#'   \item{id}{`numeric` - Unique rep identifier}
#'   \item{setId, athleteId, teamId, sessionId, exerciseId}{`numeric` - What the rep belongs to}
#'   \item{date}{`character` - Workout day (YYYY-MM-DD)}
#'   \item{exerciseNumber, supersetPosition, setNumber, repNumber}{`integer` - Position on the workout card}
#'   \item{occurredAtLocal}{`character` - When the set happened, on the rack's clock}
#'   \item{targetMetric, targetBasis, targetMin, targetMax}{The target the rep was judged against, NA when none}
#'   \item{duration}{`numeric` - Duration of the rep (s)}
#'   \item{avgVelocity, peakVelocity}{`numeric` - Bar velocity (m/s)}
#'   \item{avgPower, peakPower}{`numeric` - Power output (W)}
#'   \item{work}{`numeric` - Work performed (J)}
#'   \item{reactionTimeMs}{`integer` - Reaction time (ms)}
#'   \item{eccentricDuration, eccentricAvgVelocity, eccentricPeakVelocity, eccentricAvgPower, eccentricPeakPower, eccentricWork}{`numeric` - The lowering phase, NA when not recorded}
#' }
#' @examples
#' \dontrun{
#' # Reps for today, then for one workout day
#' reps <- EF_GetAllTrackedReps(token)
#' reps <- EF_GetAllTrackedReps(token, "08/03/2026")
#'
#' # One athlete's reps of one exercise across a month
#' reps <- EF_GetAllTrackedReps(token, dateAfter = "2026-08-01", dateBefore = "2026-09-01",
#'                              athleteId = 6, exerciseId = 88)
#'
#' # Each athlete's fastest rep
#' aggregate(peakVelocity ~ athleteId, data = reps, FUN = max)
#' }
#' @export
EF_GetAllTrackedReps <- function(token, date = "", ...) {
  filters <- ef_date_window(date, ef_team_filter(token, ef_check_filters(list(...))))
  ef_get_all(token, "/reps", filters)
}

#' Get All Tracked Reps (deprecated)
#'
#' API v2 has one rep resource, so this now returns the same as \code{\link{EF_GetAllTrackedReps}}.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param date The workout day; see \code{\link{EF_GetAllTrackedReps}}.
#' @param ... Other API filters and options; see \code{\link{EF_GetAllTrackedReps}}.
#' @return See \code{\link{EF_GetAllTrackedReps}}.
#' @export
EF_GetAllTrackedReps3 <- function(token, date = "", ...) {
  .Deprecated("EF_GetAllTrackedReps")
  EF_GetAllTrackedReps(token, date, ...)
}

#' Get all Sets
#'
#' Get the completed sets for a team, on one workout day by default. Requires the ReadSets scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param date The workout day, as a Date or a string such as \code{"2025-07-28"} or
#'   \code{"07/28/2025"}. Defaults to the current date.
#' @param includePaperless Include sets entered through Paperless. 1 = True, 0 = False. Defaults to True.
#' @param ... Other API filters and options by name: \code{athleteId} (up to 200), \code{exerciseId},
#'   \code{sessionId}, \code{sort}. For a range of days pass \code{dateAfter} and \code{dateBefore}
#'   instead of \code{date}; the end is exclusive and a range spans at most 366 days. Pass
#'   \code{hasResults = FALSE} for sets not done yet, or \code{hasResults = NULL} for every set.
#' @return Returns a data frame with one row per set. Join \code{athleteId} to
#'   \code{\link{EF_GetAthleteInfo}} and \code{exerciseId} to \code{\link{EF_GetExercises}} for names.
#' \describe{
#'   \item{id}{`numeric` - Unique set identifier}
#'   \item{athleteId, teamId, sessionId, exerciseId}{`numeric` - What the set belongs to}
#'   \item{date}{`character` - Workout day (YYYY-MM-DD)}
#'   \item{exerciseNumber, supersetPosition, setNumber}{`integer` - Position on the workout card}
#'   \item{repsAssigned}{`integer` - Repetitions assigned, NA for a max-reps set}
#'   \item{isMaxReps}{`logical` - Whether the set is as many reps as possible}
#'   \item{weight}{`numeric` - Weight assigned, in the exercise's weight unit}
#'   \item{loadFactor}{`numeric` - Load factor assigned, NA for a bodyweight set}
#'   \item{isBodyweight}{`logical` - Whether the set is bodyweight}
#'   \item{targetMetric, targetBasis, targetMin, targetMax}{The prescribed target, NA when none}
#'   \item{hasResults}{`logical` - Whether the set has been done}
#'   \item{occurredAtLocal}{`character` - When it happened, on the rack's clock}
#'   \item{repsCompleted}{`integer` - Repetitions completed}
#'   \item{actualWeight}{`numeric` - Weight lifted, in the exercise's weight unit}
#'   \item{actualRest}{`integer` - Rest before the set (seconds)}
#'   \item{isTracked}{`logical` - TRUE when measured at the rack, FALSE when Paperless}
#'   \item{repCount}{`integer` - Reps the rack captured}
#'   \item{avgVelocity, peakVelocity}{`numeric` - Bar velocity (m/s), NA when not tracked}
#'   \item{avgPower, peakPower}{`numeric` - Power output (W), NA when not tracked}
#'   \item{work}{`numeric` - Work performed (J), NA when not tracked}
#'   \item{reactionTimeMs}{`integer` - Reaction time (ms), NA when not tracked}
#'   \item{reps}{`list` - A data frame of the set's reps, with no rows when not tracked}
#' }
#' @examples
#' \dontrun{
#' # Completed sets for today, then for one workout day
#' sets <- EF_GetAllSets(token)
#' sets <- EF_GetAllSets(token, "08/03/2026")
#'
#' # Only sets tracked at the rack
#' sets <- EF_GetAllSets(token, "08/03/2026", includePaperless = 0)
#'
#' # Two athletes across a month, in one call
#' sets <- EF_GetAllSets(token, dateAfter = "2026-08-01", dateBefore = "2026-09-01",
#'                       athleteId = c(6, 13))
#'
#' # The reps of the first set
#' sets$reps[[1]]
#'
#' # What is on the card but not done yet
#' planned <- EF_GetAllSets(token, "08/03/2026", hasResults = FALSE)
#' }
#' @export
EF_GetAllSets <- function(token, date = "", includePaperless = "", ...) {
  includePaperless <- as.character(includePaperless)
  if (!(includePaperless %in% c("1", "0", ""))) {
    stop("includePaperless must be 1, 0 or ''", call. = FALSE)
  }
  filters <- utils::modifyList(list(hasResults = TRUE), ef_check_filters(list(...)))
  if (includePaperless == "0") {
    filters$trackedOnly <- TRUE
  }
  filters <- ef_date_window(date, ef_team_filter(token, filters))
  ef_get_all(token, "/sets", filters)
}

#' Get all 1 Rep Max for Entire Team
#'
#' Get each athlete's current 1RM per exercise for the token's team. Requires the ReadOneRMs scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param ... Other API filters and options by name: \code{athleteId} (up to 200), \code{exerciseId},
#'   \code{isPredicted}, \code{sort}. \code{dateBefore} answers "what was the max as of then".
#' @return Returns a data frame with the following columns:
#' \describe{
#'   \item{id}{`numeric` - Unique identifier of the max}
#'   \item{athleteId, exerciseId, teamId}{`numeric` - What the max belongs to}
#'   \item{result}{`numeric` - The max, in the exercise's weight unit}
#'   \item{isPredicted}{`logical` - TRUE when predicted by EliteForm, FALSE when entered by a coach}
#'   \item{date}{`character` - Date of the max (YYYY-MM-DD)}
#' }
#' @examples
#' \dontrun{
#' maxes <- EF_Get1RMs(token)
#'
#' # Only coach-entered maxes, as they stood on July 1
#' maxes <- EF_Get1RMs(token, isPredicted = FALSE, dateBefore = "2026-07-01")
#' }
#' @export
EF_Get1RMs <- function(token, ...) {
  filters <- ef_team_filter(token, ef_check_filters(list(...)))
  ef_get_all(token, "/one-rms", filters)
}

#' Get all Power 1 Rep Max for Entire Team
#'
#' Get each athlete's current Power 1RM per exercise for the token's team. Requires the ReadOneRMs scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param ... Other API filters and options by name: \code{athleteId} (up to 200), \code{exerciseId},
#'   \code{sort}. \code{dateBefore} answers "what was the max as of then".
#' @return Returns a data frame with the following columns:
#' \describe{
#'   \item{id}{`numeric` - Unique identifier of the max}
#'   \item{athleteId, exerciseId, teamId}{`numeric` - What the max belongs to}
#'   \item{averagePower}{`numeric` - Average power output (W)}
#'   \item{peakPower}{`numeric` - Peak power output (W)}
#'   \item{date}{`character` - Date of the max (YYYY-MM-DD)}
#' }
#' @examples
#' \dontrun{
#' power_maxes <- EF_GetPower1RMs(token)
#'
#' # One exercise
#' power_maxes <- EF_GetPower1RMs(token, exerciseId = 95)
#' }
#' @export
EF_GetPower1RMs <- function(token, ...) {
  filters <- ef_team_filter(token, ef_check_filters(list(...)))
  ef_get_all(token, "/power-one-rms", filters)
}

#' Get all Player Info for entire team
#'
#' Get the roster of the token's team. Requires the ReadAthletes scope.
#' @param token API Token Object (see \code{\link{EF_CreateAPIToken}})
#' @param date Any date within the desired season, which supplies each athlete's classification, as
#'   a Date or a string such as \code{"2025-07-28"} or \code{"07/28/2025"}. Defaults to the current date.
#' @param ... Other API filters and options by name: \code{includeArchived}, \code{sort}.
#' @return Returns a data frame with the following columns:
#' \describe{
#'   \item{athleteId}{`numeric` - Unique athlete identifier}
#'   \item{firstName}{`character` - Athlete's first name}
#'   \item{lastName}{`character` - Athlete's last name}
#'   \item{archived}{`logical` - Whether the athlete is archived}
#'   \item{positions}{`character` - Athlete's positions on this team, comma-separated}
#'   \item{categories}{`character` - Athlete's categories on this team, comma-separated}
#'   \item{classificationId}{`numeric` - Identifier of the classification}
#'   \item{classificationName}{`character` - Athlete's classification (e.g., Freshman, Senior)}
#' }
#' @examples
#' \dontrun{
#' roster <- EF_GetAthleteInfo(token)
#'
#' # Classifications from last season, including archived athletes
#' roster <- EF_GetAthleteInfo(token, "2025-10-01", includeArchived = TRUE)
#' }
#' @export
EF_GetAthleteInfo <- function(token, date = "", ...) {
  if (is.na(token@TEAM_ID)) {
    stop("Select a team first with EF_UpdateTokenTeam().", call. = FALSE)
  }
  filters <- ef_check_filters(list(...))
  if (!identical(date, "")) {
    filters$asOf <- date
  }
  roster <- ef_get_all(token, paste0("/teams/", format(token@TEAM_ID, scientific = FALSE, trim = TRUE), "/roster"), filters)
  if (nrow(roster) > 0) {
    roster$positions <- ef_collapse_names(roster$positions)
    roster$categories <- ef_collapse_names(roster$categories)
  }
  roster
}
