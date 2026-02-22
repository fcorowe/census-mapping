# Census Mapping App

Interactive Shiny app with explanatory notes on the left and a choropleth map on the right, using Census 2021 TS068/TS006 data and OAC OA geometries.

## Run

From this folder:

```r
install.packages(c("shiny", "sf", "dplyr", "readr", "leaflet", "scales", "htmltools"))
shiny::runApp(".")
```

## Data bootstrap

The repo does not include large GeoPackage files in Git history.

Required file:
- `data/inputs/oac21.gpkg`

If missing, the app and helper script can download it using this env var:
- `CENSUS_MAPPING_OAC21_GPKG_URL`

Example:

```bash
export CENSUS_MAPPING_OAC21_GPKG_URL="https://<your-hosted-file>/oac21.gpkg"
Rscript scripts/get_data.R
```

## Files

- `app.R`: Shiny app
- `scripts/data_bootstrap.R`: runtime data checks/download helper
- `scripts/get_data.R`: manual bootstrap helper
- `www/styles.css`: layout and visual styling
- `data/inputs/*`: source data
