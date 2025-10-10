import Pkg
for pkg in ["CSV", "DataFrames", "Statistics", "PlotlyJS", "HypothesisTests", "Missings"]
if !haskey(Pkg.installed(), pkg)
Pkg.add(pkg)
end
end

using CSV, DataFrames, Statistics, PlotlyJS, HypothesisTests, Missings

##############################################################
# 1. Load dataset
##############################################################
file_path = ("C:\\Users\\Simran\\OneDrive\\Desktop\\BMI Calculator Analysis\\BMI-Calculator-Analysis\\clean_dataset.csv", DataFrame)
df = CSV.read(file_path, DataFrame)

println("Preview:"); println(first(df, 5))
println("Columns: ", names(df))
println("Rows: ", nrow(df), " | Cols: ", ncol(df))

##############################################################
# 2. Preprocessing
##############################################################
# --- BMI ---
df.BMI = ifelse.(ismissing.(df.height) .| ismissing.(df.weight) .|
(df.height .<= 0) .| (df.weight .<= 0),
missing,
df.weight ./ (df.height ./ 100) .^ 2)

# --- BMI index ---
function bmi_index(bmi)
if bmi < 18.5
return 1
elseif bmi < 25
return 2
elseif bmi < 30
return 3
elseif bmi < 35
return 4
else
return 5
end
end
df.BMI_Index = map(x -> ismissing(x) ? missing : bmi_index(x), df.BMI)

# --- BMI category ---
function bmi_category(idx)
idx == 1 ? "Underweight" :
idx == 2 ? "Normal" :
idx == 3 ? "Overweight" :
idx == 4 ? "Obese I" : "Obese II+"
end
df.BMI_Category = map(x -> ismissing(x) ? missing : bmi_category(x), df.BMI_Index)

# --- Age intervals ---
function age_to_interval(a)
if ismissing(a)
return missing
elseif a < 25
return "18–24 (Young adults)"
elseif a < 35
return "25–34 (Early adulthood)"
elseif a < 45
return "35–44 (Mid adulthood)"
elseif a < 55
return "45–54 (Mature adulthood)"
else
return "55–69 (Late adulthood)"
end
end
df.AgeInterval = map(age_to_interval, df.age)

println("\nAfter preprocessing:"); println(first(df, 5))

##############################################################
# 3. Stats: Pivot & Chi-Square
##############################################################
counts = combine(groupby(df, [:BMI_Index, :AgeInterval]), nrow => :count)
transform!(groupby(counts, :BMI_Index),
:count => (x -> round.(100 .* x ./ max(sum(x),1); digits=1)) => :pct_within_bmi)
pivot_pct = unstack(counts, :BMI_Index, :AgeInterval, :pct_within_bmi)
println("\n% within BMI_Index by AgeInterval:"); println(pivot_pct)

# --- Chi-square test ---
cont_table = combine(groupby(df, [:AgeInterval, :BMI_Index]), nrow => :count)
pivot_chi = unstack(cont_table, :AgeInterval, :BMI_Index, :count)
pivot_chi .= coalesce.(pivot_chi, 0)
mat = Matrix{Int}(select(pivot_chi, Not(:AgeInterval)))
try
test_result = ChisqTest(mat)
println("\nChi-square test:"); println(test_result)
pv = pvalue(test_result)
println(pv < 0.05 ?
"→ Significant association between BMI and AgeInterval." :
"→ No strong evidence of association between BMI and AgeInterval.")
catch e
@warn "Chi-square test failed" error=e
end

##############################################################
# 4. Gender comparison
##############################################################
if :gender in names(df)
df.gender = lowercase.(string.(df.gender))
gender_stats = combine(groupby(df, [:gender, :BMI_Index]), nrow => :Count)
println("\nCounts by gender and BMI_Index:"); println(gender_stats)
end

male_df = df[df.gender .== "male", :]
female_df = df[df.gender .== "female", :]

##############################################################
# 5. Visualizations
##############################################################

# (A) Scatter: Height vs Weight
if !isempty(male_df) && !isempty(female_df)
male_trace = scatter(x=male_df.weight, y=male_df.height,
mode="markers", marker=attr(color="steelblue", size=7, opacity=0.6), name="Male")
female_trace = scatter(x=female_df.weight, y=female_df.height,
mode="markers", marker=attr(color="lightcoral", size=7, opacity=0.6), name="Female")
display(plot([male_trace, female_trace],
Layout(title="Height vs Weight", xaxis=attr(title="Weight (kg)"), yaxis=attr(title="Height (cm)"))))
end

# (B) Line Graph: Average Weight by Age
trend = combine(groupby(df, :age), :weight => mean => :Mean_Weight)
trend = dropmissing(trend, :age)
trend = sort(trend, :age)

trace_w = scatter(x=trend.age, y=trend.Mean_Weight,
mode="lines+markers", line=attr(color="steelblue", width=3),
marker=attr(size=6, color="red"), name="Avg Weight")

display(plot([trace_w], Layout(title="Average Weight by Age",
xaxis=attr(title="Age"), yaxis=attr(title="Average Weight (kg)"))))

# (C) Box Plot: Height by Gender
if !isempty(male_df) && !isempty(female_df)
male_box = PlotlyJS.box(y=male_df.height, name="Male Height", marker_color="steelblue")
female_box = PlotlyJS.box(y=female_df.height, name="Female Height", marker_color="lightcoral")
display(plot([male_box, female_box], Layout(title="Height Distribution by Gender")))
end

