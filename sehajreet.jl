
##############################################################
# 3) Stats: % within BMI by age interval + Chi-square
##############################################################

# Percent within BMI_Index by AgeInterval
counts = combine(groupby(dropmissing(df, [:BMI_Index, :AgeInterval]),
                         [:BMI_Index, :AgeInterval]), nrow => :count)

# compute % within each BMI_Index
counts = combine(groupby(counts, :BMI_Index)) do sdf
    total = sum(sdf.count)
    sdf[:, :pct_within_bmi] = round.(100 .* sdf.count ./ max(total, 1); digits=1)
    sdf
end

pivot_pct = unstack(counts, :BMI_Index, :AgeInterval, :pct_within_bmi)
println("\n% within BMI_Index by AgeInterval:"); println(pivot_pct)

# Chi-square: AgeInterval vs BMI_Index
cont_table = combine(groupby(dropmissing(df, [:AgeInterval, :BMI_Index]),
                             [:AgeInterval, :BMI_Index]), nrow => :count)
pivot_chi = unstack(cont_table, :AgeInterval, :BMI_Index, :count)
pivot_chi = coalesce.(pivot_chi, 0)  # fill missing counts with 0
mat = Matrix{Int}(select(pivot_chi, Not(:AgeInterval)))

try
    test_result = ChisqTest(mat)
    println("\nChi-square test:"); println(test_result)
    println(pvalue(test_result) < 0.05 ?
        "→ Significant association between BMI and AgeInterval." :
        "→ No strong evidence of association between BMI and AgeInterval.")
catch e
    @warn "Chi-square test failed" error=e
end

##############################################################
# 4) Gender comparison
##############################################################
if :gender in names(df)
    # normalize gender strings & drop missings
    df.gender = map(x -> ismissing(x) ? missing : lowercase(string(x)), df.gender)
    gd = dropmissing(df, [:gender, :BMI_Index])
    gender_stats = combine(groupby(gd, [:gender, :BMI_Index]), nrow => :Count)
    println("\nCounts by gender and BMI_Index:"); println(gender_stats)
else
    @warn "No :gender column found; skipping gender analyses."
end

male_df   = filter(row -> haskey(row, :gender) && row.gender == "male",   df)
female_df = filter(row -> haskey(row, :gender) && row.gender == "female", df)

##############################################################
# 5) Visualizations (PlotlyJS)
##############################################################

# (A) Scatter: Height vs Weight by gender
if !isempty(male_df) && !isempty(female_df)
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

function interpret_percentile(p)
    if p < 10
        "You are in the **lowest 10%** of BMI (much below most people)."
    elseif p < 25
        "You are in the **bottom 25%** (below average BMI)."
    elseif p < 50
        "You are **below average** BMI."
    elseif p < 75
        "You are **above average** BMI."
    elseif p < 90
        "You are in the **top 25%** of BMI (higher than most people)."
    else
        "You are in the **highest 10%** of BMI (very high compared to others)."
    end
end

# Example student input (change live in REPL during class)
age    = 21
weight = 68.0   # kg
height = 160.0   # cm

student_bmi = calc_bmi(weight, height)
student_idx = bmi_index_from_value(student_bmi)
student_cat = bmi_category_from_index(student_idx)
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

