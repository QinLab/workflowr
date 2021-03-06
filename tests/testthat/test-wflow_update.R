context("wflow_update")

# Note: Had to convert file paths to lower case b/c win-builder returns "d:" for
# the observed and "D:" for the expected files even though they both pass
# through workflowr:::absolute. Hard to debug since this doesn't happen locally
# or on AppVeyor.

# Test wflow_update ------------------------------------------------------------

test_that("wflow_update can update to workflowr 1.0", {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  tmp_dir <- workflowr:::absolute(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  file.copy("files/test-wflow_update/pre/.", tmp_dir, recursive = TRUE)
  dir.create(file.path(tmp_dir, "docs"))
  git2r::init(tmp_dir)
  r <- git2r::repository(tmp_dir)
  git2r::config(r, user.name = "Test Name", user.email = "test@email")
  git2r::add(r, ".")
  git2r::commit(r, "Initial commit.")

  # Dry run
  expected <- file.path(tmp_dir, c("_workflowr.yml", "analysis/_site.yml",
                                   "analysis/chunks.R",
                                   "analysis/include/footer.html",
                                   "analysis/index.Rmd",
                                   "analysis/workflowr-template.Rmd"))
  # For some reason, only the r-hub Ubuntu 16.04 sorts the files by ignoring the
  # underscores. Thus have to explicitly sort them to match the results from
  # wflow_update().
  expected <- sort(expected)
  files_dry <- wflow_update(project = tmp_dir)
  expect_identical(tolower(workflowr:::absolute(files_dry)),
                   tolower(expected))

  # Update the files
  files_updated <- wflow_update(dry_run = FALSE, project = tmp_dir)
  expect_identical(tolower(workflowr:::absolute(files_updated)),
                   tolower(expected))

  # Confirm files are updated correctly
  lines_expected <- Map(readLines, list.files("files/test-wflow_update/post",
                                              recursive = TRUE, full.names = TRUE))
  names(lines_expected) <- NULL
  lines_observed <- Map(readLines, list.files(tmp_dir, recursive = TRUE,
                                              full.names = TRUE))
  names(lines_observed) <- NULL
  expect_identical(lines_observed, lines_expected)

  # Confirm that all files can be committed easily
  git_commit <- wflow_git_commit(file.path(tmp_dir, "_workflowr.yml"),
                                 "Update to 1.0", all = TRUE, project = tmp_dir)
  expect_identical("Update to 1.0", git_commit$message)
  expect_identical(tolower(sort(workflowr:::absolute(git_commit$commit_files))),
                   tolower(expected))

  # Confirm that subsequent calls to wflow_update have no effect
  files_dry_post <- wflow_update(project = tmp_dir)
  expect_identical(files_dry_post, character(0))
  files_updated_post <- wflow_update(dry_run = FALSE, project = tmp_dir)
  expect_identical(files_updated_post, character(0))
  s <- git2r::status(r)
  expect_null(unlist(s))

  skip_on_cran()

  # Confirm that wflow_publish can build and commit the Rmd files
  rmd <- Sys.glob(file.path(tmp_dir, "analysis", "*Rmd"))
  html <- workflowr:::to_html(rmd, outdir = file.path(tmp_dir, "docs"))
  publish <- wflow_publish(rmd, "Publish updated files", view = FALSE,
                           project = tmp_dir)
  expect_identical(tolower(workflowr:::absolute(publish$step2$built)),
                   tolower(rmd))
  expect_true(all(tolower(html) %in%
                  tolower(workflowr:::absolute(publish$step3$commit_files))))
})
