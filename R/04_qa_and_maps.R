# Final QA, static maps, interactive map and reporter brief ----------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("04_qa_maps_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting final QA and mapping.")

gsu <- sf::st_read(file.path(paths$exports, "gsu_lizards_wgs84.geojson"), quiet = TRUE)
edd <- sf::st_read(file.path(paths$exports, "eddmaps_tegu_points_wgs84.geojson"), quiet = TRUE)
edd_polygons <- sf::st_read(file.path(paths$exports, "eddmaps_tegu_polygons_wgs84.geojson"), quiet = TRUE)
edd_revisits <- sf::st_read(file.path(paths$exports, "eddmaps_tegu_revisits_wgs84.geojson"), quiet = TRUE)

stopifnot(sf::st_crs(gsu)$epsg == 4326, sf::st_crs(edd)$epsg == 4326,
          sf::st_crs(edd_polygons)$epsg == 4326, sf::st_crs(edd_revisits)$epsg == 4326)

# The static map focuses on the Southeast so Florida and Georgia remain
# legible. Texas outliers remain available in the interactive map.
map_state_abbreviations <- c("FL", "GA", "AL", "MS", "LA", "SC", "NC", "TN")
boundary_vintage <- 2025L

log_message("Downloading/caching ", boundary_vintage,
            " Census cartographic state boundaries through tigris.")
southeast_states <- tigris::states(
  cb = TRUE,
  resolution = "20m",
  year = boundary_vintage,
  progress_bar = FALSE
) |>
  dplyr::filter(STUSPS %in% map_state_abbreviations) |>
  sf::st_transform(4326)

georgia_counties <- tigris::counties(
  state = "GA",
  cb = TRUE,
  resolution = "20m",
  year = boundary_vintage,
  progress_bar = FALSE
) |>
  sf::st_transform(4326)

highlight_county_names <- c("Tattnall", "Toombs")
highlight_counties <- georgia_counties |>
  dplyr::filter(NAME %in% highlight_county_names)

if (nrow(southeast_states) != length(map_state_abbreviations)) {
  stop("The tigris state download did not return every requested Southeast state.")
}
if (nrow(georgia_counties) != 159L) {
  stop("Expected 159 Georgia counties from tigris; received ", nrow(georgia_counties), ".")
}
if (nrow(highlight_counties) != length(highlight_county_names)) {
  stop("Tattnall and Toombs counties were not both found in the tigris layer.")
}

# Calculate label anchors in a projected CRS, then return them to WGS84.
# EPSG:5070 is appropriate for this intermediate contiguous-U.S. operation.
state_label_points <- suppressWarnings(
  sf::st_transform(
    sf::st_point_on_surface(sf::st_transform(southeast_states, 5070)),
    4326
  )
)
state_label_xy <- sf::st_coordinates(state_label_points)
state_labels <- state_label_points |>
  sf::st_drop_geometry() |>
  dplyr::mutate(label_x = state_label_xy[, "X"], label_y = state_label_xy[, "Y"])

highlight_label_points <- suppressWarnings(
  sf::st_transform(
    sf::st_point_on_surface(sf::st_transform(highlight_counties, 5070)),
    4326
  )
)
highlight_label_xy <- sf::st_coordinates(highlight_label_points)
highlight_labels <- highlight_label_points |>
  sf::st_drop_geometry() |>
  dplyr::mutate(
    label_x = highlight_label_xy[, "X"],
    label_y = highlight_label_xy[, "Y"],
    label_x_display = dplyr::if_else(NAME == "Toombs", label_x - 0.45, label_x + 0.50),
    label_y_display = dplyr::if_else(NAME == "Toombs", label_y + 0.20, label_y - 0.20)
  )

study_bbox <- sf::st_bbox(
  c(xmin = -94.2, ymin = 24.2, xmax = -75.3, ymax = 36.8),
  crs = sf::st_crs(4326)
)
gsu_southeast <- suppressWarnings(sf::st_crop(gsu, study_bbox))
edd_southeast <- suppressWarnings(sf::st_crop(edd, study_bbox))

boundary_metadata <- dplyr::bind_rows(
  tibble::tibble(
    geography = "Selected Southeast states",
    feature_count = nrow(southeast_states),
    highlighted_features = NA_character_,
    source = "U.S. Census Bureau cartographic boundary files via tigris",
    vintage = boundary_vintage,
    resolution = "1:20,000,000",
    final_crs = "EPSG:4326"
  ),
  tibble::tibble(
    geography = "Georgia counties",
    feature_count = nrow(georgia_counties),
    highlighted_features = paste(highlight_county_names, collapse = ", "),
    source = "U.S. Census Bureau cartographic boundary files via tigris",
    vintage = boundary_vintage,
    resolution = "1:20,000,000",
    final_crs = "EPSG:4326"
  )
)
write_csv_safe(boundary_metadata, file.path(paths$qa, "map_boundary_metadata.csv"))

