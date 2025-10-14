# =========================
# BMI Comparison (Clean Data, Two Datasets)
# - Assumes both CSVs already have: gender,height,weight,age,BMI,BMI_Index
# - user_data.csv has exactly ONE row
# - No parsing/missing handling/BMI recomputation — just load & compare
# =========================

using Unicode
import Pkg
for pkg in ["CSV", "DataFrames", "StatsBase", "Statistics", "PlotlyJS", "Printf"]
    try
        @eval using $(Symbol(pkg))
    catch
        Pkg.add(pkg); @eval using $(Symbol(pkg))
    end
end

using CSV, DataFrames, StatsBase, Statistics, PlotlyJS, Printf

# ====== 0) Settings ======
const SHOW_PLOTS = true   # set false to only save HTML

# ====== 1) File paths (EDIT THESE) ======
dataset_path = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\output\updated_Gender_Classification_Data.csv"
user_path    = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\output\user_data.csv"

# ====== 2) Load (clean CSVs with standard headers) ======
df     = CSV.read(dataset_path, DataFrame)  # large population (e.g., 10,000 rows)
userdf = CSV.read(user_path,    DataFrame)  # exactly 1 row

@assert nrow(userdf) == 1 "user_data.csv must have exactly one row"
required_cols = [:gender, :height, :weight, :age, :BMI, :BMI_Index]
@assert all(Ref(required_cols) .∈ names.(Ref(df))) "Population CSV missing required columns"
@assert all(Ref(required_cols) .∈ names.(Ref(userdf))) "User CSV missing required columns"

# Pull user values
user = userdf[1, :]
user_bmi  = Float64(user.BMI)
user_idx  = Int(user.BMI_Index)
user_cat  = get(Dict(1=>"Underweight", 2=>"Normal", 3=>"Overweight", 4=>"Obese I", 5=>"Obese II+"), user_idx, "Other")

# ====== 3) Quick metrics (from clean data; no recomputation) ======
bmis = Float64.(df.BMI)
N = length(bmis)
F = ecdf(bmis)
user_percentile = 100 * F(user_bmi)
prop_overweight_plus = 100 * mean(bmis .>= 25.0)
pct_below_user = 100 * mean(bmis .< user_bmi)
pct_above_user = 100 - pct_below_user

println("Summary → BMI=$(round(user_bmi, digits=2)) | Cat=$user_cat | Perc≈$(round(user_percentile, digits=1))% | Overweight+≈$(round(prop_overweight_plus, digits=1))%")

# ====== 4) Visuals ======
user_color       = "#d62728"
population_color = "#1f77b4"
accent_color     = "#2ca02c"

# A) Histogram + user line
hist = histogram(x=bmis, nbinsx=40, name="Population BMI",
                 marker_color=population_color, opacity=0.7)
user_line = scatter(x=[user_bmi, user_bmi], y=[0, 1], mode="lines",
                    name="User BMI", line=attr(color=user_color, width=3))
layoutA = Layout(
    title = "BMI Distribution — User Highlighted",
    xaxis_title = "BMI", yaxis_title = "Count / Frequency",
    barmode = "overlay", showlegend = true,
    shapes = [attr(type="line", x0=user_bmi, x1=user_bmi, y0=0, y1=1,
                   xref="x", yref="paper", line=attr(color=user_color, width=3, dash="dash"))],
    annotations = [
        attr(x=user_bmi, y=1.02, xref="x", yref="paper", showarrow=false,
             text=@sprintf("User BMI = %.2f (%s)", user_bmi, user_cat),
             font=attr(size=14, color=user_color)),
        attr(x=0.98, y=0.98, xref="paper", yref="paper", xanchor="right", showarrow=false,
             text=@sprintf("User at %.1f%% percentile", user_percentile),
             font=attr(size=13))
    ]
)
pltA = Plot([hist, user_line], layoutA)

# B) ECDF + user marker
x_sorted = sort(bmis)
y_ecdf   = collect(range(1/N, 1; length=N))
cdf_trace = scatter(x=x_sorted, y=y_ecdf, mode="lines", name="ECDF (BMI)",
                    line=attr(color=population_color, width=3))
user_marker = scatter(x=[user_bmi], y=[F(user_bmi)], mode="markers+text", name="User",
                      marker=attr(size=12, color=user_color),
                      text=[@sprintf("BMI %.2f\n%.1f%%", user_bmi, user_percentile)],
                      textposition="top center")
