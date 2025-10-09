#Gender Analysis with BMI_Index
import Pkg
for pkg in ["CSV", "DataFrames", "HypothesisTests"]
    if !haskey(Pkg.installed(), pkg)
        Pkg.add(pkg)
    end
end

using CSV
using DataFrames
using HypothesisTests

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
