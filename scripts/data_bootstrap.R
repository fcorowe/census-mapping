ensure_required_data <- function(required_files, env_url_map = character()) {
  missing_files <- required_files[!file.exists(required_files)]
  if (!length(missing_files)) {
    return(invisible(TRUE))
  }

  for (f in missing_files) {
    env_name <- unname(env_url_map[[f]])
    if (is.null(env_name) || !nzchar(env_name)) {
      next
    }

    src <- Sys.getenv(env_name, unset = "")
    if (!nzchar(src)) {
      next
    }

    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    message("Downloading missing data file: ", f)

    ok <- tryCatch({
      utils::download.file(src, destfile = f, mode = "wb", quiet = TRUE)
      TRUE
    }, error = function(e) {
      message("Failed downloading ", f, ": ", conditionMessage(e))
      FALSE
    })

    if (!ok || !file.exists(f)) {
      stop("Missing required data file and download failed: ", f, call. = FALSE)
    }
  }

  still_missing <- required_files[!file.exists(required_files)]
  if (length(still_missing)) {
    hints <- vapply(
      still_missing,
      function(f) {
        env_name <- unname(env_url_map[[f]])
        if (is.null(env_name) || !nzchar(env_name)) {
          paste0("- ", f, " (add file manually)")
        } else {
          paste0("- ", f, " (set env var ", env_name, " with a download URL)")
        }
      },
      character(1)
    )

    stop(
      paste(
        "Required data files are missing:",
        paste(hints, collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}
