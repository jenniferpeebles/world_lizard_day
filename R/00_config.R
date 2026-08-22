# =========================================================
# WORLD LIZARD DAY: PROJECT CONFIGURATION
# =========================================================

options(
  tigris_use_cache = TRUE,
  scipen = 999,
  digits = 3,
  stringsAsFactors = FALSE
)

library("tidyverse")

# Run scripts from the repository root. The project path is resolved at run
# time so usernames, employers and machine-specific paths are never embedded
# in version-controlled code. Do not put ordinary settings in .Renviron; that
# file is reserved for secrets and is excluded from Git.
project_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)

if (!dir.exists(project_dir)) {
  stop("Project directory does not exist. Update project_dir in R/00_config.R.")
}

setwd(project_dir)
if (normalizePath(getwd(), winslash = "/") != normalizePath(project_dir, winslash = "/")) {
  stop("Whoa, partner! Your working directory is not set correctly!")
}

run_date <- Sys.Date()
run_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

paths <- list(
  raw = file.path(project_dir, "data", "data_raw"),
  clean = file.path(project_dir, "data", "data_clean"),
  intermediate = file.path(project_dir, "data", "data_intermediate"),
  exports = file.path(project_dir, "exports"),
  outputs = file.path(project_dir, "outputs"),
  qa = file.path(project_dir, "outputs", "qa"),
  maps = file.path(project_dir, "outputs", "maps"),
  logs = file.path(project_dir, "logs"),
  docs = file.path(project_dir, "docs"),
  public = file.path(project_dir, "public")
)

invisible(lapply(paths[names(paths) != "raw"], dir.create,
                 recursive = TRUE, showWarnings = FALSE))

raw_files <- list(
  gsu_dwca = file.path(paths$raw, "ga_southern", "dwca-gsu_herps-v6.1.zip"),
  gsu_eml = file.path(paths$raw, "ga_southern", "eml-gsu_herps-v6.1 (1).xml"),
  gsu_rtf = file.path(paths$raw, "ga_southern", "rtf-gsu_herps-v6.1.rtf"),
  eddmaps = file.path(paths$raw, "tegus", "62459.zip")
)

missing_inputs <- names(raw_files)[!file.exists(unlist(raw_files))]
if (length(missing_inputs) > 0) {
  stop(
    "Missing expected raw input(s): ", paste(missing_inputs, collapse = ", "), "\n",
    "Download the Georgia Southern archive from:\n",
    "  http://ipt.vertnet.org:8080/ipt/resource?r=gsu_herps\n",
    "Download Argentine black and white tegu data from:\n",
    "  https://www.eddmaps.org/species/subject.cfm?sub=82961\n",
    "Then place and name the files as documented in data/README.md."
  )
}

message("Project root resolved successfully.")
message("Run timestamp: ", run_timestamp)
