try
    @eval using Gtk
catch
    import Pkg
    Pkg.add("Gtk")
    @eval using Gtk
end
using Gtk, Gtk.ShortNames
using Printf
using Dates

# -------------------- BMI helpers --------------------
const THRESH = [18.5, 25.0, 30.0, 35.0]
const LABELS = ["Underweight","Normal","Overweight","Obese Class I","Obese Class II+"]
const COLORS = Dict(
    "Underweight"=>"#5B8DEF",
    "Normal"=>"#2FA96B",
    "Overweight"=>"#E3B341",
    "Obese Class I"=>"#E0793D",
    "Obese Class II+"=>"#C93C3C",
)

bmi_index(bmi::Float64) = searchsortedlast(THRESH, bmi) + 1
bmi_category(bmi::Float64) = LABELS[bmi_index(bmi)]

# -------------------- Window & outer layout --------------------
win = GtkWindow("BMI Calculator", 900, 700)
outer = GtkBox(:v)
# avoid GtkAlign enums — rely on expand + spacers instead
set_gtk_property!(outer, :vexpand, true)
push!(win, outer)

# --- Title ---
title = GtkLabel("")
set_gtk_property!(title, :use_markup, true)
set_gtk_property!(title, :label, "<span size='28000' weight='bold'>Body Mass Index Calculator</span>")
set_gtk_property!(title, :xalign, 0.5)   # centered by xalign

subtitle = GtkLabel("")
set_gtk_property!(subtitle, :use_markup, true)
set_gtk_property!(subtitle, :label, "<span size='16000' weight='bold' foreground='#555555'>BMI = weight (kg) / (height (m))²</span>")
set_gtk_property!(subtitle, :xalign, 0.5)

push!(outer, title)
push!(outer, subtitle)

# --- Center spacers ---
top_spacer    = GtkLabel("");  set_gtk_property!(top_spacer, :vexpand, true)
bottom_spacer = GtkLabel("");  set_gtk_property!(bottom_spacer, :vexpand, true)
push!(outer, top_spacer)

# --- Center container ---
center_row = GtkBox(:h)
left_spacer  = GtkLabel(""); set_gtk_property!(left_spacer,  :hexpand, true)
right_spacer = GtkLabel(""); set_gtk_property!(right_spacer, :hexpand, true)
push!(center_row, left_spacer)

grid = GtkGrid()
set_gtk_property!(grid, :column_spacing, 30)
set_gtk_property!(grid, :row_spacing, 20)
# keep grid centered using surrounding expanders (no halign/valign enums)
push!(center_row, grid)
push!(center_row, right_spacer)

push!(outer, center_row)
push!(outer, bottom_spacer)

# -------------------- Widgets --------------------
mklabel(txt) = begin
    l = GtkLabel("")
    set_gtk_property!(l, :use_markup, true)
    set_gtk_property!(l, :label, "<span size='15000' weight='bold'>$(txt)</span>")
    set_gtk_property!(l, :xalign, 1.0)   # right-align within its cell
    l
end

age_label    = mklabel("Age (years):")
gender_label = mklabel("Gender:")
height_label = mklabel("Height (cm):")
weight_label = mklabel("Weight (kg):")

mkentry(ph) = begin
    e = GtkEntry()
    set_gtk_property!(e, :width_chars, 20)
    set_gtk_property!(e, :height_request, 40)
    try set_gtk_property!(e, :placeholder_text, ph) catch end
    e
end
age_entry    = mkentry("e.g., 25")
height_entry = mkentry("e.g., 170")
weight_entry = mkentry("e.g., 65")

# --- Gender buttons ---
gender_box = GtkBox(:h)
set_gtk_property!(gender_box, :spacing, 20)
male_btn = GtkRadioButton("Male")
female_btn = GtkRadioButton(male_btn, "Female")
set_gtk_property!(male_btn, :active, true)
push!(gender_box, male_btn)
push!(gender_box, female_btn)
# (no halign enums)

# --- Result label ---
result = GtkLabel("")
set_gtk_property!(result, :use_markup, true)
set_gtk_property!(result, :wrap, true)
# 'justify' expects an enum in some builds; avoid it — center with xalign
set_gtk_property!(result, :xalign, 0.5)

