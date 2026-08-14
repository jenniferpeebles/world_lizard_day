# Reusable helpers for World Lizard Day -----------------------------------

required_packages <- c(
  "dplyr", "readr", "stringr", "tidyr", "purrr", "tibble", "janitor",
  "sf", "ggplot2", "scales", "leaflet", "htmlwidgets", "jsonlite", "tigris",
  "cowplot", "jpeg"
)

check_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Install required package(s) before continuing: ",
         paste(missing, collapse = ", "))
  }
  invisible(TRUE)
}

log_message <- function(..., log_file = getOption("world_lizard_log")) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ", paste0(..., collapse = ""))
  message(line)
  if (!is.null(log_file)) cat(line, "\n", file = log_file, append = TRUE)
  invisible(line)
}

public_path_label <- function(path) {
  normalized_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  normalized_root <- paste0(normalizePath(getwd(), winslash = "/"), "/")
  if (startsWith(normalized_path, normalized_root)) {
    substring(normalized_path, nchar(normalized_root) + 1L)
  } else {
    basename(normalized_path)
  }
}

write_csv_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  log_message("Wrote ", nrow(x), " rows to ", public_path_label(path))
  invisible(path)
}

sha256_file <- function(path) {
  unname(tools::md5sum(path)) # Base R provides MD5 reliably; column is named accordingly.
}

data_dictionary <- function(x, source_name) {
  tibble::tibble(
    source = source_name,
    field_order = seq_along(x),
    field_name = names(x),
    r_class = vapply(x, function(z) paste(class(z), collapse = ";"), character(1)),
    non_missing_n = vapply(x, function(z) sum(!is.na(z)), numeric(1)),
    missing_n = vapply(x, function(z) sum(is.na(z)), numeric(1)),
    distinct_n = vapply(x, function(z) dplyr::n_distinct(z, na.rm = TRUE), numeric(1)),
    example_value = vapply(x, function(z) {
      vals <- unique(as.character(z[!is.na(z)]))
      if (length(vals) == 0) NA_character_ else stringr::str_trunc(vals[[1]], 100)
    }, character(1))
  )
}

clean_text_na <- function(x) {
  x <- stringr::str_squish(as.character(x))
  dplyr::na_if(x, "")
}

parse_date_conservatively <- function(x) {
  # Parse only explicit values; never fill or infer a missing date.
  suppressWarnings(as.Date(x, tryFormats = c(
    "%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%m/%d/%y",
    "%Y-%m-%d %H:%M:%S", "%m/%d/%Y %H:%M:%S"
  )))
}

add_ajc_watermark <- function(label = "NOT FOR PUBLICATION") {
  ggplot2::annotate(
    "text", x = -Inf, y = Inf, label = label,
    hjust = -0.05, vjust = 1.2, angle = 35,
    alpha = 0.22, size = 8, fontface = "bold", color = "gray40"
  )
}

theme_ajc_map <- function() {
  ggplot2::theme_void() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 16),
      plot.subtitle = ggplot2::element_text(size = 11),
      plot.caption = ggplot2::element_text(size = 8, color = "gray35"),
      legend.position = "right"
    )
}
