using Pkg
Pkg.add("CSV")
Pkg.resolve()
using CSV
using DataFrames
include("src-bmi-index.jl")

# Replace "filename.csv" with the actual CSV file name in your repository
df = CSV.read("Gender_Classification_Data.csv", DataFrame)

# Display the first few rows
println(first(df, 5))

# Display the column names
println("column names : $(names(df))")

# Display the number of rows and columns
println("number of rows : $(nrow(df))")
println("number of columns : $(ncol(df))")

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

# Save the updated DataFrame to a new CSV file adding some thing tom see changes
CSV.write("updated_Gender_Classification_Data.csv", df) 