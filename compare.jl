import Pkg
for pkg in ["CSV", "DataFrames", "StatsBase", "Statistics", "PlotlyJS", "Colors", "Printf"]
    @eval (isdefined(Main, Symbol($pkg)) || Pkg.installed() !== nothing)
    try
        Base.eval(Main, :(using $(Symbol(pkg))))
    catch
        Pkg.add(pkg)
        Base.eval(Main, :(using $(Symbol(pkg))))
    end
end

using CSV, DataFrames, StatsBase, Statistics, PlotlyJS, Colors, Printf

# -----------------------------
# 1) File paths (from your prompt)
# -----------------------------
dataset_path = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\BMI-Calculator-Analysis\Updated_dataset.csv"
user_path    = raw"C:\Users\Simran\OneDrive\Desktop\BMI Calculator Analysis\BMI-Calculator-Analysis\user_data.csv"

# -----------------------------
# 2) Helpers
# -----------------------------
bmi_from(hw...) = begin
    # Accept either (height_cm, weight_kg) or a NamedTuple/DataFrameRow
    if length(hw) == 1
        row = hw[1]
        h = get(row, :height,  get(row, :Height,  missing))
        w = get(row, :weight,  get(row, :Weight,  missing))
    else
        h, w = hw
    end
    if any(ismissing.((h, w))) || h <= 0 || w <= 0
        return missing
    end
    # BMI = kg / (m^2). Height is expected in cm here.
    return w / (h/100)^2
end

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

# -----------------------------
# 3) Load data
# -----------------------------
df = CSV.read(dataset_path, DataFrame; missingstring=["", "NA", "NaN"])
userdf = CSV.read(user_path, DataFrame; missingstring=["", "NA", "NaN"])

# Ensure expected columns exist
for col in (:height, :weight)
    if !(col in names(df)) && !(Symbol(string(col)[1:1] |> uppercase) in names(df))
        @warn "Column $(col) not found in dataset. Make sure your dataset has height (cm) and weight (kg)."
    end
end

# Compute BMI for the population if not present
if !(:BMI in names(df))
    df.BMI = [bmi_from(r) for r in eachrow(df)]
end

# (Optional) also keep height/weight if present (used in a scatter later)
has_height = :height in names(df) ? :height : (:Height in names(df) ? :Height : nothing)
has_weight = :weight in names(df) ? :weight : (:Weight in names(df) ? :Weight : nothing)

# Compute BMI for the single user
if nrow(userdf) == 0
    error("user_data.csv appears empty.")
end
user_row = userdf[1, :]
user_bmi = haskey(user_row, :BMI) ? user_row[:BMI] : bmi_from(user_row)

# Validate user_bmi
if user_bmi === missing
    error("User BMI is missing or invalid. Ensure user_data.csv has numeric height (cm) and weight (kg).")
end

# Compute BMI index & category columns for dataset
df.BMI_index = similar(df.BMI, Union{Missing,Int})
df.BMI_cat   = Vector{String}(undef, nrow(df))
for (i, b) in pairs(df.BMI)
    idx, cat = bmi_index_and_category(b)
    df.BMI_index[i] = idx
    df.BMI_cat[i]   = cat
end

# User index & category
user_idx, user_cat = bmi_index_and_category(user_bmi)

# Filter to valid BMI values
df_valid = filter(:BMI => x -> x !== missing && isfinite(x), df)
bmis = Float64.(df_valid.BMI)
N = length(bmis)
if N == 0
    error("No valid BMI values in the dataset after cleaning.")
end

# -----------------------------
# 4) Where does the user lie?
# -----------------------------
# Empirical CDF to get percentile (fraction of population with BMI <= user BMI)
F = ecdf(bmis)
user_percentile = 100 * F(user_bmi)

# Share of people overweight+ (BMI >= 25)
prop_overweight_plus = 100 * mean(bmis .>= 25)

# % of people with BMI LOWER than the user's
pct_below_user = 100 * mean(bmis .< user_bmi)
# % of people with BMI HIGHER than the user's
pct_above_user = 100 - pct_below_user

@info @sprintf "User BMI = %.2f, Category = %s, Percentile = %.1f%%, %.1f%% are overweight+ in dataset" user_bmi user_cat user_percentile prop_overweight_plus

# -----------------------------
# 5) Plots (4 different comparisons)
# -----------------------------
# Common colors
user_color    = "#d62728"  # red-ish
population_color = "#1f77b4" # blue-ish
accent_color  = "#2ca02c"  # green-ish

# ---- Plot A: Histogram of BMI with vertical line at user's BMI ----
hist = histogram(x=bmis, nbinsx=40,
                 name="Population BMI",
                 marker_color=population_color, opacity=0.7)

# A thin marker trace to put a visible dot on top of the histogram at user's BMI density≈0
user_line = scatter(x=[user_bmi, user_bmi], y=[0, 1],
                    mode="lines",
                    name="User BMI",
                    line=attr(color=user_color, width=3))

layoutA = Layout(
    title = "BMI Distribution User Highlighted",
    xaxis_title = "BMI",
    yaxis_title = "Count / Frequency",
    barmode = "overlay",
    showlegend = true,
    shapes = [
        # Vertical line at user BMI
        attr(type="line", x0=user_bmi, x1=user_bmi, y0=0, y1=1, xref="x", yref="paper",
             line=attr(color=user_color, width=3, dash="dash"))
    ],
    annotations = [
        attr(
            x=user_bmi, y=1.02, xref="x", yref="paper", showarrow=false,
            text=@sprintf("User BMI = %.2f (%s)", user_bmi, user_cat),
            font=attr(size=14, color=user_color)
        ),
        attr(
            x=0.98, y=0.98, xref="paper", yref="paper", xanchor="right", showarrow=false,
            text=@sprintf("User at %.1f%% percentile", user_percentile),
            font=attr(size=13)
        )
    ]
)

