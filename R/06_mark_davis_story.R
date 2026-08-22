# Georgia-only EDDMapS exports and internal review map --------------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("06_mark_davis_story_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting Georgia-only exports for the Mark Davis story.")

story_dir <- file.path(paths$outputs, "mark_davis_story")
dir.create(story_dir, recursive = TRUE, showWarnings = FALSE)

points_path <- file.path(paths$exports, "eddmaps_tegu_points_wgs84.geojson")
revisits_path <- file.path(paths$exports, "eddmaps_tegu_revisits_wgs84.geojson")

if (!file.exists(points_path) || !file.exists(revisits_path)) {
  stop("Run R/03_clean_eddmaps.R before R/06_mark_davis_story.R.")
}

points <- sf::st_read(points_path, quiet = TRUE) |>
  sf::st_transform(4326)
revisits <- sf::st_read(revisits_path, quiet = TRUE) |>
  sf::st_transform(4326)

boundary_vintage <- 2025L
georgia <- tigris::states(
  cb = TRUE, resolution = "500k", year = boundary_vintage,
  progress_bar = FALSE
) |>
  dplyr::filter(STUSPS == "GA") |>
  sf::st_transform(4326)

georgia_counties <- tigris::counties(
  state = "GA", cb = TRUE, resolution = "500k", year = boundary_vintage,
  progress_bar = FALSE
) |>
  sf::st_transform(4326)

story_counties <- georgia_counties |>
  dplyr::filter(NAME %in% c("Tattnall", "Toombs")) |>
  dplyr::select(GEOID, NAME, NAMELSAD, geometry)

if (nrow(georgia) != 1L) stop("Expected one Georgia state feature.")
if (nrow(georgia_counties) != 159L) stop("Expected 159 Georgia counties.")
if (nrow(story_counties) != 2L) stop("Expected Tattnall and Toombs counties.")

# Use geometry, not a locality text field, to make the Georgia subset. This
# treats points on the state boundary as Georgia records and avoids spelling
# and formatting differences in EDDMapS location labels.
points_ga <- points[lengths(sf::st_intersects(points, georgia)) > 0, ]
revisits_ga <- revisits[lengths(sf::st_intersects(revisits, georgia)) > 0, ]

extract_point_table <- function(x, revisit = FALSE) {
  xy <- sf::st_coordinates(x)
  if (nrow(x) == 0L) {
    latitude <- numeric()
    longitude <- numeric()
  } else {
    latitude <- xy[, 2]
    longitude <- xy[, 1]
  }
  base <- x |>
    sf::st_drop_geometry() |>
    dplyr::mutate(
      latitude = latitude,
      longitude = longitude,
      .after = dplyr::last_col()
    )

  if (revisit) {
    base |>
      dplyr::transmute(
        source,
        revisit_id = source_record_id,
        parent_observation_id,
        scientific_name,
        common_name,
        revisit_date = as.character(observation_date),
        revisit_year = observation_year,
        status,
        verified = is_verified,
        current_record = is_current_record,
        latitude,
        longitude
      )
  } else {
    base |>
      dplyr::transmute(
        source,
        observation_id = source_record_id,
        scientific_name,
        common_name,
        observation_date = as.character(observation_date),
        observation_year,
        occurrence_status = occ_status,
        management_status = status,
        verified = is_verified,
        current_record = is_current_record,
        latitude,
        longitude
      )
  }
}

points_ga_csv <- extract_point_table(points_ga)
revisits_ga_csv <- extract_point_table(revisits_ga, revisit = TRUE)

points_csv_path <- file.path(story_dir, "eddmaps_tegu_sightings_georgia.csv")
revisits_csv_path <- file.path(story_dir, "eddmaps_tegu_revisits_georgia.csv")
counties_geojson_path <- file.path(story_dir, "toombs_tattnall_counties_wgs84.geojson")

write_csv_safe(points_ga_csv, points_csv_path)
write_csv_safe(revisits_ga_csv, revisits_csv_path)
sf::st_write(
  story_counties, counties_geojson_path,
  driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE
)