final_qa <- tibble::tibble(
  check = c(
    "gsu_geojson_rows", "gsu_southeast_map_rows", "edd_geojson_rows",
    "edd_southeast_map_rows", "edd_current_rows", "edd_non_current_rows",
    "edd_positive_rows", "edd_treated_rows", "all_exports_wgs84"
  ),
  value = c(
    nrow(gsu), nrow(gsu_southeast), nrow(edd), nrow(edd_southeast),
    sum(edd$is_current_record, na.rm = TRUE), sum(!edd$is_current_record, na.rm = TRUE),
    sum(edd$status == "Positive", na.rm = TRUE), sum(edd$status == "Treated", na.rm = TRUE),
    1
  )
)
write_csv_safe(final_qa, file.path(paths$qa, "final_mapping_qa.csv"))

year_summary <- dplyr::bind_rows(
  edd |> sf::st_drop_geometry() |>
    dplyr::count(observation_year, status, name = "records") |>
    dplyr::mutate(source = "EDDMapS", .before = 1),
  gsu |> sf::st_drop_geometry() |>
    dplyr::count(event_year, name = "records") |>
    dplyr::transmute(source = "Georgia Southern", observation_year = event_year,
                     status = NA_character_, records)
)
write_csv_safe(year_summary, file.path(paths$qa, "mapped_records_by_year.csv"))

map_points <- edd_southeast |>
  dplyr::mutate(
    map_group = dplyr::case_when(
      status == "Positive" ~ "Tegu present",
      status == "Treated" ~ "Tegu present; control applied",
      TRUE ~ paste0("EDDMapS tegu: ", status)
    )
  ) |>
  dplyr::select(map_group)

map_colors <- c(
  "Tegu present" = "#CC4778",
  "Tegu present; control applied" = "#0D0887"
)

map_world_lizard_sources_base <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = southeast_states,
    fill = "#F3F0E8", color = "#9A9A9A", linewidth = 0.45
  ) +
  ggplot2::geom_sf(
    data = georgia_counties,
    fill = NA, color = "#C5C5C5", linewidth = 0.18
  ) +
  ggplot2::geom_sf(
    data = highlight_counties,
    fill = "#6BAED6", color = "#174A7E", linewidth = 0.9, alpha = 0.58
  ) +
  ggplot2::geom_sf(
    data = map_points, ggplot2::aes(color = map_group),
    size = 0.9, alpha = 0.42, inherit.aes = FALSE
  ) +
  ggplot2::geom_text(
    data = state_labels,
    ggplot2::aes(x = label_x, y = label_y, label = STUSPS),
    color = "#666666", size = 3.2, fontface = "bold",
    inherit.aes = FALSE
  ) +
  ggplot2::geom_segment(
    data = highlight_labels,
    ggplot2::aes(x = label_x, y = label_y, xend = label_x_display, yend = label_y_display),
    color = "#174A7E", linewidth = 0.35, inherit.aes = FALSE
  ) +
  ggplot2::geom_label(
    data = highlight_labels,
    ggplot2::aes(x = label_x_display, y = label_y_display, label = NAME),
    color = "#174A7E", fill = "white", alpha = 0.88,
    size = 2.4, fontface = "bold", linewidth = 0.15,
    inherit.aes = FALSE
  ) +
  ggplot2::coord_sf(xlim = c(-94.2, -75.3), ylim = c(24.2, 36.8), expand = FALSE,
                    datum = NA) +
  ggplot2::scale_color_manual(values = map_colors, name = "EDDMapS status") +
  ggplot2::labs(
    title = "Reported Argentine black and white tegu observations",
    subtitle = paste0(
      "EDDMapS 'treated' means the tegu was present and control was applied; it does not mean eradicated.\n",
      "Tattnall and Toombs counties, Georgia, are highlighted. Points are not rates or prevalence."
    ),
    caption = stringr::str_wrap(paste0(
      "Sources: EDDMapS; ",
      boundary_vintage, " Census cartographic state/county boundaries via tigris. ",
      "WGS84. Object: map_world_lizard_sources. Created ", run_date, "."
    ), width = 145)
  ) +
  theme_ajc_map() +
  ggplot2::theme(
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.box = "horizontal"
  )

