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

study_bbox <- sf::st_bbox(c(xmin = -100, ymin = 24, xmax = -79, ymax = 36), crs = sf::st_crs(4326))
gsu_southeast <- suppressWarnings(sf::st_crop(gsu, study_bbox))
edd_southeast <- suppressWarnings(sf::st_crop(edd, study_bbox))

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

map_points <- dplyr::bind_rows(
  edd_southeast |>
    dplyr::mutate(map_group = paste0("EDDMapS — ", status)) |>
    dplyr::select(map_group),
  gsu_southeast |>
    dplyr::mutate(map_group = "Georgia Southern — museum record") |>
    dplyr::select(map_group)
)

map_colors <- c(
  "EDDMapS — Positive" = "#CC4778",
  "EDDMapS — Treated" = "#0D0887",
  "Georgia Southern — museum record" = "#F89441"
)

map_world_lizard_sources <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = map_points, ggplot2::aes(color = map_group),
    size = 0.8, alpha = 0.32, inherit.aes = FALSE
  ) +
  ggplot2::coord_sf(xlim = c(-100, -79), ylim = c(24, 36), expand = FALSE,
                    datum = NA) +
  ggplot2::scale_color_manual(values = map_colors, name = "Record type") +
  ggplot2::labs(
    title = "Museum lizard records and reported tegu observations",
    subtitle = "Southeast review extent; points should not be compared as rates or prevalence",
    caption = paste0(
      "Sources: Georgia Southern University Herpetology Collection; EDDMapS. WGS84. ",
      "Map object: map_world_lizard_sources. Created ", run_date, "."
    )
  ) +
  theme_ajc_map() +
  ggplot2::annotate(
    "text", x = -89.5, y = 30, label = "NOT FOR PUBLICATION",
    angle = 35, alpha = 0.16, size = 13, fontface = "bold", color = "gray35"
  )

map_world_lizard_sources

static_map_path <- file.path(
  paths$maps, paste0("world_lizard_sources_", format(run_date, "%Y-%m-%d"), ".jpg")
)
ggplot2::ggsave(static_map_path, map_world_lizard_sources,
                width = 11, height = 7, dpi = 300, bg = "white")
log_message("Wrote static review map: ", public_path_label(static_map_path))

popup_edd <- paste0(
  "<strong>", edd$common_name, "</strong><br>",
  "Status: ", edd$status, "<br>",
  "Observed: ", edd$observation_date_raw, "<br>",
  "Current record: ", edd$is_current_record, "<br>",
  "EDDMapS object ID: ", edd$source_record_id
)
popup_gsu <- paste0(
  "<strong>", gsu$scientific_name, "</strong><br>",
  "Family: ", gsu$family, "<br>",
  "Event date: ", gsu$event_date_raw, "<br>",
  "Catalog number: ", gsu$catalog_number
)

interactive_lizard_map <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
  leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron,
                            group = "Reference basemap") |>
  leaflet::addCircleMarkers(
    data = edd |> dplyr::filter(status == "Positive"),
    radius = 3, stroke = FALSE, fillOpacity = 0.55, color = map_colors[["EDDMapS — Positive"]],
    popup = popup_edd[edd$status == "Positive"], group = "EDDMapS — Positive"
  ) |>
  leaflet::addCircleMarkers(
    data = edd |> dplyr::filter(status == "Treated"),
    radius = 3, stroke = FALSE, fillOpacity = 0.45, color = map_colors[["EDDMapS — Treated"]],
    popup = popup_edd[edd$status == "Treated"], group = "EDDMapS — Treated"
  ) |>
  leaflet::addPolygons(
    data = edd_polygons, color = map_colors[["EDDMapS — Positive"]], weight = 2,
    fillOpacity = 0.15, group = "EDDMapS — polygons"
  ) |>
  leaflet::addCircleMarkers(
    data = gsu, radius = 4, weight = 1, fillOpacity = 0.65,
    color = map_colors[["Georgia Southern — museum record"]],
    popup = popup_gsu, group = "Georgia Southern — museum records"
  ) |>
  leaflet::addLayersControl(
    overlayGroups = c("EDDMapS — Positive", "EDDMapS — Treated", "EDDMapS — polygons",
                      "Georgia Southern — museum records"),
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
  "- Use the interactive map to inspect named EDDMapS locations and Georgia Southern catalog records. Do not treat clustered points as a population estimate without accounting for reporting effort.",
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
