# Census Mapping App

Interactive Shiny app with explanatory notes on the left and a choropleth map on the right, using Census 2021 TS068 data and OA geometries.

## Run

From this folder:

```r
install.packages(c("shiny", "sf", "dplyr", "readr", "leaflet", "scales", "htmltools"))
shiny::runApp(".")
```

## Files

- `app.R`: Shiny app
- `www/styles.css`: layout and visual styling
- `data/inputs/*`: source data
