# Build privacy-reviewed public release files -----------------------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("05_public_release_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting sanitized public release build.")

public_data <- file.path(paths$public, "data")
public_qa <- file.path(paths$public, "qa")
dir.create(public_data, recursive = TRUE, showWarnings = FALSE)
dir.create(public_qa, recursive = TRUE, showWarnings = FALSE)

edd_points <- sf::st_read(
  file.path(paths$exports, "eddmaps_tegu_points_wgs84.geojson"), quiet = TRUE
)
edd_revisits <- sf::st_read(
  file.path(paths$exports, "eddmaps_tegu_revisits_wgs84.geojson"), quiet = TRUE
)

# PUBLICATION RULE: Use an allowlist. Never start with the complete source
# record and try to redact risky fields afterward. That approach can miss PII
# hidden in comments, locality, reporter or other free-text columns.
point_xy <- sf::st_coordinates(edd_points)
edd_points_public <- edd_points %>%
  sf::st_drop_geometry() %>%
  dplyr::transmute(
    source = "EDDMapS",
    source_record_id = as.character(source_record_id),
    scientific_name,
    common_name,
    occurrence_status = occ_status,
    management_status = status,
    observation_date = as.character(observation_date),
    observation_year,
    record_is_current = is_current_record,
    record_is_verified = is_verified,
    public_latitude = round(point_xy[, "Y"], 2),
    public_longitude = round(point_xy[, "X"], 2),
    coordinate_generalization = "Rounded to 0.01 degree for public release"
  ) %>%
  sf::st_as_sf(
    coords = c("public_longitude", "public_latitude"),
    crs = 4326,
    remove = FALSE
  )

revisit_xy <- sf::st_coordinates(edd_revisits)
edd_revisits_public <- edd_revisits %>%
  sf::st_drop_geometry() %>%
  dplyr::transmute(
    source = "EDDMapS revisit",
    source_record_id = as.character(source_record_id),
    parent_observation_id = as.character(parent_observation_id),
    scientific_name,
    common_name,
    occurrence_status = occ_status,
    management_status = status,
    observation_date = as.character(observation_date),
    observation_year,
    record_is_current = is_current_record,
    record_is_verified = is_verified,
    public_latitude = round(revisit_xy[, "Y"], 2),
    public_longitude = round(revisit_xy[, "X"], 2),
    coordinate_generalization = "Rounded to 0.01 degree for public release"
  ) %>%
  sf::st_as_sf(
    coords = c("public_longitude", "public_latitude"),
    crs = 4326,
    remove = FALSE
  )

write_csv_safe(
  sf::st_drop_geometry(edd_points_public),
  file.path(public_data, "eddmaps_tegu_points_sanitized.csv")
)
write_csv_safe(
  sf::st_drop_geometry(edd_revisits_public),
  file.path(public_data, "eddmaps_tegu_revisits_sanitized.csv")
)
sf::st_write(
  edd_points_public,
  file.path(public_data, "eddmaps_tegu_points_sanitized.geojson"),
  delete_dsn = TRUE, quiet = TRUE
)
sf::st_write(
  edd_revisits_public,
  file.path(public_data, "eddmaps_tegu_revisits_sanitized.geojson"),
  delete_dsn = TRUE, quiet = TRUE
)

# Publish compact QA without raw example values or source free text.
public_summary <- tibble::tibble(
  file = c(
    "eddmaps_tegu_points_sanitized.csv",
    "eddmaps_tegu_points_sanitized.geojson",
    "eddmaps_tegu_revisits_sanitized.csv",
    "eddmaps_tegu_revisits_sanitized.geojson"
  ),
  rows = c(nrow(edd_points_public), nrow(edd_points_public),
           nrow(edd_revisits_public), nrow(edd_revisits_public)),
  crs = c(NA_character_, "EPSG:4326", NA_character_, "EPSG:4326"),
  exact_coordinates_published = FALSE,
  pii_fields_published = FALSE
)
write_csv_safe(public_summary, file.path(public_qa, "public_release_inventory.csv"))

# Automated negative checks complement, but do not replace, field allowlisting.
public_text <- paste(
  capture.output(readLines(file.path(public_data, "eddmaps_tegu_points_sanitized.csv"), warn = FALSE)),
  collapse = "\n"
)
pii_patterns <- c(
  email = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}",
  phone = "(?<![0-9])[+]?[0-9]{0,2}[ .()-]*[0-9]{3}[ .()-]+[0-9]{3}[ .-]+[0-9]{4}(?![0-9])",
  windows_user_path = "[A-Z]:[/\\\\]Users[/\\\\]"
)
pii_hits <- vapply(
  pii_patterns,
  function(pattern) stringr::str_detect(public_text, stringr::regex(pattern, ignore_case = TRUE)),
  logical(1)
)
if (any(pii_hits)) {
  stop("Public release failed PII-pattern QA: ", paste(names(pii_hits)[pii_hits], collapse = ", "))
}

field_inventory <- tibble::tibble(
  field = names(sf::st_drop_geometry(edd_points_public)),
  public = TRUE,
  rationale = c(
    "Source attribution", "Stable machine identity", "Taxonomic identification",
    "Human-readable taxon", "Source occurrence category", "Source management category",
    "Observation timing", "Year grouping", "Source current-record flag",
    "Source verification flag", "Generalized latitude", "Generalized longitude",
    "Disclosure of geographic transformation"
  )
)
write_csv_safe(field_inventory, file.path(public_qa, "public_field_dictionary.csv"))

log_message("Sanitized public release complete. Exact local data remains unchanged.")

