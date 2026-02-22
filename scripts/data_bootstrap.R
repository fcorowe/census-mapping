normalize_download_url <- function(src) {
  # Dropbox shared links are often published with dl=0 (preview mode).
  # Convert to dl=1 so download.file gets the file payload directly.
  if (grepl("dropbox\\.com", src, ignore.case = TRUE)) {
    if (grepl("dl=0", src, fixed = TRUE)) {
      src <- sub("dl=0", "dl=1", src, fixed = TRUE)
    } else if (!grepl("dl=", src, fixed = TRUE)) {
      sep <- if (grepl("\\?", src)) "&" else "?"
      src <- paste0(src, sep, "dl=1")
    }
  }
  src
}

ensure_required_data <- function(required_files, env_url_map = character(), url_map = character()) {
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
      src <- unname(url_map[[f]])
    }
    if (!nzchar(src)) {
      next
    }
    src <- normalize_download_url(src)

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
