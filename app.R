library(shiny)
library(sf)
library(dplyr)
library(readr)
library(leaflet)
library(scales)
library(htmltools)

options(shiny.autoreload = TRUE)

ts068_path <- "data/inputs/census2021-ts068/census2021-ts068-oa.csv"
ts006_path <- "data/inputs/census2021-ts006/census2021-ts006-oa.csv"
oac_path <- "data/inputs/oac21.gpkg"
slides_src <- "slides/index.html"

source("scripts/data_bootstrap.R")
ensure_required_data(
  required_files = c(ts068_path, ts006_path, oac_path),
  env_url_map = c(
    "data/inputs/oac21.gpkg" = "CENSUS_MAPPING_OAC21_GPKG_URL"
  ),
  url_map = c(
    "data/inputs/oac21.gpkg" = "https://www.dropbox.com/scl/fi/dwfa8wo67137985mkti9s/oac21.gpkg?rlkey=7i23zrqgno07wxr2co3a7ctr5&dl=0"
  )
)

students <- read_csv(ts068_path, show_col_types = FALSE) |>
  transmute(
    oa_code = `geography code`,
    total = `Schoolchild or full-time student indicator: Total: All usual residents aged 5 years and over`,
    student = `Schoolchild or full-time student indicator: Student`,
    non_student = `Schoolchild or full-time student indicator: Not a student`
  ) |>
  mutate(student_share = student / total)

density <- read_csv(ts006_path, show_col_types = FALSE) |>
  transmute(
    oa_code = `geography code`,
    population_density = `Population Density: Persons per square kilometre; measures: Value`
  )

student_density <- students |>
  inner_join(density, by = "oa_code")

lad_choices <- st_read(
  oac_path,
  query = "SELECT DISTINCT LAD25Name AS lad_name FROM oac21 WHERE GeographyC LIKE 'E%' OR GeographyC LIKE 'W%' ORDER BY LAD25Name",
  quiet = TRUE
) |>
  dplyr::pull(lad_name)

read_lad_oac <- function(lad) {
  lad_escaped <- gsub("'", "''", lad)
  q <- sprintf(
    "SELECT GeographyC AS oa_code, LAD25Code AS lad_code, LAD25Name AS lad_name, Supergroup AS supergroup, \"Group\" AS group_name, Subgroup AS subgroup, geom
     FROM oac21
     WHERE LAD25Name = '%s' AND (GeographyC LIKE 'E%%' OR GeographyC LIKE 'W%%')",
    lad_escaped
  )
  st_read(oac_path, query = q, quiet = TRUE)
}

default_lad <- if ("Liverpool" %in% lad_choices) "Liverpool" else lad_choices[1]

metric_label <- c(
  student_share = "Student share",
  student = "Students",
  population_density = "Population density (persons per km2)"
)

metric_palette <- function(metric, values) {
  values <- values[is.finite(values)]
  if (!length(values)) {
    return(colorNumeric("Greys", domain = c(0, 1)))
  }

  if (metric == "student_share") {
    bins <- unique(quantile(values, probs = seq(0, 1, by = 0.1), na.rm = TRUE))
    return(colorBin(
      palette = c("#440154", "#482878", "#3e4a89", "#31688e", "#26828e", "#1f9e89", "#35b779", "#6dcd59", "#b4de2c", "#fde725"),
      bins = bins,
      na.color = "#d9d9d9"
    ))
  }

  if (metric == "student") {
    bins <- unique(quantile(values, probs = seq(0, 1, by = 0.1), na.rm = TRUE))
    return(colorBin(
      palette = c("#0d0887", "#46039f", "#7201a8", "#9c179e", "#bd3786", "#d8576b", "#ed7953", "#fb9f3a", "#fdca26", "#f0f921"),
      bins = bins,
      na.color = "#d9d9d9"
    ))
  }

  if (metric == "population_density") {
    bins <- unique(quantile(values, probs = seq(0, 1, by = 0.1), na.rm = TRUE))
    return(colorBin(
      palette = c("#440154", "#482878", "#3e4a89", "#31688e", "#26828e", "#1f9e89", "#35b779", "#6dcd59", "#b4de2c", "#fde725"),
      bins = bins,
      na.color = "#d9d9d9"
    ))
  }

  bins <- unique(quantile(values, probs = c(0, 0.25, 0.5, 0.75, 0.9, 1), na.rm = TRUE))
  colorBin(
    palette = c("#f7f7f7", "#d9d9d9", "#bdbdbd", "#737373", "#252525"),
    bins = bins,
    na.color = "#d9d9d9"
  )
}

