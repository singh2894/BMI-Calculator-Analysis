# Load required packages
using Pkg
# Activate the repository environment (Project.toml / Manifest.toml at repo root)
Pkg.activate(@__DIR__)
# Instantiate the environment from the manifest (do not add packages at runtime with Pkg.add)
Pkg.instantiate()
Pkg.precompile()
Pkg.status()
Pkg.add("CSV")
try
    @eval using Gtk
catch
    import Pkg
    Pkg.add("Gtk")
    @eval using Gtk
end
using Gtk, Gtk.ShortNames


using CSV
using DataFrames
using HypothesisTests
# Load required packages for visualizations
using Statistics
using PlotlyJS
using Dates
using Printf


include("src/load_clean_df.jl")
include("src/visualizing.jl")
include("src/helpers.jl")
include("src/calc_bmi.jl")
include("src/userinterface.jl")
include("src/Analysis.jl")

##### Main app logic
function start_app()
    # Load all input files + output directory
    gender_bmi_pivot_table_path, unclean_gender_classification_data_path, output_dir = initialize_paths()


    # Load and clean the dataset
    raw_df = CSV.read(unclean_gender_classification_data_path, DataFrame)
    clean_df = load_clean_df(raw_df)
    
    # Save cleaned data (optional)
    CSV.write(joinpath(output_dir, "clean_dataset.csv"), clean_df)


    # calculte the BMI and add it to the dataframe
    # the result clean_df is updated inside the function.
    updated_clean_df, pivot_table = calculate_bmi(clean_df)

    # Save the updated DataFrame to a new CSV file adding some thing tom see changes
    CSV.write(joinpath(output_dir, "updated_gender_classification_data.csv"), updated_clean_df)
    # Save the results to a CSV file (optional)
    CSV.write(joinpath(output_dir, "gender_bmi_pivot_table.csv"), pivot_table)


    # Here we're going to visualize the data
    show_charts(updated_clean_df)

    # TODO: Fix the error with Gtk on MacOS
    # Show the user interface
    # show_ui()

    # TODO: after fetching the input data from the UI, call the 'analyse()' method to show the given info

end

#### Start the app and path all the paths
start_app()
