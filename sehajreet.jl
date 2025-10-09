 
using Statistics
using PlotlyJS
using CSV
using DataFrames
using HypothesisTests

# Load the dataset from the repository
df = CSV.read("Gender_Classification_Data.csv", DataFrame)

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
end                                                                                                                                     # 5) Visualizations (PlotlyJS)
##############################################################

# (A) Scatter: Height vs Weight by gender

if !isempty(male_df) && !isempty(female_df)
    male_df   = df[df.gender .== "male", :]
female_df = df[df.gender .== "female", :]

    male_trace = scatter(x=male_df.weight, y=male_df.height,
        mode="markers", marker=attr(color="steelblue", size=7, opacity=0.6), name="Male")
    female_trace = scatter(x=female_df.weight, y=female_df.height,
        mode="markers", marker=attr(color="lightcoral", size=7, opacity=0.6), name="Female")
    display(plot([male_trace, female_trace],
        Layout(title="Height vs Weight", xaxis=attr(title="Weight (kg)"), yaxis=attr(title="Height (cm)"))))
end

# (B) Line: Average Weight by Age (unique ages)
if :age in names(df) && :weight in names(df)
    trend = combine(groupby(dropmissing(df, [:age, :weight]), :age), :weight => mean => :Mean_Weight)
    trend = sort(trend, :age)
    trace_w = scatter(x=trend.age, y=trend.Mean_Weight,
        mode="lines+markers", line=attr(color="steelblue", width=3),
        marker=attr(size=6), name="Avg Weight")
    display(plot([trace_w], Layout(title="Average Weight by Age",
        xaxis=attr(title="Age"), yaxis=attr(title="Average Weight (kg)"))))
end

# (C) Box Plot: Height by Gender
if !isempty(male_df) && !isempty(female_df)
    male_box   = PlotlyJS.box(y=male_df.height, name="Male Height",   marker=attr(color="steelblue"))
    female_box = PlotlyJS.box(y=female_df.height, name="Female Height", marker=attr(color="lightcoral"))
    display(plot([male_box, female_box], Layout(title="Height Distribution by Gender")))
end

# (D) BMI Distribution (% by category)
##############################################################
# Create BMI_Category column from BMI_Index 
if !(:BMI_Category in names(df))
    function bmi_category(idx)
        idx == 1 ? "Underweight" :
        idx == 2 ? "Normal" :
        idx == 3 ? "Overweight" :
        idx == 4 ? "Obese I"   : "Obese II+"
    end

    df.BMI_Category = map(x -> ismissing(x) ? missing : bmi_category(x), df.BMI_Index)
end

counts_bmi = combine(groupby(dropmissing(df, :BMI_Category), :BMI_Category), nrow => :Count)
total_bmi = max(sum(counts_bmi.Count), 1)
counts_bmi.Percent = round.(counts_bmi.Count ./ total_bmi .* 100, digits=2)

cats = ["Underweight","Normal","Overweight","Obese I","Obese II+"]
color_map = Dict("Underweight"=>"steelblue", "Normal"=>"mediumseagreen",
                 "Overweight"=>"khaki", "Obese I"=>"sandybrown", "Obese II+"=>"indianred")

trace_hist = bar(
    x = counts_bmi.BMI_Category,
    y = counts_bmi.Percent,
    marker = attr(color=[color_map[c] for c in counts_bmi.BMI_Category]),
    text = string.(counts_bmi.Percent, "%"),
    textposition = "outside",
    name = "BMI %"
)
display(plot([trace_hist], Layout(
    title = "BMI Distribution",
    xaxis = attr(categoryorder="array", categoryarray=cats),
    yaxis = attr(title="Percent (%)"),
    showlegend=false
)))

##############################################################
# 6) CDF of BMI (+ 10th/90th + single “you are here” point)
##############################################################

# Prepare sorted BMI values and CDF
bmi_values = sort(collect(skipmissing(df.BMI)))
n = length(bmi_values)
if n == 0
    error("No valid BMI values to build a CDF.")
end
cumulative_prob = collect(1:n) ./ n .* 100.0

# Percentiles
p10 = quantile(bmi_values, 0.10)
p90 = quantile(bmi_values, 0.90)

# Helpers for the interactive point
calc_bmi(weight, height_cm) = round(weight / ((height_cm/100)^2), digits=2)

function bmi_percentile(bmi_value, bmi_values_vec)
    # percentile based on empirical CDF
    return round(sum(bmi_values_vec .<= bmi_value) / length(bmi_values_vec) * 100, digits=2)
end

include("src/interpret_percentile.jl")
# Example student input (change live in REPL during class)
age    = 21
weight = 68.0   # kg
height = 160.0   # cm

student_bmi = calc_bmi(weight, height)
student_idx = bmi_index(student_bmi)       
student_cat = bmi_category(student_idx)    

student_pct = bmi_percentile(student_bmi, bmi_values)
interp      = interpret_percentile(student_pct)

println("\n🎓 Student age: $age")
println("✅ BMI: $student_bmi ($student_cat)")
println("✅ Percentile in dataset: $student_pct%")
println("📌 Interpretation: $interp")

# CDF trace
trace_curve = scatter(
    x = bmi_values,
    y = cumulative_prob,
    mode = "lines",
    line = attr(color="purple", width=3),
    name = "BMI CDF"
)

# 10th & 90th percentile markers
trace_p10 = scatter(x=[p10, p10], y=[0.0, 100.0], mode="lines", line=attr(color="red",   dash="dash"),   name="10th %")
trace_p90 = scatter(x=[p90, p90], y=[0.0, 100.0], mode="lines", line=attr(color="green", dash="dash"),   name="90th %")

# Student point (y should be percentile, not CDF value at x strictly—both okay since we computed it)
trace_point = scatter(
    x = [student_bmi],
    y = [student_pct],
    mode = "markers+text",
    marker = attr(color="red", size=12),
    text = ["You are here! (BMI=$(student_bmi), $(student_cat))"],
    textposition = "top center",
    name = "Student"
)

layout_cdf = Layout(
    title = "BMI CDF with 10th/90th Percentiles + Student Position",
    xaxis = attr(title="BMI"),
    yaxis = attr(title="Cumulative Probability (%)"),
    legend = attr(x=0.02, y=0.98)
)

display(plot([trace_curve, trace_p10, trace_p90, trace_point], layout_cdf))
##############################################################"                                                   
                                              
