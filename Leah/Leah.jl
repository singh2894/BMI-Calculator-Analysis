import Pkg
for pkg in ["CSV", "DataFrames"]
    if !haskey(Pkg.installed(), pkg)
        Pkg.add(pkg)
    end
end
using CSV
using DataFrames
println(pwd())
using CSV
using DataFrames


file_path = "/Users/hezhushan/Downloads/Gender_Classification_Data.csv"

data = CSV.read(file_path, DataFrame)
import Pkg
Pkg.add("Plots")
Pkg.add("StatsPlots")
Pkg.add.("PlotlyJS")
Pkg.add("Statistics")
using CSV
using DataFrames
using Plots
using StatsPlots
using Statistics
using PlotlyJS


#--- Section ---
using CSV
using DataFrames

# Load the dataset from the repository
df = df = CSV.read("/Users/hezhushan/Downloads/Gender_Classification_Data.csv", DataFrame)

# --- Label gender Sort female and male Compare M vs F at every index leveln ---
using CSV
using DataFrames

# Check unique gender values
println("Unique genders: ", unique(df.gender))

# Count samples by gender
println("Count by gender:")
println(combine(groupby(df, :gender), nrow => :Count))

# Count by gender and BMI_Index
gender_bmi_stats = combine(groupby(df, [:gender, :BMI_Index]), nrow => :Count)
println("Count by gender and BMI_Index:")
println(gender_bmi_stats)

# Create a pivot table (compare male vs female at each BMI_Index)
pivot_table = unstack(gender_bmi_stats, :gender, :Count)
rename!(pivot_table, Dict("female" => "Female_Count", "male" => "Male_Count"))
println("Pivot table (Male vs Female at each BMI_Index):")
println(pivot_table)

# Add proportions for better comparison
pivot_table.Female_Proportion = pivot_table.Female_Count ./ (pivot_table.Female_Count .+ pivot_table.Male_Count)
pivot_table.Male_Proportion = pivot_table.Male_Count ./ (pivot_table.Female_Count .+ pivot_table.Male_Count)

println("Pivot table with proportions:")
println(pivot_table)

# Print side-by-side comparison
for row in eachrow(pivot_table)
    println("BMI_Index $(row.BMI_Index): Female $(row.Female_Count) vs Male $(row.Male_Count)")
end


