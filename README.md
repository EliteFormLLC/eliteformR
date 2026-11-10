# eliteformR <img src="man/figures/logo.png" align="right" height="120"/>
**Get your reps, sets, and maxes from the EliteForm API**   
<!-- badges: start -->
[![R-CMD-check](https://github.com/EliteFormLLC/eliteformR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/EliteFormLLC/eliteformR/actions/workflows/R-CMD-check.yaml)
![Last Commit](https://img.shields.io/github/last-commit/EliteFormLLC/eliteformR?style=flat)
[![license](https://img.shields.io/badge/license-MIT%20+%20file%20LICENSE-lightgrey.svg)](https://choosealicense.com/)
[![minimal R
version](https://img.shields.io/badge/R%3E%3D-4.1.1-6666ff.svg)](https://cran.r-project.org/)
[![Project Status: Active – The project has reached a stable, usable
state and is being actively
developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![packageversion](https://img.shields.io/badge/Package%20version-2.0.0-orange.svg?style=flat-square)](https://github.com/EliteFormLLC/eliteformR/commits/main)

<!-- badges: end -->
eliteformR is an R package designed to provide easy interfacing with the [EliteForm](https://www.eliteform.com/) API. An EliteForm account and an API v2 key are required to utilize this package. Version 2.0.0 moved from the original `/api/v1` endpoints to API v2; see [NEWS.md](NEWS.md) for what to change in existing scripts.

# Installation
You can install version 2.0.0 of eliteformR from Github with: 
```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("EliteFormLLC/eliteformR")
```

# Quick start
```r
library(eliteformR)

# The key identifies your organization. Keep it out of your scripts.
token <- EF_CreateAPIToken(Sys.getenv("ELITEFORM_API_KEY"))

# Pick a team
teams <- EF_GetTeamsList(token)
token <- EF_UpdateTokenTeam(token, teams$id[1])

# Completed sets for one workout day, or a whole month in one call
sets <- EF_GetAllSets(token, "08/03/2026")
sets <- EF_GetAllSets(token, dateAfter = "2026-08-01", dateBefore = "2026-09-01")

# Add athlete and exercise names, keeping sets from archived athletes
roster <- EF_GetAthleteInfo(token, includeArchived = TRUE)
sets <- merge(sets, roster[, c("athleteId", "firstName", "lastName")], by = "athleteId", all.x = TRUE)
sets <- merge(sets, EF_GetExercises(token)[, c("id", "name")], by.x = "exerciseId", by.y = "id", all.x = TRUE)

# Each athlete's fastest set
aggregate(peakVelocity ~ firstName + lastName + name, data = sets, FUN = max)
```

# What's included

| Function | Returns | Key scope needed |
| --- | --- | --- |
| `EF_CreateAPIToken()` | The token every other function takes | |
| `EF_GetTeamsList()` | Your teams | `ReadTeams` |
| `EF_UpdateTokenTeam()` | The token, with a team selected | |
| `EF_GetAllSets()` | Sets, with their targets and reps | `ReadSets` |
| `EF_GetAllTrackedReps()` | One row per tracked rep | `ReadReps` or `ReadSets` |
| `EF_Get1RMs()` | Each athlete's current 1RM per exercise | `ReadOneRMs` |
| `EF_GetPower1RMs()` | Each athlete's current Power 1RM per exercise | `ReadOneRMs` |
| `EF_GetAthleteInfo()` | The team's roster, with positions, categories and classification | `ReadAthletes` |
| `EF_GetExercises()` | Exercise names and weight units | `ReadTeams` |

Every data function reads all pages for you and returns one data frame. Any filter from the [API reference](https://api.eliteform.com/docs) can be passed by name, such as `athleteId = c(6, 13)`.

See the guides for more: [Getting Started](vignettes/getting-started.Rmd), [Reps and Sets](vignettes/get-reps-and-sets.Rmd), [Maxes](vignettes/get-max.Rmd) and [Recipes](vignettes/recipes.Rmd).

# Moving from version 1
Version 1 scripts need a new API key and a few changes, because columns are now `camelCase` and names come from a join. [NEWS.md](NEWS.md) lists them all. Your existing IDs still match, since v2 uses the same athlete, team and exercise IDs as v1.

# Contributing and support
Pull requests are welcome, with no promises; see [CONTRIBUTING.md](CONTRIBUTING.md). For help with the API, your key or your data, please contact EliteForm support or your EliteForm representative.

# Credits
eliteformR was created by [Matthew Wilcox](https://github.com/MatthewLeeWilcox), who wrote the original version for API v1.

# R version
eliteformR was built and tested on R version 4.1.1. It may run and function on earlier R versions; however, for an optimal experience, please upgrade to 4.1.1 or greater. 
