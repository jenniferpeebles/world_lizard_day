# Clean EDDMapS tegu observations and revisits ----------------------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("03_clean_eddmaps_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting EDDMapS cleaning.")

points_raw <- readRDS(file.path(paths$intermediate, "eddmaps_points_raw_import.rds"))
polygons_raw <- readRDS(file.path(paths$intermediate, "eddmaps_polygons_raw_import.rds"))
revisits_raw <- readRDS(file.path(paths$intermediate, "eddmaps_revisits_raw_import.rds"))

clean_edd_attributes <- function(x, date_field) {
  x |>
    dplyr::mutate(
      dplyr::across(where(is.character), clean_text_na),
      source = "EDDMapS",
      source_record_id = as.character(objectid),
      scientific_name = sci_name,
      common_name = com_name,
      observation_date_raw = .data[[date_field]],
      observation_date = parse_date_conservatively(.data[[date_field]]),
      observation_year = as.integer(format(observation_date, "%Y")),
      latitude_reported = suppressWarnings(as.numeric(latitude)),
      longitude_reported = suppressWarnings(as.numeric(longitude)),
      is_current_record = current_record == "1",
      is_verified = stringr::str_to_lower(verified) == "verified"
    )
}

points <- clean_edd_attributes(points_raw, "obs_date") |>
  sf::st_transform(4326)
points$geometry_valid <- sf::st_is_valid(points)
points$geometry_empty <- sf::st_is_empty(points)

polygons <- clean_edd_attributes(polygons_raw, "obs_date") |>
  sf::st_transform(4326)
polygons$geometry_valid <- sf::st_is_valid(polygons)
polygons$geometry_empty <- sf::st_is_empty(polygons)

revisits <- revisits_raw |>
  dplyr::mutate(
    dplyr::across(where(is.character), clean_text_na),
    source = "EDDMapS revisit",
    source_record_id = as.character(revisit_id),
    parent_observation_id = as.character(object_id),
    scientific_name = sci_name,
    common_name = com_name,
    observation_date_raw = revisit_date,
    observation_date = parse_date_conservatively(revisit_date),
    observation_year = as.integer(format(observation_date, "%Y")),
    is_current_record = current_record == "1",
    is_verified = stringr::str_to_lower(verified) == "verified"
  ) |>
  sf::st_transform(4326)
revisits$geometry_valid <- sf::st_is_valid(revisits)
revisits$geometry_empty <- sf::st_is_empty(revisits)

# Preserve non-current records in clean exports. The mapping step can display
# them separately; silently dropping them would erase source-system meaning.
sf::st_write(points, file.path(paths$exports, "eddmaps_tegu_points_wgs84.geojson"),
             delete_dsn = TRUE, quiet = TRUE)
sf::st_write(polygons, file.path(paths$exports, "eddmaps_tegu_polygons_wgs84.geojson"),
             delete_dsn = TRUE, quiet = TRUE)
sf::st_write(revisits, file.path(paths$exports, "eddmaps_tegu_revisits_wgs84.geojson"),
             delete_dsn = TRUE, quiet = TRUE)

write_csv_safe(sf::st_drop_geometry(points), file.path(paths$clean, "eddmaps_tegu_points_clean.csv"))
write_csv_safe(sf::st_drop_geometry(polygons), file.path(paths$clean, "eddmaps_tegu_polygons_clean.csv"))
write_csv_safe(sf::st_drop_geometry(revisits), file.path(paths$clean, "eddmaps_tegu_revisits_clean.csv"))

point_xy <- sf::st_coordinates(points)
coord_disagreement <- !is.na(points$latitude_reported) & !is.na(points$longitude_reported) &
  (abs(points$latitude_reported - point_xy[, "Y"]) > 0.00001 |
     abs(points$longitude_reported - point_xy[, "X"]) > 0.00001)

edd_qa <- tibble::tibble(
  check = c(
    "point_rows", "polygon_rows", "revisit_rows", "point_duplicate_object_ids",
    "point_invalid_geometry", "point_empty_geometry", "point_unverified",
    "point_non_current", "point_unparsed_dates", "point_reported_geometry_coord_disagreements",
    "revisit_unmatched_parent_ids"
  ),
  value = c(
    nrow(points), nrow(polygons), nrow(revisits),
    sum(duplicated(points$source_record_id) | duplicated(points$source_record_id, fromLast = TRUE)),
    sum(!points$geometry_valid), sum(points$geometry_empty), sum(!points$is_verified),
    sum(!points$is_current_record), sum(is.na(points$observation_date) & !is.na(points$observation_date_raw)),
    sum(coord_disagreement, na.rm = TRUE),
    sum(!revisits$parent_observation_id %in% points$source_record_id)
  )
)
write_csv_safe(edd_qa, file.path(paths$qa, "eddmaps_cleaning_qa.csv"))

write_csv_safe(
  points |> sf::st_drop_geometry() |>
    dplyr::count(status, verified, is_current_record, sort = TRUE, name = "records"),
  file.path(paths$qa, "eddmaps_status_review.csv")
)

log_message("EDDMapS cleaning complete: ", nrow(points), " points, ",
            nrow(polygons), " polygons and ", nrow(revisits), " revisits.")
