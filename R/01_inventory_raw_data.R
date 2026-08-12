# Inventory raw Georgia Southern and EDDMapS downloads --------------------

source("R/00_config.R")
source("R/helpers.R")
check_packages()

log_file <- file.path(paths$logs, paste0("01_inventory_", run_timestamp, ".log"))
options(world_lizard_log = log_file)
log_message("Starting raw-data inventory. Raw files will be read only.")

inventory <- purrr::imap_dfr(raw_files, function(path, source_key) {
  info <- file.info(path)
  normalized_path <- normalizePath(path, winslash = "/")
  normalized_project <- paste0(normalizePath(project_dir, winslash = "/"), "/")
  tibble::tibble(
    source_key = source_key,
    relative_path = if (startsWith(normalized_path, normalized_project)) {
      substring(normalized_path, nchar(normalized_project) + 1L)
    } else {
      normalized_path
    },
    extension = tools::file_ext(path),
    bytes = info$size,
    modified_local = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
    md5 = unname(tools::md5sum(path))
  )
})
write_csv_safe(inventory, file.path(paths$qa, "raw_file_inventory.csv"))

zip_inventory <- purrr::map_dfr(raw_files[c("gsu_dwca", "eddmaps")], function(path) {
  utils::unzip(path, list = TRUE) |>
    janitor::clean_names() |>
    dplyr::mutate(
      archive = sub(paste0(normalizePath(paths$raw, winslash = "/"), "/"), "", normalizePath(path, winslash = "/")),
      .before = 1
    )
})
write_csv_safe(zip_inventory, file.path(paths$qa, "raw_zip_member_inventory.csv"))

log_message("Reading Georgia Southern occurrence table from inside its ZIP archive.")
gsu_con <- unz(raw_files$gsu_dwca, "occurrence.txt", open = "rb")
gsu <- readr::read_tsv(
  gsu_con, na = c("", "NA"), quote = "", show_col_types = FALSE,
  progress = FALSE, name_repair = "minimal",
  col_types = readr::cols(.default = readr::col_character())
) |>
  janitor::clean_names()
close(gsu_con)
log_message("Georgia Southern occurrence rows: ", format(nrow(gsu), big.mark = ","),
            "; columns: ", ncol(gsu))

edd_vsi <- paste0("/vsizip/", normalizePath(raw_files$eddmaps, winslash = "/"))
log_message("Reading EDDMapS GeoPackages directly from inside its ZIP archive.")
edd_points <- sf::st_read(file.path(edd_vsi, "observations.gpkg"),
                          layer = "PointLayer", quiet = TRUE) |>
  janitor::clean_names()
edd_polygons <- sf::st_read(file.path(edd_vsi, "observations.gpkg"),
                            layer = "PolygonLayer", quiet = TRUE) |>
  janitor::clean_names()
edd_revisits <- sf::st_read(file.path(edd_vsi, "revisits.gpkg"),
                            layer = "PointLayer", quiet = TRUE) |>
  janitor::clean_names()
log_message("EDDMapS rows — points: ", nrow(edd_points),
            "; polygons: ", nrow(edd_polygons), "; revisits: ", nrow(edd_revisits))

dictionaries <- dplyr::bind_rows(
  data_dictionary(gsu, "Georgia Southern occurrence.txt"),
  data_dictionary(sf::st_drop_geometry(edd_points), "EDDMapS observations PointLayer"),
  data_dictionary(sf::st_drop_geometry(edd_polygons), "EDDMapS observations PolygonLayer"),
  data_dictionary(sf::st_drop_geometry(edd_revisits), "EDDMapS revisits PointLayer")
)
write_csv_safe(dictionaries, file.path(paths$qa, "raw_data_dictionary.csv"))

source_summary <- tibble::tribble(
  ~source, ~table_or_layer, ~rows, ~columns, ~geometry_type, ~crs,
  "Georgia Southern", "occurrence.txt", nrow(gsu), ncol(gsu), NA_character_, NA_character_,
  "EDDMapS", "observations.gpkg / PointLayer", nrow(edd_points), ncol(edd_points),
  paste(unique(as.character(sf::st_geometry_type(edd_points))), collapse = ";"), sf::st_crs(edd_points)$input,
  "EDDMapS", "observations.gpkg / PolygonLayer", nrow(edd_polygons), ncol(edd_polygons),
  paste(unique(as.character(sf::st_geometry_type(edd_polygons))), collapse = ";"), sf::st_crs(edd_polygons)$input,
  "EDDMapS", "revisits.gpkg / PointLayer", nrow(edd_revisits), ncol(edd_revisits),
  paste(unique(as.character(sf::st_geometry_type(edd_revisits))), collapse = ";"), sf::st_crs(edd_revisits)$input
)
write_csv_safe(source_summary, file.path(paths$qa, "raw_source_summary.csv"))

# Small reconnaissance tables guide cleaning without altering the sources.
if ("scientific_name" %in% names(gsu)) {
  gsu_taxa <- gsu |>
    dplyr::count(scientific_name, accepted_name_usage, taxon_rank, sort = TRUE, name = "records")
  write_csv_safe(gsu_taxa, file.path(paths$qa, "raw_gsu_taxa_counts.csv"))
}

edd_categories <- edd_points |>
  sf::st_drop_geometry() |>
  dplyr::count(sci_name, com_name, status, verified, current_record, sort = TRUE, name = "records")
write_csv_safe(edd_categories, file.path(paths$qa, "raw_eddmaps_category_counts.csv"))

saveRDS(gsu, file.path(paths$intermediate, "gsu_occurrence_raw_import.rds"), compress = "xz")
saveRDS(edd_points, file.path(paths$intermediate, "eddmaps_points_raw_import.rds"), compress = "xz")
saveRDS(edd_polygons, file.path(paths$intermediate, "eddmaps_polygons_raw_import.rds"), compress = "xz")
saveRDS(edd_revisits, file.path(paths$intermediate, "eddmaps_revisits_raw_import.rds"), compress = "xz")

writeLines(capture.output(sessionInfo()), file.path(paths$logs, "session_info.txt"))
log_message("Inventory complete. Intermediate R objects are copies; raw files are unchanged.")
