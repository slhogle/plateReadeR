# plateReadeR

`plateReadeR` reads text and Excel output files from different microplate readers, converts them to tidy data frames, and runs basic quality control checks. Joining the data to sample metadata is left to the user.

| Function | Instrument | Format |
|----|----|----|
| `read_logphase_txt()` | LogPhase600 | text, one file per plate |
| `read_logphase_xlsx()` | LogPhase600 | Excel, `Raw Data` sheets, one per plate |
| `read_bioscreen()` | Bioscreen C | UTF-16 text, one or two 100-well plates |

All readers return one row per well per time point, with `plate_id` and `well` identifying the well.

## Installation

You can install the development version from GitHub with:

``` r
# install.packages("pak")
pak::pkg_install("slhogle/plateReadeR")
```

## Example

``` r
library(plateReadeR)

f <- system.file("extdata", "logphase600_plate1.txt", package = "plateReadeR")

read_logphase_txt(f) |>
  flag_od_range(saturation = 2) |>
  blank_correct(smooth = TRUE) |>
  flag_no_growth() |>
  plot_plate(plate = "Plate 1", smooth = TRUE)
```

See `vignette("plateReadeR")` for the full workflow, including the Bioscreen reader.
