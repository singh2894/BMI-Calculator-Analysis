using CSV
using DataFrames

df = CSV.read("Gender_Classification_Data.csv", DataFrame)

# Read CSV file
df = CSV.read("data.csv", DataFrame)

first(df,10)

# Round height and weight
df.height = round.(df.height, digits=1)
df.weight = round.(df.weight, digits=1)

# Define validity checks
function is_valid(row)
    valid_age = (row.age isa Integer || row.age == floor(row.age)) &&
                18 <= row.age <= 60
    valid_height = 144.0 <= row.height <= 210.0
    valid_weight = 34.0 <= row.weight <= 120.0
    return valid_age && valid_height && valid_weight
end

# Show invalid rows
invalid_rows = filter(row -> !is_valid(row), eachrow(df))
println("Invalid rows:")
println(DataFrame(invalid_rows))

# Keep only valid rows
clean_df = filter(is_valid, eachrow(df)) |> DataFrame

# Save cleaned data (adjust path as needed)
CSV.write(raw("Gender_Classification_Data.csv", clean_df))

