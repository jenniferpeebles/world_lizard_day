# Retrospective

## What went wrong

- The first inventory run used an overcomplicated regular expression to shorten paths. R rejected the expression. It was replaced with literal prefix handling.
- The initial EDDMapS geometry check assumed the active geometry column would be named `geometry`; the source retains `shape`. The check now uses the `sf` object itself and is independent of column name.
- System R was not on the command path, but the project guidance provided the installed R 4.5.3 location.

Both script failures occurred before final outputs were accepted. Neither touched the raw files.

## What would make a future update easier

- Record the EDDMapS landing-page URL, query parameters, requested species/geography and exact download time next to each new archive. The ZIP does not provide enough provenance to reconstruct all of that confidently.
- State the intended geographic focus at project kickoff. This workflow uses the Southeast for the static comparison map because the EDDMapS download extent is concentrated there, while keeping full layers in GeoJSON and the interactive.
- If the editorial question depends on trends, obtain documentation about changes in EDDMapS reporting, verification and treatment practices before comparing years.

## Reusable improvements

- `data_dictionary()` creates field-level missingness, class, distinct-count and example-value documentation for future projects.
- `log_message()` writes the same progress diagnostics to the console and a timestamped log.
- The clean stages separate source meaning from map display decisions, preserving non-current records and unmatched revisits for QA.

