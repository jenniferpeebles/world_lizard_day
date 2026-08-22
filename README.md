# World Lizard Day

This repository inventories, cleans and maps two public biodiversity downloads: the Georgia Southern University Herpetology Collection Darwin Core Archive and an EDDMapS download of Argentine black and white tegu records. The workflow is written in R, preserves the supplied raw files byte-for-byte, and creates review-ready QA, clean tables, WGS84 GeoJSON, static maps and an interactive map.

The project code is available under the [MIT License](LICENSE). Source-data and derived-data reuse remains subject to the terms of the respective data providers.

## What the project does

1. Inventories raw files and ZIP members, records file sizes and MD5 hashes, and creates source data dictionaries.
2. Cleans the full Georgia Southern occurrence table and creates an explicit lizard subset.
3. Cleans EDDMapS point, polygon and revisit layers without discarding non-current records.
4. Runs geographic and relational QA before mapping.
5. Exports WGS84 GeoJSON for Datawrapper and produces static and interactive review maps.
6. Writes a reporter brief that distinguishes findings from caveats.

## Important methodological choices

- No imputation is performed. Missing dates and coordinates remain missing.
- Source record identifiers are retained as character fields.
- The Georgia Southern archive does not include a simple lizard flag. This workflow defines lizards as records in order `Squamata` excluding the four snake families present in the download: Boidae, Colubridae, Elapidae and Viperidae. The included-family QA table makes that rule reviewable.
- The two sources are not appended. They have different structures, missions, time spans and collection processes. They appear as separate map layers.
- EDDMapS `Positive`, `Treated`, verified/current flags and revisit relationships are source-system fields. A treated record is not assumed to mean eradication.
- Static and final spatial exports use WGS84 (EPSG:4326). The supplied EDDMapS files are also WGS84.

## Repository structure

```text
R/                    Numbered R scripts and reusable helpers
data/data_raw/        Original downloads; never modified
data/data_intermediate/ Imported R objects regenerated from raw files
data/data_clean/      Clean CSV tables
exports/              WGS84 GeoJSON
outputs/qa/           Inventory and QA tables
outputs/maps/         Static JPG and interactive HTML maps
logs/                 Timestamped console logs and session information
docs/                 Maintenance notes and retrospective
```

## Run the workflow