# (D) Histogram: BMI Distribution
counts_bmi = combine(groupby(df, :BMI_Category), nrow => :Count)
total = max(sum(counts_bmi.Count), 1)
counts_bmi.Percent = round.(counts_bmi.Count ./ total .* 100, digits=2)

cats = ["Underweight","Normal","Overweight","Obese I","Obese II+"]
color_map = Dict("Underweight"=>"steelblue", "Normal"=>"mediumseagreen",
"Overweight"=>"khaki", "Obese I"=>"sandybrown", "Obese II+"=>"indianred")

trace_hist = bar(x=counts_bmi.BMI_Category, y=counts_bmi.Percent,
marker_color=[color_map[c] for c in counts_bmi.BMI_Category],
text=string.(counts_bmi.Percent, "%"), textposition="outside")

display(plot([trace_hist], Layout(title="BMI Distribution",
xaxis=attr(categoryorder="array", categoryarray=cats),
yaxis=attr(title="Percent (%)"), showlegend=false)))

# (E) CDF

using CSV, DataFrames, Statistics, PlotlyJS

# Load dataset
file_path = ("C:\\Users\\Simran\\OneDrive\\Desktop\\BMI Calculator Analysis\\BMI-Calculator-Analysis\\clean_dataset.csv", DataFrame)
df = CSV.read(file_path, DataFrame)

# Prepare BMI values

# Number of valid BMI entries
n = length(bmi_values)

# Compute cumulative probability (%)
cumulative_prob = collect(1:n) ./ n .* 100

# --- Percentiles ---
p10 = quantile(bmi_values, 0.10)
p90 = quantile(bmi_values, 0.90)

# --- CDF Curve ---
trace_curve = scatter(
x = bmi_values,
y = cumulative_prob,
mode = "lines",
line = attr(color="purple", width=3),
name = "CDF of BMI"
)

# --- Mark 10th percentile ---
trace_p10 = scatter(
x = [p10, p10],
y = [0, 100],
mode = "lines",
line = attr(color="red", dash="dash"),
name = "10th Percentile"
)

# --- Mark 90th percentile ---
trace_p90 = scatter(
x = [p90, p90],
y = [0, 100],
mode = "lines",
line = attr(color="green", dash="dash"),
name = "90th Percentile"
)

# --- Layout ---
layout = Layout(
title = "BMI CDF with 10th and 90th Percentiles",
xaxis = attr(title="BMI"),
yaxis = attr(title="Cumulative Probability (%)"),
legend = attr(x=0.05, y=0.95)
)

# --- Display ---
display(plot([trace_curve, trace_p10, trace_p90], layout))




##############################################################
# 6. Interactive BMI Calculator
##############################################################
using CSV, DataFrames, Statistics, PlotlyJS

# --- Load dataset ---
file_path = ("C:\\Users\\Simran\\OneDrive\\Desktop\\BMI Calculator Analysis\\BMI-Calculator-Analysis\\clean_dataset.csv", DataFrame)
df = CSV.read(file_path, DataFrame)

#--- Prepare BMI values ---
n = length(bmi_values)
cumulative_prob = collect(1:n) ./ n .* 100

# --- Functions ---
function calc_bmi(weight, height_cm)
height_m = height_cm / 100
return round(weight / (height_m^2), digits=2)
end

function bmi_index(bmi)
if bmi < 18.5
return 1
elseif bmi < 25
return 2
elseif bmi < 30
return 3
elseif bmi < 35
return 4
else
return 5
end
end

function bmi_category(idx)
idx == 1 ? "Underweight" :
idx == 2 ? "Normal" :
idx == 3 ? "Overweight" :
idx == 4 ? "Obese I" : "Obese II+"
end

function bmi_percentile(bmi_value, bmi_values)
return round(sum(bmi_values .<= bmi_value) / length(bmi_values) * 100, digits=2)
end

function interpret_percentile(p)
if p < 10
return "You are in the **lowest 10%** of BMI (much below most people)."
elseif p < 25
return "You are in the **bottom 25%** (below average BMI)."
elseif p < 50
return "You are **below average** BMI."
elseif p < 75
return "You are **above average** BMI."
elseif p < 90
return "You are in the **top 25%** of BMI (higher than most people)."
else
return "You are in the **highest 10%** of BMI (very high compared to others)."
end
end

# --- Example student input ---
age = 88
weight = 110.0 # kg
height = 160.0 # cm

# --- Calculate stats ---
student_bmi = calc_bmi(weight, height)
student_category = bmi_category(bmi_index(student_bmi))
student_percentile = bmi_percentile(student_bmi, bmi_values)
interpretation = interpret_percentile(student_percentile)

println("🎓 Student age: $age")
println("✅ BMI: $student_bmi ($student_category)")
println("✅ Percentile in dataset: $student_percentile%")
println("📌 Interpretation: $interpretation")

# --- Plot CDF with student point ---
trace_curve = scatter(
x = bmi_values, y = cumulative_prob,
mode = "lines", line = attr(color="purple", width=3),
name = "Population CDF"
)

trace_point = scatter(
x = [student_bmi],
y = [student_percentile],
mode = "markers+text",
marker = attr(color="red", size=12),
text = ["You are here! (BMI=$student_bmi, $student_category)"],
textposition = "top center",
name = "Student"
)

layout = Layout(
title = "BMI CDF with Student Position",
xaxis = attr(title="BMI"),
yaxis = attr(title="Cumulative Probability (%)"),
legend = attr(x=0.05, y=0.95)
)

display(plot([trace_curve, trace_point], layout))