pltA = Plot([hist, user_line], layoutA)

# ---- Plot B: Empirical CDF with user marker ----
x_sorted = sort(bmis)
y_cdf = range(1/N, 1; length=N)
cdf_trace = scatter(x=x_sorted, y=y_cdf,
                    mode="lines", name="ECDF (BMI)",
                    line=attr(color=population_color, width=3))

user_marker = scatter(x=[user_bmi], y=[F(user_bmi)],
                      mode="markers+text", name="User",
                      marker=attr(size=12, color=user_color),
                      text=[@sprintf("BMI %.2f\n%.1f%%", user_bmi, user_percentile)],
                      textposition="top center")

layoutB = Layout(
    title = "Where the User Sits (ECDF Rank Plot)",
    xaxis_title = "BMI",
    yaxis_title = "Fraction =< BMI",
    showlegend = false,
    annotations = [

        attr(
            x=0.98, y=0.1, xref="paper", yref="paper", xanchor="right", showarrow=false,
            text=@sprintf("Below user: %.1f%%<br>Above user: %.1f%%", pct_below_user, pct_above_user),
            font=attr(size=13)
        )
    ]
)
pltB = Plot([cdf_trace, user_marker], layoutB)

# ---- Plot C: Height vs Weight scatter (colored by BMI) + user highlight ----
tracesC = PlotlyJS.SyncPlot[]

if has_height !== nothing && has_weight !== nothing
    heights = skipmissing(df_valid[!, has_height])
    weights = skipmissing(df_valid[!, has_weight])
    # Keep rows where both h & w are present
    mask_hw = .!(ismissing.(df_valid[!, has_height])) .& .!(ismissing.(df_valid[!, has_weight]))
    hvals = Float64.(df_valid[mask_hw, has_height])
    wvals = Float64.(df_valid[mask_hw, has_weight])
    bvals = Float64.(df_valid[mask_hw, :BMI])

    cloud = scatter(x=hvals, y=wvals, mode="markers",
                    name="Population",
                    marker=attr(size=6, color=bvals, colorscale="Viridis",
                                showscale=true, colorbar=attr(title="BMI")))
    push!(tracesC, cloud)

    # User point:
    user_h = get(user_row, has_height, missing)
    user_w = get(user_row, has_weight, missing)
    if !(ismissing(user_h) || ismissing(user_w))
        user_pt = scatter(x=[Float64(user_h)], y=[Float64(user_w)], mode="markers+text",
                          name="User",
                          marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                          text=[@sprintf("BMI %.2f (%s)", user_bmi, user_cat)],
                          textposition="top center")
        push!(tracesC, user_pt)
    end

    layoutC = Layout(
        title = "Height vs Weight Colored by BMI (User Highlighted)",
        xaxis_title = "Height (cm)",
        yaxis_title = "Weight (kg)",
        showlegend = false
    )
    pltC = Plot(tracesC, layoutC)
else
    pltC = Plot([scatter(x=[0], y=[0], mode="text", text=["(Height/Weight columns not found; skipping plot)"])])
end

# ---- Plot D: Box plot of BMI by BMI category + user reference ----
# Order categories
cat_order = ["Underweight", "Normal", "Overweight", "Obese I", "Obese II+"]
df_valid.BMI_cat = map(cat -> cat in cat_order ? cat : "Other", df_valid.BMI_cat)

box_traces = PlotlyJS.Plot[]  # Collect traces per category
for cat in cat_order
    vals = Float64.(df_valid.BMI[df_valid.BMI_cat .== cat])
    if !isempty(vals)
        push!(box_traces, box(y=vals, name=cat, boxpoints="outliers",
                              marker_color=population_color, line=attr(color=population_color)))
    end
end

user_ref = scatter(x=[user_cat], y=[user_bmi], mode="markers+text",
                   name="User", marker=attr(size=14, color=user_color, line=attr(width=2, color="white")),
                   text=[@sprintf("BMI %.2f", user_bmi)], textposition="top center")

layoutD = Layout(
    title = "BMI by Category — User Marked",
    yaxis_title = "BMI",
    showlegend = false,
    annotations = [
        attr(
            x=0.98, y=0.98, xref="paper", yref="paper", xanchor="right", showarrow=false,
            text=@sprintf("Overweight+ in dataset: %.1f%%", prop_overweight_plus),
            font=attr(size=13, color=accent_color)
        )
    ]
)
pltD = Plot([box_traces... , user_ref], layoutD)

# -----------------------------
# 6) Show (in REPL/Pluto/Jupyter these display automatically)
# -----------------------------
display(pltA)
display(pltB)
display(pltC)
display(pltD)

# -----------------------------
# 7) Print a concise summary line in the console
# -----------------------------
println("────────────────────────────────────────────────────────")
@printf "User BMI = %.2f (%s). They are at the %.1f%% percentile.\n" user_bmi user_cat user_percentile
@printf "%.1f%% of people in the dataset are BMI ≥ 25 (Overweight+).\n" prop_overweight_plus
@printf "About %.1f%% have a lower BMI than the user; %.1f%% have a higher BMI.\n" pct_below_user pct_above_user
println("────────────────────────────────────────────────────────")
