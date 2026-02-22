# Census Mapping App

This project contains an R Shiny application and a GitHub Pages wrapper site.

## Important: GitHub Pages and Shiny

GitHub Pages is static hosting and cannot run an R Shiny server directly.

Deployment pattern used here:
1. Deploy the Shiny app to a Shiny-capable host (e.g. shinyapps.io, Posit Connect, or your own Shiny Server).
2. Use GitHub Pages (`docs/`) as a static front-end that embeds that deployed app URL.

## Run locally

```r
install.packages(c("shiny", "sf", "dplyr", "readr", "leaflet", "scales", "htmltools"))
shiny::runApp(".")
```

## Data bootstrap

The repo does not keep large GeoPackage binaries in Git history.

Required file:
- `data/inputs/oac21.gpkg`

If missing, app startup and helper script can download it using env var:
- `CENSUS_MAPPING_OAC21_GPKG_URL`

Example:

```bash
export CENSUS_MAPPING_OAC21_GPKG_URL="https://<your-hosted-file>/oac21.gpkg"
Rscript scripts/get_data.R
```

Dropbox note:
- Use a shared link for `oac21.gpkg`; the bootstrap script auto-converts Dropbox preview links (`dl=0`) to direct download (`dl=1`).
- Example:
```bash
export CENSUS_MAPPING_OAC21_GPKG_URL="https://www.dropbox.com/scl/fi/<id>/oac21.gpkg?dl=0"
Rscript scripts/get_data.R
```

## GitHub Pages setup

1. Deploy your Shiny app and copy its public URL.
2. Edit `docs/config.js` and set:

```js
window.CENSUS_MAPPING_CONFIG = {
  SHINY_APP_URL: "https://<your-shiny-hosted-app-url>",
  TITLE: "Census Mapping"
};
```

3. Push to GitHub.
4. In GitHub repo settings: **Pages** -> Source: `Deploy from a branch` -> Branch: `main` / Folder: `/docs`.
5. Your Pages URL will serve the wrapper site and embed the live Shiny app.

## Key files

- `app.R`: Shiny app
- `scripts/data_bootstrap.R`: runtime data checks/download helper
- `scripts/get_data.R`: manual data bootstrap helper
- `docs/index.html`: GitHub Pages static wrapper
- `docs/config.js`: wrapper configuration (set embedded Shiny URL)
- `www/styles.css`: app styling