map_world_lizard_sources_review_base <- map_world_lizard_sources_base +
  ggplot2::annotate(
    "text", x = -84.8, y = 30.4, label = "NOT FOR PUBLICATION",
    angle = 35, alpha = 0.16, size = 13, fontface = "bold", color = "gray35"
  )

tegu_photo_path <- file.path(
  project_dir, "assets", "argentine_black_and_white_tegu_tomfriedel_cc_by_3.jpg"
)
if (!file.exists(tegu_photo_path)) {
  stop("Licensed tegu photo is missing: ", tegu_photo_path)
}

compose_tegu_map <- function(base_plot) {
  cowplot::ggdraw(base_plot) +
    cowplot::draw_grob(
      grid::rectGrob(gp = grid::gpar(fill = "white", col = "#666666", lwd = 0.6)),
      x = 0.025, y = 0.155, width = 0.27, height = 0.215
    ) +
    cowplot::draw_image(
      tegu_photo_path,
      x = 0.032, y = 0.19, width = 0.256, height = 0.17
    ) +
    cowplot::draw_label(
      "Argentine black and white tegu\nPhoto: Tomfriedel/Wikimedia Commons, CC BY 3.0",
      x = 0.035, y = 0.175,
      hjust = 0, vjust = 0.5, size = 6.5, color = "#444444"
    )
}

map_world_lizard_sources <- compose_tegu_map(map_world_lizard_sources_review_base)
map_world_lizard_sources_threads <- compose_tegu_map(map_world_lizard_sources_base)

map_world_lizard_sources
map_world_lizard_sources_threads

static_map_path <- file.path(
  paths$maps, paste0("world_lizard_sources_", format(run_date, "%Y-%m-%d"), ".jpg")
)
ggplot2::ggsave(static_map_path, map_world_lizard_sources,
                width = 11, height = 7, dpi = 300, bg = "white")
log_message("Wrote static review map: ", public_path_label(static_map_path))

threads_map_path <- file.path(
  paths$maps, paste0("world_lizard_sources_threads_", format(run_date, "%Y-%m-%d"), ".jpg")
)
ggplot2::ggsave(threads_map_path, map_world_lizard_sources_threads,
                width = 11, height = 7, dpi = 300, bg = "white")
log_message("Wrote Threads-ready map without review watermark: ",
            public_path_label(threads_map_path))

popup_edd <- paste0(
  "<strong>", edd$common_name, "</strong><br>",
  "Status: ", edd$status, "<br>",
  "Observed: ", edd$observation_date_raw, "<br>",
  "Current record: ", edd$is_current_record, "<br>",
  "EDDMapS object ID: ", edd$source_record_id
)
interactive_lizard_map <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
  leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron,
                            group = "Reference basemap") |>
  leaflet::addPolygons(
    data = southeast_states, fill = FALSE, color = "#666666", weight = 1,
    opacity = 0.8, label = ~paste0(NAME, " (", STUSPS, ")"),
    group = paste0(boundary_vintage, " Census state boundaries")
  ) |>
  leaflet::addPolygons(
    data = georgia_counties, fill = FALSE, color = "#A8A8A8", weight = 0.6,
    opacity = 0.7, group = paste0(boundary_vintage, " Georgia county boundaries")
  ) |>
  leaflet::addPolygons(
    data = highlight_counties, fillColor = "#2F6FB0", fillOpacity = 0.35,
    color = "#174A7E", weight = 2, label = ~paste0(NAME, " County, Georgia"),
    group = "Tattnall and Toombs counties"
  ) |>
  leaflet::addCircleMarkers(
    data = edd |> dplyr::filter(status == "Positive"),
    radius = 3, stroke = FALSE, fillOpacity = 0.55, color = map_colors[["Tegu present"]],
    popup = popup_edd[edd$status == "Positive"], group = "Tegu present"
  ) |>
  leaflet::addCircleMarkers(
    data = edd |> dplyr::filter(status == "Treated"),
    radius = 3, stroke = FALSE, fillOpacity = 0.45, color = map_colors[["Tegu present; control applied"]],
    popup = popup_edd[edd$status == "Treated"], group = "Tegu present; control applied"
  ) |>
  leaflet::addPolygons(
    data = edd_polygons, color = map_colors[["Tegu present"]], weight = 2,
    fillOpacity = 0.15, group = "EDDMapS: polygons"
  ) |>
  leaflet::addLayersControl(
    overlayGroups = c(paste0(boundary_vintage, " Census state boundaries"),
                      paste0(boundary_vintage, " Georgia county boundaries"),
                      "Tattnall and Toombs counties",
                      "Tegu present", "Tegu present; control applied", "EDDMapS: polygons"),
    options = leaflet::layersControlOptions(collapsed = FALSE)
  ) |>
  leaflet::addControl(
    html = "<strong>NOT FOR PUBLICATION</strong><br>Different source systems; points are not prevalence rates.",
    position = "bottomleft"
  )