county_label_points <- suppressWarnings(
  story_counties |>
    sf::st_transform(5070) |>
    sf::st_point_on_surface() |>
    sf::st_transform(4326)
)
county_label_xy <- sf::st_coordinates(county_label_points)
county_labels <- county_label_points |>
  sf::st_drop_geometry() |>
  dplyr::mutate(
    x = county_label_xy[, "X"],
    y = county_label_xy[, "Y"],
    label_x = dplyr::if_else(NAME == "Toombs", x - 0.42, x + 0.48),
    label_y = dplyr::if_else(NAME == "Toombs", y + 0.24, y - 0.23)
  )

map_plot <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = georgia_counties,
    fill = "#F5F2EA", color = "#B8B8B8", linewidth = 0.25
  ) +
  ggplot2::geom_sf(
    data = story_counties,
    fill = "#B7D7E8", color = "#255A74", linewidth = 0.8
  ) +
  ggplot2::geom_sf(
    data = points_ga,
    ggplot2::aes(color = "EDDMapS sighting"),
    size = 2.1, alpha = 0.72, shape = 16
  ) +
  ggplot2::geom_sf(
    data = revisits_ga,
    ggplot2::aes(color = "EDDMapS revisit"),
    size = 2.6, alpha = 0.9, shape = 17
  ) +
  ggplot2::geom_segment(
    data = county_labels,
    ggplot2::aes(x = x, y = y, xend = label_x, yend = label_y),
    color = "#255A74", linewidth = 0.35
  ) +
  ggplot2::geom_text(
    data = county_labels,
    ggplot2::aes(x = label_x, y = label_y, label = NAME),
    color = "#173E50", size = 3.2, fontface = "bold"
  ) +
  ggplot2::coord_sf(datum = NA, expand = FALSE) +
  ggplot2::scale_color_manual(
    values = c("EDDMapS sighting" = "#C23B55", "EDDMapS revisit" = "#553C9A"),
    name = NULL
  ) +
  ggplot2::labs(
    title = "Reported Argentine black and white tegu records in Georgia",
    subtitle = paste0(
      scales::comma(nrow(points_ga)), " sightings and ",
      scales::comma(nrow(revisits_ga)), " follow-up revisits in this EDDMapS download"
    ),
    caption = paste0(
      "Sources: EDDMapS; ", boundary_vintage,
      " U.S. Census Bureau cartographic boundaries via tigris. ",
      "Reports are not a population estimate. WGS84. Created ", run_date, "."
    )
  ) +
  theme_ajc_map() +
  ggplot2::theme(
    legend.position = "bottom",
    plot.margin = ggplot2::margin(14, 18, 14, 18)
  ) +
  ggplot2::annotate(
    "text", x = -83.7, y = 32.4,
    label = "AJC • INTERNAL REVIEW",
    angle = 32, alpha = 0.16, size = 11,
    fontface = "bold", color = "gray30"
  )

map_png_path <- file.path(story_dir, "tegu_records_georgia_internal_review.png")
map_jpg_path <- file.path(story_dir, "tegu_records_georgia_internal_review.jpg")
ggplot2::ggsave(map_png_path, map_plot, width = 10, height = 8, dpi = 300, bg = "white")
ggplot2::ggsave(map_jpg_path, map_plot, width = 10, height = 8, dpi = 300, bg = "white")

qa <- tibble::tibble(
  output = c("Georgia sightings CSV", "Georgia revisits CSV", "Two-county GeoJSON"),
  feature_count = c(nrow(points_ga_csv), nrow(revisits_ga_csv), nrow(story_counties)),
  crs = c("longitude/latitude WGS84", "longitude/latitude WGS84", "EPSG:4326"),
  geometry_valid = c(
    all(sf::st_is_valid(points_ga)),
    all(sf::st_is_valid(revisits_ga)),
    all(sf::st_is_valid(story_counties))
  )
)
write_csv_safe(qa, file.path(story_dir, "mark_davis_story_qa.csv"))

log_message(
  "Georgia-only story package complete: ", nrow(points_ga), " sightings, ",
  nrow(revisits_ga), " revisits and ", nrow(story_counties), " county polygons."
)
