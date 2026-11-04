#' API_TOKEN S4 class
#'
#' Holds EliteForm API credentials/metadata.
#'
#' @slot url Character scalar with the EliteForm API base URL.
#' @slot api_key Character scalar with the API key.
#' @slot TEAM_ID Numeric team identifier, NA until \code{\link{EF_UpdateTokenTeam}} sets it.
#'
#' @exportClass API_TOKEN
#' @keywords classes
setClass("API_TOKEN", slots = list(
  url = "character",
  api_key = "character",
  TEAM_ID = "numeric"
))