interactive_lizard_map

interactive_path <- file.path(paths$maps, paste0(
  "world_lizard_sources_interactive_", format(run_date, "%Y-%m-%d"), ".html"
))
htmlwidgets::saveWidget(interactive_lizard_map, interactive_path, selfcontained = FALSE)
log_message("Wrote interactive review map: ", public_path_label(interactive_path))

top_species <- gsu |> sf::st_drop_geometry() |>
  dplyr::count(scientific_name, sort = TRUE, name = "records") |>
  dplyr::slice_head(n = 5)
edd_min_year <- suppressWarnings(min(edd$observation_year, na.rm = TRUE))
edd_max_year <- suppressWarnings(max(edd$observation_year, na.rm = TRUE))
treated_share <- mean(edd$status == "Treated", na.rm = TRUE)

brief <- c(
  "# Reporter Brief",
  "",
  "## Top findings",
  paste0("- The EDDMapS download contains ", scales::comma(nrow(edd)),
         " verified Argentine black and white tegu point records. Of those, ",
         scales::comma(sum(edd$status == "Treated")), " (", scales::percent(treated_share, accuracy = 0.1),
         ") are labeled `Treated`; treatment status should not be interpreted as confirmed eradication."),
  paste0("- The Georgia Southern archive contains ", scales::comma(nrow(readRDS(file.path(paths$intermediate, "gsu_occurrence_raw_import.rds")))),
         " herpetology occurrences. The transparent family-based filter identifies ",
         scales::comma(nrow(readr::read_csv(file.path(paths$clean, "gsu_lizards_clean.csv"), show_col_types = FALSE))), " lizard records."),
  paste0("- Only ", scales::comma(nrow(gsu)), " Georgia Southern lizard records have valid coordinate pairs, so the museum map represents ",
         scales::percent(nrow(gsu) / nrow(readr::read_csv(file.path(paths$clean, "gsu_lizards_clean.csv"), show_col_types = FALSE)), accuracy = 0.1),
         " of the identified lizard records."),
  "",
  "## Best story-ready statistics",
  paste0("- EDDMapS point records span observation years ", edd_min_year, " through ", edd_max_year, "."),
  paste0("- EDDMapS includes ", sum(edd$is_current_record), " current and ", sum(!edd$is_current_record), " non-current point records."),
  paste0("- The most common Georgia Southern lizard taxon in the archive is *", top_species$scientific_name[[1]], "* (", scales::comma(top_species$records[[1]]), " records)."),
  "",
  "## Biggest outliers",
  "- One of the three EDDMapS revisit rows does not match a parent observation object ID in this download. It should be checked before revisit analysis.",
  "- Georgia Southern coordinate missingness is the dominant limitation: 1,629 of 1,806 operationally identified lizard records cannot be mapped.",
  "",
  "## Local examples",
  "- Use the interactive map to inspect EDDMapS tegu records. Do not treat clustered points as a population estimate without accounting for reporting effort.",
  "",
  "## Possible story angles",
  "- Where are positive tegu observations still being reported relative to treated records? This is a reporting lead, not proof of control success or failure.",
  "- What explains the museum archive's low georeferencing rate, and could priority specimens be georeferenced for research and public use?",
  "",
  "## Caveats / don't-overstate notes",
  "- These sources have different missions, time spans and collection methods. Never compare their raw counts as prevalence, risk or effort.",
  "- EDDMapS is occurrence/reporting data. Absence of a report is not evidence that tegus are absent.",
  "- `Treated` is a source-system status; this workflow does not establish that an animal or population was eradicated.",
  "- The lizard definition is operational: order Squamata excluding the four snake families present in this archive. Review `outputs/qa/gsu_lizard_family_review.csv` if taxonomy changes.",
  "- No values were imputed. Missing coordinates and dates remain missing.",
  "",
  "## Suggested charts or maps",
  "- Map positive and treated EDDMapS records as separate layers and let readers toggle them.",
  "- Plot yearly record counts only after checking for changes in reporting practices or platform coverage."
)
writeLines(brief, file.path(paths$outputs, "reporter_brief.md"), useBytes = TRUE)
write_csv_safe(final_qa, file.path(paths$outputs, "reporter_brief.csv"))

log_message("Final QA and mapping complete.")