1. Download the [Georgia Southern Herpetology Collection archive](http://ipt.vertnet.org:8080/ipt/resource?r=gsu_herps).
2. Download Argentine black and white tegu records from the [official EDDMapS species/download page](https://www.eddmaps.org/species/subject.cfm?sub=82961). EDDMapS may require a login.
3. Place the files in the local structure documented in [`data/README.md`](data/README.md). Data files are ignored by Git and remain on the user's machine.
4. From the project root, run:

```r
source("run_all.R")
```

The scripts require `dplyr`, `readr`, `stringr`, `tidyr`, `purrr`, `tibble`, `janitor`, `sf`, `ggplot2`, `scales`, `leaflet`, `htmlwidgets`, `jsonlite`, `tigris`, `cowplot` and `jpeg`. A successful run prints row-count diagnostics, writes logs and uses `beepr` when installed. The mapping stage requires internet access on its first run to download 2025 Census cartographic state and Georgia county boundaries; `tigris_use_cache = TRUE` reuses the local copies afterward.

## Script guide

- `R/01_inventory_raw_data.R`: reads both ZIP files in place; generates hashes, member inventory, field profiles and intermediate R objects.
- `R/02_clean_georgia_southern.R`: standardizes selected Darwin Core fields, preserves IDs, applies the documented taxonomic filter, checks coordinates and exports lizard GeoJSON.
- `R/03_clean_eddmaps.R`: cleans point, polygon and revisit layers, parses dates conservatively, compares reported coordinates with point geometry, validates geometry and checks revisit links.
- `R/04_qa_and_maps.R`: downloads 2025 Census cartographic state and Georgia county boundaries through `tigris`, highlights Tattnall and Toombs counties, confirms WGS84 outputs, adds the attributed CC BY tegu photograph, creates static and interactive maps, and generates the reporter brief.
- `R/06_mark_davis_story.R`: spatially filters EDDMapS sightings and revisits to Georgia, exports Datawrapper-ready longitude/latitude CSVs and a WGS84 Toombs–Tattnall GeoJSON, and creates a watermarked Georgia-only internal-review map without the tegu photograph.

## Source data

The Georgia Southern metadata identifies the VertNet IPT resource as `http://ipt.vertnet.org:8080/ipt/resource?r=gsu_herps`, version 6.1. Its archive includes `occurrence.txt`, `multimedia.txt`, `meta.xml` and `eml.xml`; this workflow currently analyzes occurrences, not multimedia. The supplied EML states a CC0 public-domain dedication.

The local EDDMapS archive is expected as `62459.zip` and contains `observations.gpkg`, `revisits.gpkg` and `SHPDowloadDataDictionaries.xlsx`. Users obtain their own copy from the [EDDMapS Argentine black and white tegu page](https://www.eddmaps.org/species/subject.cfm?sub=82961). The exact query filters and download timestamp are not encoded clearly in the supplied archive, so each user should record those details when downloading. Local modification times and hashes are written to `outputs/qa/raw_file_inventory.csv`.

## QA gates and known limitations

- Review `outputs/qa/gsu_cleaning_qa.csv`, `outputs/qa/eddmaps_cleaning_qa.csv` and `outputs/qa/final_mapping_qa.csv` before using findings.
- Only 177 of 1,806 operationally identified Georgia Southern lizard records contain usable coordinate pairs. The static map therefore represents a small, non-random subset of those records.
- Two EDDMapS point records are marked non-current; they are preserved and identified.
- One EDDMapS revisit does not match a parent point object ID in this download.
- Reporting intensity, museum collecting effort and digitization/georeferencing practices vary over time and place. Point density is not population density.
- This project does not use changing Census, political or administrative boundaries. The basemap is for orientation only and is not used for geographic aggregation.

## Primary outputs

- `outputs/reporter_brief.md`: story-ready findings and caveats
- `outputs/qa/raw_data_dictionary.csv`: machine-readable field inventory
- `outputs/maps/world_lizard_sources_YYYY-MM-DD.jpg`: watermarked review map
- `outputs/maps/world_lizard_sources_interactive_YYYY-MM-DD.html` plus its `_files` asset folder: shareable interactive (keep them together)
- `exports/*.geojson`: Datawrapper-ready WGS84 spatial layers

## Reproducibility and maintenance

Raw inputs are never extracted over or rewritten. The file inventory uses hashes so Future Jennifer can detect source changes. Derived outputs are deterministic except for run timestamps and the current date embedded in review-map filenames. When either source is updated, replace or add the raw download, update the explicit filenames in `R/00_config.R`, run the pipeline and compare QA counts before accepting any apparent trend.

## Public-repository data policy

This repository intentionally excludes local raw, intermediate and clean data, `exports/`, `outputs/` and `logs/` artifacts through `.gitignore`. The EDDMapS download contains record-level personal information—including reporter names, phone numbers, email addresses and free-text comments—as well as precise occurrence locations. Public availability from a source system does not automatically make wholesale republication in a Git repository prudent.

The public repository should therefore contain the reproducible R code, methodological documentation and source-acquisition instructions, but not local source or record-level output files. Anyone running the analysis should obtain the source downloads directly and place them in the expected paths described in `data/README.md`.

`R/05_build_public_release.R` creates an allowlisted public-release candidate under `public/`. It removes source free text and personal fields and rounds coordinates to two decimal places. The generated data remains ignored until EDDMapS redistribution terms are confirmed. See `public/README.md` for the disclosure method and limitations.

Before publishing any additional summarized data or map separately, review it for personal information, sensitive locations, source terms and the minimum geographic precision needed for the reporting purpose.