layoutB = Layout(
    title = "Where Does the User Lie? (ECDF)",
    xaxis_title = "BMI", yaxis_title = "Fraction ≤ BMI",
    showlegend = false,
    annotations = [
        attr(x=0.98, y=0.18, xref="paper", yref="paper", xanchor="right", showarrow=false,
             text=@sprintf("User BMI = %.2f (%s)<br>Percentile: %.1f%%<br>Below: %.1f%% · Above: %.1f%%",
                           user_bmi, user_cat, user_percentile, pct_below_user, pct_above_user),
             font=attr(size=13))
    ]
)
pltB = Plot([cdf_trace, user_marker], layoutB)

# C) Height vs Weight (colored by BMI) + user point
hvals = Float64.(df.height)
wvals = Float64.(df.weight)
bvals = Float64.(df.BMI)

cloud = scatter(x=hvals, y=wvals, mode="markers", name="Population",
                marker=attr(size=6, color=bvals, colorscale="Viridis",
                            showscale=true, colorbar=attr(title="BMI")))
tracesC = PlotlyJS.SyncPlot[cloud]
push!(tracesC, scatter(x=[Float64(user.height)], y=[Float64(user.weight)], mode="markers+text", name="User",
                       marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                       text=[@sprintf("BMI %.2f (%s)", user_bmi, user_cat)],
                       textposition="top center"))
layoutC = Layout(title="Height vs Weight (BMI colors)",
                 xaxis_title="Height (cm)", yaxis_title="Weight (kg)", showlegend=false)
pltC = Plot(tracesC, layoutC)

# D) Box: BMI by BMI_Index category + user
cat_map = Dict(1=>"Underweight", 2=>"Normal", 3=>"Overweight", 4=>"Obese I", 5=>"Obese II+")
cat_order = ["Underweight","Normal","Overweight","Obese I","Obese II+"]

BMI_cat = [get(cat_map, Int(i), "Other") for i in df.BMI_Index]
df_cat = DataFrame(BMI=df.BMI, BMI_cat=BMI_cat)

box_traces = PlotlyJS.Plot[]
for cat in cat_order
    vals = Float64.(df_cat.BMI[df_cat.BMI_cat .== cat])
    !isempty(vals) && push!(box_traces, box(y=vals, name=cat, boxpoints="outliers",
                                            marker_color=population_color, line=attr(color=population_color)))
end

user_ref = scatter(x=[user_cat], y=[user_bmi], mode="markers+text", name="User",
                   marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                   text=[@sprintf("BMI %.2f", user_bmi)], textposition="top center")
layoutD = Layout(title="BMI by Category (from BMI_Index) — User Marked", yaxis_title="BMI", showlegend=false,
                 annotations=[attr(x=0.98, y=0.98, xref="paper", yref="paper", xanchor="right", showarrow=false,
                                   text=@sprintf("Overweight+ in dataset: %.1f%%", prop_overweight_plus),
                                   font=attr(size=13, color=accent_color))])
pltD = Plot([box_traces... , user_ref], layoutD)

# E) Bar: counts by BMI category × gender
g = String.(df.gender)
c = String.([get(cat_map, Int(i), "Other") for i in df.BMI_Index])
tbl = combine(groupby(DataFrame(gender=g, cat=c), [:gender, :cat]), nrow => :count)
bars = bar(x=tbl.cat, y=tbl.count, transforms=[attr(type="groupby", groups=tbl.gender)])
layoutE = Layout(title="Counts by BMI Category × Gender",
                 xaxis_title="BMI Category", yaxis_title="Count", barmode="group")
pltE = Plot(bars, layoutE)

# F) Violin: BMI by gender
vio_traces = PlotlyJS.Plot[]
for gg in unique(g)
    push!(vio_traces, violin(y=Float64.(df.BMI[g .== gg]), name=gg, box_visible=true, meanline_visible=true))
end
layoutF = Layout(title="BMI Distribution by Gender (Violin)")
pltF = Plot(vio_traces, layoutF)

# ====== 5) Show & Save ======
if SHOW_PLOTS
    display(pltA); display(pltB); display(pltC)
    display(pltD); display(pltE); display(pltF)
end

isdir("output") || mkpath("output")
try
    PlotlyJS.savehtml(pltA, joinpath("output", "bmi_histogram.html"))
    PlotlyJS.savehtml(pltB, joinpath("output", "where_user_lies.html"))
    println("Saved HTML → output/bmi_histogram.html, output/where_user_lies.html")
catch e
    @warn "Could not save HTML plots" exception=(e, catch_backtrace())
end

println("────────────────────────────────────────────────────────")
@printf "User BMI = %.2f (%s). Percentile ≈ %.1f%%\n" user_bmi user_cat user_percentile
@printf "Overweight+ share = %.1f%% | Below user = %.1f%% | Above user = %.1f%%\n" prop_overweight_plus pct_below_user pct_above_user
println("────────────────────────────────────────────────────────")


