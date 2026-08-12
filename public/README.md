# Sanitized public data

This folder documents publication-specific derivatives of the local EDDMapS download. Generated release candidates do not contain the original records.

The generated `data/` and `qa/` subfolders remain excluded from Git until EDDMapS redistribution terms are confirmed. EDDMapS describes its query data as publicly available and provides downloads, but that is not the same thing as an explicit redistribution license.

## Privacy method

The release is created with a strict field allowlist. It excludes reporter names, record owners, surveyors, reviewers, museum notes, comments, locality descriptions, site descriptions, references and all other source free text. This is safer than attempting to redact selected patterns from a full record.

Public point and revisit coordinates are rounded to two decimal places—approximately 1 kilometer, although actual east-west distance varies by latitude. The files retain explicit `public_latitude`, `public_longitude` and `coordinate_generalization` fields so users cannot mistake generalized coordinates for source precision.

No values are imputed. Coordinate rounding is an explicit publication transformation; the exact local analytical data remains unchanged and excluded from Git.

## Included files

- `data/eddmaps_tegu_points_sanitized.csv`
- `data/eddmaps_tegu_points_sanitized.geojson`
- `data/eddmaps_tegu_revisits_sanitized.csv`
- `data/eddmaps_tegu_revisits_sanitized.geojson`
- `qa/public_release_inventory.csv`
- `qa/public_field_dictionary.csv`

The four source polygons are not included. Exact polygon boundaries may disclose site-level locations, and there were too few records to justify a generalized polygon release without an explicit editorial use case.

## Important limitations

- `Positive` and `Treated` are source-system categories, not measures of prevalence or proof of eradication.
- Public coordinates are unsuitable for parcel-level, distance or habitat analysis.
- Absence of an EDDMapS report is not evidence of tegu absence.
- Reuse remains subject to the applicable EDDMapS terms. Those terms were not established from the supplied ZIP alone.

Generate this folder with `R/05_build_public_release.R` after running the preceding workflow stages.

The public GitHub repository does not need these generated files to reproduce the work. Users can obtain their own source records from the [official EDDMapS tegu page](https://www.eddmaps.org/species/subject.cfm?sub=82961) and run the published R scripts locally.
