# Contributing to eliteformR

eliteformR is shared as is. We're happy to look at pull requests and issues, but we can't promise a reply, a merge or a timeline.

## Getting help with the API

This repository is only for the R package. For anything about the API itself, such as your account, keys, scopes, rate limits or your data, please contact EliteForm support or your EliteForm representative. We can't help with those here.

The [API reference](https://api.eliteform.com/docs) lists the endpoints and filters. API errors include an ID (`urn:eliteform:request:...`) you can quote to EliteForm support.

## Reporting a package bug

Open an issue with:

- the function you called and a small example
- the error or the result you got, and what you expected
- your package version and R version

**Never post API keys or athlete data.** This repository may be public, so replace real keys, names and results with made-up values. If a key is exposed, contact EliteForm support to have it replaced.

## Sending a pull request

For anything bigger than a small fix, open an issue first so you don't spend time on something we may not take.

Before you send it:

- Run `devtools::document()` after changing roxygen comments. `man/` and `NAMESPACE` are generated, so don't edit them by hand.
- Add or update tests in `tests/testthat/`. Tests mock the API, so they don't need a key and shouldn't call the real API.
- Make sure `devtools::check()` finishes with no errors or warnings.
- Add a line to `NEWS.md` if users will notice the change.

By sending a pull request, you agree that your contribution is licensed under the package's MIT license.
