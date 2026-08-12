# Clean Georgia Southern herpetology records ------------------------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("02_clean_gsu_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting Georgia Southern cleaning.")

gsu_raw <- readRDS(file.path(paths$intermediate, "gsu_occurrence_raw_import.rds"))

# Operational definition: Squamata records outside the four snake families
# present in this download. This is transparent and auditable, but taxonomy can
# change; the QA table lists every included family for reporter review.
snake_families_in_download <- c("Boidae", "Colubridae", "Elapidae", "Viperidae")

gsu_clean <- gsu_raw |>
  dplyr::transmute(
    source = "Georgia Southern University Herpetology Collection",
    source_record_id = clean_text_na(id),
    occurrence_id = clean_text_na(occurrence_id),
    catalog_number = clean_text_na(catalog_number),
    institution_code = clean_text_na(institution_code),
    collection_code = clean_text_na(collection_code),
    basis_of_record = clean_text_na(basis_of_record),
    scientific_name = clean_text_na(scientific_name),
    accepted_name_usage = clean_text_na(accepted_name_usage),
    taxon_rank = clean_text_na(taxon_rank),
    class = clean_text_na(class),
    order = clean_text_na(order),
    family = clean_text_na(family),
    genus = clean_text_na(genus),
    vernacular_name = clean_text_na(vernacular_name),
    event_date_raw = clean_text_na(event_date),
    year_reported = suppressWarnings(as.integer(year)),
    month_reported = suppressWarnings(as.integer(month)),
    day_reported = suppressWarnings(as.integer(day)),
    country = clean_text_na(country),
    country_code = clean_text_na(country_code),
    state_province = clean_text_na(state_province),
    county = clean_text_na(county),
    municipality = clean_text_na(municipality),
    locality = clean_text_na(locality),
    decimal_latitude = suppressWarnings(as.numeric(decimal_latitude)),
    decimal_longitude = suppressWarnings(as.numeric(decimal_longitude)),
    geodetic_datum = clean_text_na(geodetic_datum),
    coordinate_uncertainty_m = suppressWarnings(as.numeric(coordinate_uncertainty_in_meters)),
    georeference_verification_status = clean_text_na(georeference_verification_status),
    license = clean_text_na(license),
    rights_holder = clean_text_na(rights_holder),
    references = clean_text_na(references)
  ) |>
  dplyr::mutate(
    is_lizard = order == "Squamata" & !is.na(family) & !family %in% snake_families_in_download,
    coordinate_pair_complete = !is.na(decimal_latitude) & !is.na(decimal_longitude),
    coordinate_in_world_bounds = coordinate_pair_complete &
      dplyr::between(decimal_latitude, -90, 90) &
      dplyr::between(decimal_longitude, -180, 180),
    event_year = dplyr::coalesce(year_reported, suppressWarnings(as.integer(substr(event_date_raw, 1, 4)))),
    possible_duplicate_id = duplicated(source_record_id) | duplicated(source_record_id, fromLast = TRUE)
  )

lizard_records <- gsu_clean |>
  dplyr::filter(is_lizard)

lizard_mappable <- lizard_records |>
  dplyr::filter(coordinate_in_world_bounds)

if (anyDuplicated(lizard_mappable$source_record_id[!is.na(lizard_mappable$source_record_id)]) > 0) {
  stop("Georgia Southern source record IDs are duplicated among mappable lizards; inspect QA before mapping.")
}

lizard_sf <- sf::st_as_sf(
  lizard_mappable,
  coords = c("decimal_longitude", "decimal_latitude"),
  crs = 4326,
  remove = FALSE
)

write_csv_safe(gsu_clean, file.path(paths$clean, "gsu_herpetology_clean.csv"))
write_csv_safe(lizard_records, file.path(paths$clean, "gsu_lizards_clean.csv"))
sf::st_write(lizard_sf, file.path(paths$exports, "gsu_lizards_wgs84.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

gsu_qa <- tibble::tibble(
  check = c(
    "raw_rows", "clean_rows", "lizard_rows", "lizard_mappable_rows",
    "lizard_missing_coordinate_pair", "lizard_out_of_world_bounds",
    "lizard_duplicate_source_ids", "lizard_invalid_geometry"
  ),
  value = c(
    nrow(gsu_raw), nrow(gsu_clean), nrow(lizard_records), nrow(lizard_sf),
    sum(!lizard_records$coordinate_pair_complete),
    sum(lizard_records$coordinate_pair_complete & !lizard_records$coordinate_in_world_bounds),
    sum(lizard_records$possible_duplicate_id, na.rm = TRUE),
    sum(!sf::st_is_valid(lizard_sf))
  )
)
write_csv_safe(gsu_qa, file.path(paths$qa, "gsu_cleaning_qa.csv"))

family_qa <- lizard_records |>
  dplyr::count(family, sort = TRUE, name = "records") |>
  dplyr::mutate(operational_group = "lizard — included")
write_csv_safe(family_qa, file.path(paths$qa, "gsu_lizard_family_review.csv"))

log_message("Georgia Southern cleaning complete: ", nrow(lizard_records),
            " lizard records; ", nrow(lizard_sf), " have valid coordinate pairs.")

