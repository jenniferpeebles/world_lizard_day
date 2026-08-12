# Run the complete World Lizard Day workflow in order.
scripts <- c(
  "R/01_inventory_raw_data.R",
  "R/02_clean_georgia_southern.R",
  "R/03_clean_eddmaps.R",
  "R/04_qa_and_maps.R",
  "R/05_build_public_release.R"
)

for (script in scripts) {
  message("\n===== RUNNING ", script, " =====")
  source(script, local = new.env(parent = globalenv()))
}

message("\nWorld Lizard Day workflow completed successfully.")
if (requireNamespace("beepr", quietly = TRUE)) beepr::beep(2)
