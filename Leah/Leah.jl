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

# Explore dataset
# Display the first five rows
println(first(df, 5))

# Display the column names
println("column names : $(names(df))")

# Display the number of rows and columns
println("number of rows : $(nrow(df))")
println("number of columns : $(ncol(df))")

# Describe the dataset with summary statistics
println(describe(df))

# Check for missing values of all columns
println("Missing values per column: ",
    map(c -> (c => count(ismissing, df[!, c])), names(df)))

# Calculate BMI and add it as a new column
# BMI = weight (kg) / height (m)^2
# Convert height from cm to m before calculating BMI
# Added safety: if height or weight is missing, or height <= 0, set BMI to missing
df.BMI = ifelse.(ismissing.(df.height) .| ismissing.(df.weight) .| (df.height .<= 0) .| (df.weight .<= 0),
                 missing,
                 df.weight ./ (df.height ./ 100) .^ 2)

# Display the first five rows with the new BMI column
println(first(df, 5))  

# Classify BMI values into categories
function bmi_index(bmi)
    if bmi < 18.5
        return 1  # Underweight
    elseif bmi < 25
        return 2  # Normal
    elseif bmi < 30
        return 3  # Overweight
    elseif bmi < 35
        return 4  # Obese Class I
    else
        return 5  # Obese Class II+
    end
end

# Apply BMI classification
# Added safety: if BMI is missing, keep it missing
df.BMI_Index = map(x -> ismissing(x) ? missing : bmi_index(x), df.BMI)

# Display the first five rows with the new BMI_Index column
println(first(df, 5))


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


