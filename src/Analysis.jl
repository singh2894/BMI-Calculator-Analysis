#############################
# BMI analysis & visuals (clean, single-run)
#############################

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
const SHOW_PLOTS = true   # set false to only save HTML and avoid any on-screen plots

# ====== 1) File paths (EDIT THESE) ======
dataset_path = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\output\updated_Gender_Classification_Data.csv"
user_path    = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\output\user_data.csv"

# ====== 2) Helpers ======
# detect tab/comma/semicolon
function detect_delim(path::AbstractString)
    firstline = open(readline, path)
    if occursin('\t', firstline)
        return '\t'
    elseif occursin(';', firstline)
        return ';'
    else
        return ','
    end
end

# BMI (cm, kg) + safe missing methods
bmi_from(h::Real, w::Real) = w / (h/100)^2
bmi_from(::Missing, ::Any) = missing
bmi_from(::Any, ::Missing) = missing
bmi_from(::Missing, ::Missing) = missing

function bmi_index_and_category(bmi::Union{Missing,Real})
    if bmi === missing
        return missing, "Missing"
    end
    b = Float64(bmi)
    if b < 18.5
        return 1, "Underweight"
    elseif b < 25
        return 2, "Normal"
    elseif b < 30
        return 3, "Overweight"
    elseif b < 35
        return 4, "Obese I"
    else
        return 5, "Obese II+"
    end
end

# normalize headers, drop junk columns, ensure expected columns exist
const KEEP = [:height, :weight, :BMI, :BMI_index, :gender, :age]
function harmonize!(df::DataFrame)
    rename!(df, Dict(names(df) .=> Symbol.(replace.(lowercase.(String.(names(df))), " " => "_"))))
    ren = Dict(
        :height_cm=>:height, :weight_kg=>:weight,
        :bmi=>:BMI, :bmi_index=>:BMI_index, :index=>:BMI_index
    )
    for (k,v) in ren
        if k in names(df) && v != k
            rename!(df, k=>v)
        end
    end
    # drop artifacts like :column7 …
    for nm in names(df)
        s = String(nm)
        if startswith(s, "column") && !(nm in KEEP)
            select!(df, Not(nm))
        end
    end
    for c in KEEP
        if !(c in names(df))
            df[!, c] = missing
        end
    end
    return df
end

# parse/float helper
parse_float(x) = x isa Number ? float(x) :
                 try parse(Float64, String(x)) catch; missing end

# ====== 3) Load ======
d_delim = detect_delim(dataset_path)
u_delim = detect_delim(user_path)

df     = CSV.read(dataset_path, DataFrame; delim=d_delim, ignorerepeated=true,
                  missingstring=["", "NA", "NaN", "null", "Nil", "Missing"])
userdf = CSV.read(user_path,    DataFrame; delim=u_delim, ignorerepeated=true,
                  missingstring=["", "NA", "NaN", "null", "Nil", "Missing"])

harmonize!(df)
harmonize!(userdf)

# convert numerics
for col in (:height, :weight, :BMI, :BMI_index, :age)
    if col in names(df);     df[!, col]     = passmissing(parse_float).(df[!, col]);     end
    if col in names(userdf); userdf[!, col] = passmissing(parse_float).(userdf[!, col]); end
end

# ====== 4) Remove decimals first (round) ======
if :height in names(df);     df.height     = passmissing(x->round(Int, x)).(df.height);     end
if :weight in names(df);     df.weight     = passmissing(x->round(Int, x)).(df.weight);     end
if :height in names(userdf); userdf.height = passmissing(x->round(Int, x)).(userdf.height); end
if :weight in names(userdf); userdf.weight = passmissing(x->round(Int, x)).(userdf.weight); end

# compute BMI if missing (using rounded ints)
if :BMI in names(df)
    df.BMI = ifelse.(ismissing.(df.BMI),
                     bmi_from.(Float64.(df.height), Float64.(df.weight)),
                     Float64.(df.BMI))
else
    df.BMI = bmi_from.(Float64.(df.height), Float64.(df.weight))
end

# user BMI
if nrow(userdf) == 0
    error("user_data.csv appears empty.")
end
user_row = userdf[1, :]
user_bmi = get(user_row, :BMI, missing)
if ismissing(user_bmi)
    h = get(user_row, :height, missing)
    w = get(user_row, :weight, missing)
    if ismissing(h) || ismissing(w)
        error("User row is missing BMI and also height/weight.")
    end
    user_bmi = bmi_from(Float64(h), Float64(w))
end
user_idx, user_cat = bmi_index_and_category(user_bmi)

# ====== 5) Final clean & metrics ======
df_valid = filter(:BMI => x -> x !== missing && isfinite(x) && x > 0, df)
bmis = Float64.(df_valid.BMI)
N = length(bmis)
N == 0 && error("No valid BMI values after cleaning. Check delimiter and columns.")