# --- Place widgets ---
grid[1,1] = age_label;    grid[2,1] = age_entry
grid[1,2] = gender_label; grid[2,2] = gender_box
grid[1,3] = height_label; grid[2,3] = height_entry
grid[1,4] = weight_label; grid[2,4] = weight_entry
grid[1:2,5] = result

# --- Size groups for neat alignment ---
lg = Gtk.GtkSizeGroup(:horizontal)
for w in (age_label, gender_label, height_label, weight_label); push!(lg, w); end
ig = Gtk.GtkSizeGroup(:horizontal)
for w in (age_entry, gender_box, height_entry, weight_entry); push!(ig, w); end

# -------------------- Live preview --------------------
function set_result(bmi::Float64)
    idx = bmi_index(bmi)
    cat = LABELS[idx]
    color = COLORS[cat]
    set_gtk_property!(result, :label,
        @sprintf("<span size='22000' weight='bold' foreground='%s'>BMI: %.2f</span>\n<span size='16000'>Category: %s  |  Index: %d</span>",
                 color, bmi, cat, idx))
end

function preview()
    age_txt    = get_gtk_property(age_entry, :text, String)
    h_txt      = get_gtk_property(height_entry, :text, String)
    w_txt      = get_gtk_property(weight_entry, :text, String)
    age    = tryparse(Int, age_txt)
    height = tryparse(Float64, h_txt)
    weight = tryparse(Float64, w_txt)

    if any(x->x===nothing, (age,height,weight))
        set_gtk_property!(result, :label, ""); return
    end
    age, height, weight = age::Int, height::Float64, weight::Float64
    if age<=0 || height<=0 || weight<=0
        set_gtk_property!(result, :label, ""); return
    end
    bmi = weight / (height/100)^2
    set_result(bmi)
end

# --- Parse current inputs and save one row ---
function save_current_row()
    age_txt    = get_gtk_property(age_entry, :text, String)
    h_txt      = get_gtk_property(height_entry, :text, String)
    w_txt      = get_gtk_property(weight_entry, :text, String)

    age    = tryparse(Int, age_txt)
    height = tryparse(Float64, h_txt)
    weight = tryparse(Float64, w_txt)
    if any(x->x===nothing, (age,height,weight)); return; end
    age, height, weight = age::Int, height::Float64, weight::Float64
    if age<=0 || height<=0 || weight<=0; return; end

    bmi = weight / (height/100)^2
    idx = bmi_index(bmi)
    cat = LABELS[idx]
    gender = get_gtk_property(male_btn, :active, Bool) ? "Male" : "Female"

    save_user_data(age, gender, height, weight, bmi, idx, cat)
end

# Update as user types
for e in (age_entry, height_entry, weight_entry)
    signal_connect(e, "key-release-event") do _...; preview(); false end
    signal_connect(e, "activate") do _; preview(); end
end

for e in (age_entry, height_entry, weight_entry)
    signal_connect(e, "key-release-event") do _...; preview(); false end
    signal_connect(e, "activate") do _
        preview()
        save_current_row()
    end
end

# Clear with Escape key
signal_connect(win, "key-press-event") do _, ev
    try
        if get(ev, :keyval) == 65307  # Escape
            for e in (age_entry, height_entry, weight_entry)
                set_gtk_property!(e, :text, "")
            end
            set_gtk_property!(male_btn, :active, true)
            set_gtk_property!(result, :label, "")
        end
    catch; end
    false
end

# --- Save one row to user_data.csv next to this script ---
function save_user_data(age::Int, gender::String, height_cm::Float64, weight_kg::Float64,
                        bmi::Float64, idx::Int, category::String)
    path = joinpath(@__DIR__, "user_data.csv")
    newfile = !isfile(path)
    open(path, "a") do io
        if newfile
            println(io, "timestamp,age,gender,height_cm,weight_kg,bmi,index,category")
        end
        ts = Dates.format(now(), dateformat"yyyy-mm-dd HH:MM:SS")
        @printf(io, "%s,%d,%s,%.2f,%.2f,%.2f,%d,%s\n",
                ts, age, gender, height_cm, weight_kg, bmi, idx, category)
    end
end

# -------------------- Show --------------------
showall(win)
Gtk.GtkMain()
