#!/usr/bin/env Rscript

source("scripts/data_bootstrap.R")

required <- c(
  "data/inputs/census2021-ts068/census2021-ts068-oa.csv",
  "data/inputs/census2021-ts006/census2021-ts006-oa.csv",
  "data/inputs/oac21.gpkg"
)

ensure_required_data(
  required_files = required,
  env_url_map = c("data/inputs/oac21.gpkg" = "CENSUS_MAPPING_OAC21_GPKG_URL")
)

cat("All required data files are present.\n")
