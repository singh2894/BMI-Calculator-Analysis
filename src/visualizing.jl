##################################################
# Visualizing data with PlotlyJS
##################################################

using DataFrames: combine, groupby, dropmissing, sort
import PlotlyJS
const PJ = PlotlyJS

# --- Visualizations  ---

function bmi_percentile(bmi_value, bmi_values_vec)
    # percentile based on empirical CDF
    return round(sum(bmi_values_vec .<= bmi_value) / length(bmi_values_vec) * 100, digits=2)
end

function bmi_category(idx)
    idx == 1 ? "Underweight" :
    idx == 2 ? "Normal" :
    idx == 3 ? "Overweight" :
    idx == 4 ? "Obese I" : "Obese II+"
end

# (A) Scatter: Height vs Weight by gender

# Define male and female subsets first
function show_charts(df)

    male_df = df[df.gender.=="male", :]
    female_df = df[df.gender.=="female", :]

    #check if they are not empty before plotting
    if !isempty(male_df) && !isempty(female_df)


            male_trace = PJ.scatter(x=male_df.weight, y=male_df.height,
                mode="markers", marker=PJ.attr(color="steelblue", size=7, opacity=0.6), name="Male")
            female_trace = PJ.scatter(x=female_df.weight, y=female_df.height,
                mode="markers", marker=PJ.attr(color="lightcoral", size=7, opacity=0.6), name="Female")
            display(PJ.plot([male_trace, female_trace],
                PJ.Layout(title="Height vs Weight", xaxis=PJ.attr(title="Weight (kg)"), yaxis=PJ.attr(title="Height (cm)"))))
    end

    # (B) Line: Average Weight by Age (unique ages)
    if :age in names(df) && :weight in names(df)
        trend = DataFrames.combine(DataFrames.groupby(DataFrames.dropmissing(df, [:age, :weight]), :age), :weight => mean => :Mean_Weight)
        trend = DataFrames.sort(trend, :age)
        trace_w = PJ.scatter(x=trend.age, y=trend.Mean_Weight,
            mode="lines+markers", line=PJ.attr(color="steelblue", width=3),
            marker=PJ.attr(size=6), name="Avg Weight")
        display(PJ.plot([trace_w], PJ.Layout(title="Average Weight by Age",
            xaxis=PJ.attr(title="Age"), yaxis=PJ.attr(title="Average Weight (kg)"))))
    end

    # (C) Box Plot: Height by Gender
    if !isempty(male_df) && !isempty(female_df)
    male_box = PJ.box(y=male_df.height, name="Male Height", marker=PJ.attr(color="steelblue"))
    female_box = PJ.box(y=female_df.height, name="Female Height", marker=PJ.attr(color="lightcoral"))
    display(PJ.plot([male_box, female_box], PJ.Layout(title="Height Distribution by Gender")))
    end

    # (D) BMI Distribution (% by category)
    ##############################################################
    # Create BMI_Category column from BMI_Index 
    if !(:BMI_Category in names(df))
        df.BMI_Category = map(x -> ismissing(x) ? missing : bmi_category(x), df.BMI_Index)
    end

    counts_bmi = DataFrames.combine(DataFrames.groupby(DataFrames.dropmissing(df, :BMI_Category), :BMI_Category), nrow => :Count)
    total_bmi = max(sum(counts_bmi.Count), 1)
    counts_bmi.Percent = round.(counts_bmi.Count ./ total_bmi .* 100, digits=2)

    cats = ["Underweight", "Normal", "Overweight", "Obese I", "Obese II+"]
    color_map = Dict("Underweight" => "steelblue", "Normal" => "mediumseagreen",
        "Overweight" => "khaki", "Obese I" => "sandybrown", "Obese II+" => "indianred")

    trace_hist = PJ.bar(
        x=counts_bmi.BMI_Category,
        y=counts_bmi.Percent,
        marker=PJ.attr(color=[color_map[c] for c in counts_bmi.BMI_Category]),
        text=string.(counts_bmi.Percent, "%"),
        textposition="outside",
        name="BMI %"
    )
    display(PJ.plot([trace_hist], PJ.Layout(
        title="BMI Distribution",
        xaxis=PJ.attr(categoryorder="array", categoryarray=cats),
        yaxis=PJ.attr(title="Percent (%)"),
        showlegend=false
    )))

    ##############################################################
    #CDF of BMI (+ 10th/90th + single “you are here” point)
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
    calc_bmi(weight, height_cm) = round(weight / ((height_cm / 100)^2), digits=2)


    # Example student input (change live in REPL during class)
    age = 21
    weight = 68.0   # kg
    height = 160.0   # cm

    student_bmi = calc_bmi(weight, height)
    student_idx = bmi_index(student_bmi)
    student_cat = bmi_category(student_idx)

    student_pct = bmi_percentile(student_bmi, bmi_values)
    interp = interpret_percentile(student_pct)

    println("\n🎓 Student age: $age")
    println("✅ BMI: $student_bmi ($student_cat)")
    println("✅ Percentile in dataset: $student_pct%")
    println("📌 Interpretation: $interp")

    # CDF trace
    trace_curve = PJ.scatter(
        x=bmi_values,
        y=cumulative_prob,
        mode="lines",
        line=PJ.attr(color="purple", width=3),
        name="BMI CDF"
    )

    # 10th & 90th percentile markers
    trace_p10 = PJ.scatter(x=[p10, p10], y=[0.0, 100.0], mode="lines", line=PJ.attr(color="red", dash="dash"), name="10th %")
    trace_p90 = PJ.scatter(x=[p90, p90], y=[0.0, 100.0], mode="lines", line=PJ.attr(color="green", dash="dash"), name="90th %")

    # Student point (y should be percentile, not CDF value at x strictly—both okay since we computed it)
    trace_point = PJ.scatter(
        x=[student_bmi],
        y=[student_pct],
        mode="markers+text",
        marker=PJ.attr(color="red", size=12),
        text=["You are here! (BMI=$(student_bmi), $(student_cat))"],
        textposition="top center",
        name="Student"
    )

    layout_cdf = PJ.Layout(
        title="BMI CDF with 10th/90th Percentiles + Student Position",
        xaxis=PJ.attr(title="BMI"),
        yaxis=PJ.attr(title="Cumulative Probability (%)"),
        legend=PJ.attr(x=0.02, y=0.98)
    )

    display(PJ.plot([trace_curve, trace_p10, trace_p90, trace_point], layout_cdf))
end
##############################################################