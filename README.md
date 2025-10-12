# BMI-Calculator-Analysis

A small Julia project for cleaning, analysing and visualizing BMI / body-composition data.

## Project structure

### Source codes
- `main.jl` — project entry point script. **Always** start the project from here...
- `Project.toml`, `Manifest.toml` — Julia package environment files. Use these to reproduce the environment with the Julia package manager.

- `src/` — Primary source folder (preferred location for canonical code):
    - `load_clean_df.jl` — data loading and cleaning utilities.
    - `calc_bmi.jl` — calculate BMI based on the given cleaned data
	- `visualizing.jl` — plotting helpers and wrappers.
    - `helpers.jl` — general-purpose helper functions used across scripts.


### Data related directories

- `input/` — Raw and example input CSV files used by the analysis scripts.
- `output/` — Auto generated folder for output files (CSV, pivot tables, plot HTML):

### TEMP directory

- `temp/` — Not merged scripts, --> scripts inside this folder should merge into the project and then delete this folders

## How to start

- Option 1: run the `main.jl` using vscode
- Option 2: run the `julia main.jl` using terminal
