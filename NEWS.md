# eliteformR 2.0.0

Moves the package from the original `/api/v1` endpoints to EliteForm API v2 (`https://api.eliteform.com`). This is a breaking change.

## What to change in your scripts

- **Ask EliteForm for a new key.** v1 keys do not work on v2.
- **`EF_CreateAPIToken(url, api_key)` is now `EF_CreateAPIToken(api_key)`.** The key identifies your organization, so there is no organization URL.
- **Column names are now the API's `camelCase`,** such as `athleteId` and `avgVelocity`. `EF_GetTeamsList()` returns `id` and `name` rather than `TeamId` and `Name`.
- **Athlete and exercise names are no longer on sets, reps and maxes.** Join `athleteId` to `EF_GetAthleteInfo()` and `exerciseId` to the new `EF_GetExercises()`. Those calls need the `ReadAthletes` and `ReadTeams` scopes on your key.
- **`date` now means the workout day,** not the day the lift was recorded.
- **Dates are `YYYY-MM-DD`,** and `occurredAtLocal` replaces the separate `Date` and `Time` columns.
- **Maxes can carry a different date.** v2 gives the date a max was entered for; v1 gave the day it was last saved, in UTC.

## Reps

- `EF_GetAllTrackedReps3()` is deprecated, since v2 has one rep resource; it now returns the same as `EF_GetAllTrackedReps()`.
- Reps no longer carry `LoadFactor`, `ActualWeight` or `ActualRest`. Join `setId` to the `id` from `EF_GetAllSets()`, or read `reps` on each set.
- `TimeToPeak` and `TrackerClassificationId` are not available from v2.

## New

- `EF_GetExercises()` returns exercise names and weight units.
- Every data function pulls all pages and takes the API's filters by name, such as `athleteId` or `exerciseId`.
- Sets and reps can read a range of days in one call with `dateAfter` and `dateBefore`, instead of one call per day.
- `EF_GetAllSets()` includes each set's reps in a `reps` column and its target in `targetMetric`, `targetBasis`, `targetMin` and `targetMax`. `hasResults = FALSE` returns sets not done yet.
- API errors now stop with the API's message, where v1 returned the error body as if it were data.
- A short rate-limit response (`429`) is waited out and retried.

## Removed

- `convert_to_MMddyyyy()`, which only v1 needed. Date arguments still accept the same formats, and `Date` objects.
