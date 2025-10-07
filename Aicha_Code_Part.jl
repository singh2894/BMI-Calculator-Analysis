# Using the already imported packages
using CSV
using DataFrames
using HypothesisTests

# Load the dataset from the repository
df = df = CSV.read("C:/Users/HP/Desktop/BMI-Calculator-Analysis/Gender_Classification_Data.csv", DataFrame)

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

# Save the updated DataFrame (with BMI and BMI_Index) to a new CSV file
CSV.write(joinpath(@__DIR__, "updated_Gender_Classification_Data.csv"), df)
