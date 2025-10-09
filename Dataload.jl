import Pkg; Pkg.add("HypothesisTests")
using Pkg
Pkg.add("CSV")
Pkg.resolve()
using CSV
using DataFrames
using HypothesisTests
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
heightMissing=count(ismissing,df.height)
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

# DIVISION
# Create Age Intervals
function age_to_interval(a)
    if ismissing(a)
        return missing          #Keep missing values as missing
    elseif a < 25
        return "18–24"          #Young adults
    elseif a < 35
        return "25–34"          #Early adulthood
    elseif a < 45
        return "35–44"          #Mid adulthood
    elseif a < 55
        return "45–54"          #Mature adulthood
    else
        return "55–69"          #Late adulthood
    end
end

# Apply the function to the "age" column and create a new column "age_interval"
df.age_interval = map(age_to_interval, df.age)

# Show the first five rows to confirm
println("\nPreview with age_interval added:")
println(first(df, 5))

# DESCRIPTION
#Pivot Table (Percentages Only)
# Count people in each BMI_Index × age_interval combination
counts = combine(groupby(df, [:BMI_Index, :age_interval]), nrow => :count)

# Add percentages within each BMI_Index (rows will sum to ~100%)
transform!(groupby(counts, :BMI_Index),
           :count => (x -> round.(100 .* x ./ sum(x); digits=1)) => :pct_within_bmi)

# Reshape into pivot: rows = BMI_Index, columns = age intervals
pivot_pct = unstack(counts, :BMI_Index, :age_interval, :pct_within_bmi)

# Sort rows (BMI_Index) and columns (age_interval) for consistency
sort!(pivot_pct, :BMI_Index)
select!(pivot_pct, ["BMI_Index", "18–24", "25–34", "35–44", "45–54", "55–69"])

println("\nPivot table (percentages within BMI_Index):")
show(pivot_pct, allrows=true, allcols=true)

# ANALYSIS
# Chi-square Test of Independence
# Build contingency table (counts, not percentages)
cont_table = combine(groupby(df, [:age_interval, :BMI_Index]), nrow => :count)

# Pivot into wide format (rows = age_interval, cols = BMI_Index)
pivot_chi = unstack(cont_table, :age_interval, :BMI_Index, :count)

# Replace missing values with 0 (if any groups are empty)
pivot_chi .= coalesce.(pivot_chi, 0)

# Sort rows by age interval for consistent ordering
sort!(pivot_chi, :age_interval)

# Convert to pure Int matrix for chi-square test
mat = Matrix{Int}(select(pivot_chi, Not(:age_interval)))

# Run chi-square test
test_result = ChisqTest(mat)
p_val = pvalue(test_result)

println("\nChi-square test summary:")
println("p-value = $(round(p_val, digits=4))")

if p_val < 0.05
    println("Interpretation: BMI distribution differs significantly across age intervals.")
else
    println("Interpretation: No strong evidence of association between BMI and age intervals.")
end

# Save the updated DataFrame to a new CSV file adding some thing tom see changes
CSV.write("updated_Gender_Classification_Data.csv", df) 

#Gender Analysis with BMI_Index
import Pkg
for pkg in ["CSV", "DataFrames", "HypothesisTests"]
    if !haskey(Pkg.installed(), pkg)
        Pkg.add(pkg)
    end
end

# Load the dataset (use the updated file with BMI_Index column)
file_path = "/Users/hezhushan/Desktop/BMI-Calculator-Analysis/updated_Gender_Classification_Data.csv"
df = CSV.read(file_path, DataFrame)

# --- Label gender Sort female and male Compare M vs F at every index level ---

# Check unique gender values
println("Unique genders: ", unique(df.gender))

# Count samples by gender
println("\nCount by gender:")
println(combine(groupby(df, :gender), nrow => :Count))

# Count by gender and BMI_Index
gender_bmi_stats = combine(groupby(df, [:gender, :BMI_Index]), nrow => :Count)
println("\nCount by gender and BMI_Index:")
println(gender_bmi_stats)

# Create a pivot table (compare male vs female at each BMI_Index)
pivot_table = unstack(gender_bmi_stats, :gender, :Count)
rename!(pivot_table, Dict("female" => "Female_Count", "male" => "Male_Count"))
println("\nPivot table (Male vs Female at each BMI_Index):")
println(pivot_table)

# Add proportions for better comparison
pivot_table.Female_Proportion = pivot_table.Female_Count ./ (pivot_table.Female_Count .+ pivot_table.Male_Count)
pivot_table.Male_Proportion = pivot_table.Male_Count ./ (pivot_table.Female_Count .+ pivot_table.Male_Count)

println("\nPivot table with proportions:")
println(pivot_table)

# Print side-by-side comparison
println("\nSide-by-side comparison:")
for row in eachrow(pivot_table)
    println("BMI_Index $(row.BMI_Index): Female $(row.Female_Count) vs Male $(row.Male_Count)")
end

# --- Chi-square Test of Independence (Gender vs BMI_Index) ---
println("\n" * "="^60)
println("CHI-SQUARE TEST: Gender vs BMI_Index")
println("="^60)

# Build contingency table (counts)
cont_table = combine(groupby(df, [:gender, :BMI_Index]), nrow => :count)

# Pivot into wide format (rows = gender, cols = BMI_Index)
pivot_chi = unstack(cont_table, :gender, :BMI_Index, :count)

# Replace missing values with 0 (if any groups are empty)
for col in names(pivot_chi)
    if col != :gender
        pivot_chi[!, col] = coalesce.(pivot_chi[!, col], 0)
    end
end

# Sort rows by gender for consistent ordering
sort!(pivot_chi, :gender)

println("\nContingency table for Chi-square test:")
println(pivot_chi)

# Convert to pure Int matrix for chi-square test
mat = Matrix{Int}(select(pivot_chi, Not(:gender)))

println("\nMatrix for Chi-square test:")
println(mat)

# Run chi-square test
test_result = ChisqTest(mat)
p_val = pvalue(test_result)
chi_stat = test_result.stat
dof = test_result.df

println("\n" * "-"^60)
println("Chi-square test results:")
println("-"^60)
println("Chi-square statistic: $(round(chi_stat, digits=4))")
println("Degrees of freedom: $(dof)")
println("p-value: $(round(p_val, digits=6))")
println("-"^60)

if p_val < 0.05
    println("\n✓ SIGNIFICANT ASSOCIATION")
    println("Interpretation: BMI distribution differs significantly between genders.")
    println("Gender and BMI_Index are statistically dependent (p < 0.05).")
else
    println("\n✗ NO SIGNIFICANT ASSOCIATION")
    println("Interpretation: No strong evidence of association between gender and BMI.")
    println("Gender and BMI_Index appear to be independent (p ≥ 0.05).")
end

# Save the results to a CSV file (optional)
CSV.write("gender_bmi_pivot_table.csv", pivot_table)
println("\n✓ Results saved to 'gender_bmi_pivot_table.csv'")
