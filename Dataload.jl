using Pkg
Pkg.add("CSV")
Pkg.resolve()
using CSV
using DataFrames
include("src-bmi-index.jl")

# Replace "filename.csv" with the actual CSV file name in your repository
df = CSV.read("Gender_Classification_Data.csv", DataFrame)

# Read CSV file
df = CSV.read("data.csv", DataFrame)

first(df,10)

#Describe the dataset
describe(df)

# Check for missing values
ageMissing=count(ismissing, df.age)
heightMissing=count(ismissing,df.gender)
println("Number of missing values in age column: $ageMissing")  
println("Number of missing values in height column: $heightMissing")

# Calculate BMI and add it as a new column 

# Convert height from cm to m before calculating BMI
df.BMI = df.weight ./ (df.height ./ 100) .^ 2

# Display the first few rows with the new BMI column
println(first(df, 5))   



# function bmi_index(bmi)
#     if bmi < 18.5
#         return 1  # Underweight
#     elseif bmi < 25
#         return 2  # Normal
#     elseif bmi < 30
#         return 3  # Overweight
#     elseif bmi < 35
#         return 4  # Obese Class I
#     else
#         return 5  # Obese Class II+
#     end
# end

df.BMI_Index = map(bmi_index, df.BMI)
println(first(df, 5))

# Keep only valid rows
clean_df = filter(is_valid, eachrow(df)) |> DataFrame

# Save cleaned data (adjust path as needed)
CSV.write("C:/Users/YourName/Documents/data_cleaned.csv", clean_df)