F = ecdf(bmis)
user_percentile = 100 * F(user_bmi)
prop_overweight_plus = 100 * mean(bmis .>= 25.0)
pct_below_user = 100 * mean(bmis .< user_bmi)
pct_above_user = 100 - pct_below_user

println("Summary → BMI=$(round(user_bmi, digits=2)) | Cat=$user_cat | Perc≈$(round(user_percentile, digits=1))% | Overweight+≈$(round(prop_overweight_plus, digits=1))%")

# ====== 6) Visuals ======
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

# C) Height vs Weight (robust)
have_hw = all(Symbol.(["height","weight"]) .∈ Ref(names(df)))
if have_hw
    mask = .!(ismissing.(df.height)) .& .!(ismissing.(df.weight)) .& .!(ismissing.(df.BMI))
    hvals = Float64.(df.height[mask])
    wvals = Float64.(df.weight[mask])
    bvals = Float64.(df.BMI[mask])

    if isempty(hvals)
        pltC = Plot([scatter(x=[0], y=[0], mode="text", text=["(No non-missing H/W rows; skipping)"])])
    else
        cloud = scatter(x=hvals, y=wvals, mode="markers", name="Population",
                        marker=attr(size=6, color=bvals, colorscale="Viridis",
                                    showscale=true, colorbar=attr(title="BMI")))
        tracesC = PlotlyJS.SyncPlot[cloud]
        uh = get(user_row, :height, missing); uw = get(user_row, :weight, missing)
        if !(ismissing(uh) || ismissing(uw))
            push!(tracesC, scatter(x=[Float64(uh)], y=[Float64(uw)], mode="markers+text", name="User",
                                   marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                                   text=[@sprintf("BMI %.2f (%s)", user_bmi, user_cat)],
                                   textposition="top center"))
        end
        layoutC = Layout(title="Height vs Weight (BMI colors)",
                         xaxis_title="Height (cm)", yaxis_title="Weight (kg)", showlegend=false)
        pltC = Plot(tracesC, layoutC)
    end
else
    pltC = Plot([scatter(x=[0], y=[0], mode="text", text=["(Height/Weight missing; skipping)"])])
end

# D) Box: BMI by category + user
cat_order = ["Underweight","Normal","Overweight","Obese I","Obese II+"]
df_valid.BMI_cat = [bmi_index_and_category(b)[2] for b in df_valid.BMI]
df_valid.BMI_cat = map(cat -> (cat in cat_order) ? cat : "Other", df_valid.BMI_cat)
box_traces = PlotlyJS.Plot[]
for cat in cat_order
    vals = Float64.(df_valid.BMI[df_valid.BMI_cat .== cat])
    !isempty(vals) && push!(box_traces, box(y=vals, name=cat, boxpoints="outliers",
                                            marker_color=population_color, line=attr(color=population_color)))
end
user_ref = scatter(x=[user_cat], y=[user_bmi], mode="markers+text", name="User",
                   marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                   text=[@sprintf("BMI %.2f", user_bmi)], textposition="top center")
layoutD = Layout(title="BMI by Category — User Marked", yaxis_title="BMI", showlegend=false,
                 annotations=[attr(x=0.98, y=0.98, xref="paper", yref="paper", xanchor="right", showarrow=false,
                                   text=@sprintf("Overweight+ in dataset: %.1f%%", prop_overweight_plus),
                                   font=attr(size=13, color=accent_color))])
pltD = Plot([box_traces... , user_ref], layoutD)

# E) Bar: counts by BMI category × gender
if :gender in names(df_valid)
    g = coalesce.(String.(df_valid.gender), "Unknown")
    c = coalesce.(String.(df_valid.BMI_cat), "Missing")
    tbl = combine(groupby(DataFrame(gender=g, cat=c), [:gender, :cat]), nrow => :count)
    bars = bar(x=tbl.cat, y=tbl.count, transforms=[attr(type="groupby", groups=tbl.gender)])
    layoutE = Layout(title="Counts by BMI Category × Gender",
                     xaxis_title="BMI Category", yaxis_title="Count", barmode="group")
    pltE = Plot(bars, layoutE)
else
    pltE = Plot([scatter(x=[0], y=[0], mode="text", text=["(No gender column; skipping)"])])
end

# F) Violin: BMI by gender
if :gender in names(df_valid)
    vio_traces = PlotlyJS.Plot[]
    for g in unique(skipmissing(df_valid.gender))
        push!(vio_traces, violin(y=Float64.(df_valid.BMI[df_valid.gender .== g]),
                                 name=String(g), box_visible=true, meanline_visible=true))
    end
    layoutF = Layout(title="BMI Distribution by Gender (Violin)")
    pltF = Plot(vio_traces, layoutF)
else
    pltF = Plot([scatter(x=[0], y=[0], mode="text", text=["(No gender column; skipping)"])])
end

# ====== 7) Show (no duplicates) & Save ======
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

nothing  # prevent VS Code from auto-rendering last value twice