ui <- fluidPage(
  tags$head(
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Next:wght@400;700&display=swap"
    ),
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(HTML(
      "window.addEventListener('message', function(event) {
         if (event.data == null) return;
         if (typeof event.data === 'number') {
           if (window.Shiny) {
             window.Shiny.setInputValue('slide_indexh', event.data, {priority: 'event'});
           }
           return;
         }
         if (!event.data || event.data.type !== 'reveal-slide') return;
         if (window.Shiny) {
           window.Shiny.setInputValue('slide_indexh', event.data.indexh, {priority: 'event'});
         }
       });"
    ))
  ),
  div(
    class = "wrapper",
    tags$header(
      tags$iframe(
        class = "slides-frame",
        src = slides_src,
        frameborder = "0",
        width = "100%",
        height = "100%"
      )
    ),
    tags$section(
      leafletOutput("map", width = "100%", height = "100%"),
      uiOutput("map_controls_ui"),
      tags$footer(
        tags$p(
          HTML(
            "Licensed under <a rel='license' href='http://creativecommons.org/licenses/by-nc-sa/4.0/'>Creative Commons 4.0</a> [<a href='https://github.com/darribas/explore_liv_students'>Original format source</a>]"
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  map_mode <- reactiveVal("student")

  selected_lad <- reactive({
    if (is.null(input$lad) || !(input$lad %in% lad_choices)) default_lad else input$lad
  })

  selected_metric <- reactive({
    if (is.null(input$metric) || !(input$metric %in% names(metric_label))) "student_share" else input$metric
  })

  selected_min_density <- reactive({
    if (is.null(input$min_density)) 0 else input$min_density
  })

  observeEvent(input$slide_indexh, {
    idx <- input$slide_indexh
    new_mode <- if (!is.null(idx) && idx >= 3 && idx <= 7) {
      "oac"
    } else {
      "student"
    }
    if (!identical(new_mode, map_mode())) {
      map_mode(new_mode)
    }
  })

  students_data <- reactive({
    min_density <- selected_min_density()
    oac_data() |>
      filter(population_density >= min_density)
  })

  oac_data <- reactive({
    lad <- selected_lad()
    geo <- read_lad_oac(lad)
    attrs <- student_density |>
      filter(oa_code %in% geo$oa_code)

    geo |>
      inner_join(attrs, by = "oa_code") |>
      st_transform(4326)
  })

  output$map_controls_ui <- renderUI({
    lad <- selected_lad()
    metric <- selected_metric()
    min_density <- selected_min_density()

    if (identical(map_mode(), "oac")) {
      div(
        class = "map-controls",
        h3("OAC view"),
        selectInput("lad", "Local authority", choices = lad_choices, selected = lad),
        p(
          class = "oac-note",
          "The map now shows OAC supergroups from oac21.gpkg. Advance slides to return to student metrics."
        ),
        div(class = "stats-box", htmlOutput("summary_text"))
      )
    } else {
      div(
        class = "map-controls",
        h3("Explore the data"),
        selectInput("lad", "Local authority", choices = lad_choices, selected = lad),
        radioButtons(
          "metric",
          "Metric",
          choices = c(
            "Student share" = "student_share",
            "Number of students" = "student",
            "Population density (persons per km2)" = "population_density"
          ),
          selected = metric
        ),
        sliderInput(
          "min_density",
          "Population density (persons per km2)",
          min = 0,
          max = 30000,
          value = min_density,
          step = 250
        ),
        div(class = "stats-box", htmlOutput("summary_text"))
      )
    }
  })

  output$summary_text <- renderUI({
    if (identical(map_mode(), "oac")) {
      dat <- oac_data()
      req(nrow(dat) > 0)

      sg_counts <- dat |>
        st_drop_geometry() |>
        count(supergroup, sort = TRUE)

      top_sg <- sg_counts$supergroup[1]
      top_n <- sg_counts$n[1]

        tagList(
        tags$strong(selected_lad()),
        tags$br(),
        sprintf("%s output areas in view", comma(nrow(dat))),
        tags$br(),
        sprintf("Distinct OAC supergroups: %s", n_distinct(dat$supergroup)),
        tags$br(),
        sprintf("Largest supergroup: %s (%s OAs)", top_sg, comma(top_n))
      )
    } else {
      dat <- students_data()
      req(nrow(dat) > 0)

      avg_share <- percent(mean(dat$student_share, na.rm = TRUE), accuracy = 0.1)
      top_share <- percent(max(dat$student_share, na.rm = TRUE), accuracy = 0.1)

      tagList(
        tags$strong(selected_lad()),
        tags$br(),
        sprintf("%s output areas in view", comma(nrow(dat))),
        tags$br(),
        sprintf("Average student share: %s", avg_share),
        tags$br(),
        sprintf("Highest student share OA: %s", top_share)
      )
    }
  })

  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(zoomControl = TRUE, minZoom = 8, maxZoom = 15)) |>
      addProviderTiles(providers$CartoDB.DarkMatterNoLabels) |>
      addProviderTiles(providers$CartoDB.DarkMatterOnlyLabels)
  })

  observe({
    if (identical(map_mode(), "oac")) {
      dat <- oac_data()
      req(nrow(dat) > 0)

      pal <- colorFactor(
        palette = c("#56B4E9", "#E69F00", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999"),
        domain = sort(unique(dat$supergroup)),
        na.color = "#d9d9d9"
      )

      labels <- lapply(
        sprintf(
          "<strong>%s</strong><br/>OA: %s<br/>OAC supergroup: %s<br/>Group: %s<br/>Subgroup: %s",
          dat$lad_name,
          dat$oa_code,
          dat$supergroup,
          dat$group_name,
          dat$subgroup
        ),
        HTML
      )

      bbox <- st_bbox(dat)

      leafletProxy("map", data = dat) |>
        clearShapes() |>
        clearControls() |>
        addPolygons(
          fillColor = ~pal(supergroup),
          fillOpacity = 0.86,
          color = "#f5f5f5",
          weight = 0.18,
          smoothFactor = 0.2,
          label = labels,
          labelOptions = labelOptions(direction = "auto", textsize = "12px"),
          highlight = highlightOptions(weight = 1.1, color = "#ffffff", bringToFront = TRUE)
        ) |>
        addLegend(
          position = "bottomright",
          pal = pal,
          values = dat$supergroup,
          title = "OAC supergroup",
          opacity = 0.95
        ) |>
        fitBounds(bbox[["xmin"]], bbox[["ymin"]], bbox[["xmax"]], bbox[["ymax"]])
    } else {
      dat <- students_data()
      req(nrow(dat) > 0)

      metric <- selected_metric()
      dat <- dat |>
        mutate(metric_value = .data[[metric]])

      pal <- metric_palette(metric, dat$metric_value)

      pretty_metric <- metric_label[[metric]]
      metric_display <- if (metric == "student_share") {
        percent(dat$metric_value, accuracy = 0.1)
      } else {
        comma(dat$metric_value)
      }

      labels <- lapply(
        sprintf(
          "<strong>%s</strong><br/>OA: %s<br/>%s: %s<br/>Students: %s<br/>Population density: %s persons/km2",
          dat$lad_name,
          dat$oa_code,
          pretty_metric,
          metric_display,
          comma(dat$student),
          comma(round(dat$population_density, 1))
        ),
        HTML
      )

      bbox <- st_bbox(dat)

      leafletProxy("map", data = dat) |>
        clearShapes() |>
        clearControls() |>
        addPolygons(
          fillColor = ~pal(metric_value),
          fillOpacity = 0.86,
          color = "#f5f5f5",
          weight = 0.18,
          smoothFactor = 0.2,
          label = labels,
          labelOptions = labelOptions(direction = "auto", textsize = "12px"),
          highlight = highlightOptions(weight = 1.1, color = "#ffffff", bringToFront = TRUE)
        ) |>
        addLegend(
          position = "bottomright",
          pal = pal,
          values = dat$metric_value,
          title = pretty_metric,
          opacity = 0.95
        ) |>
        fitBounds(bbox[["xmin"]], bbox[["ymin"]], bbox[["xmax"]], bbox[["ymax"]])
    }
  })
}

shinyApp(ui, server)
