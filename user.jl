using Gtk
using Printf
using Dates

# Minimal GTK-based BMI calculator (no graphs, no analysis)

function bmi_index(bmi::Float64)
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

function bmi_category(bmi::Float64)
    if bmi < 18.5
        return "Underweight"
    elseif bmi < 25
        return "Normal"
    elseif bmi < 30
        return "Overweight"
    elseif bmi < 35
        return "Obese Class I"
    else
        return "Obese Class II+"
    end
end

function save_user_data(age::Int, gender::String, height_cm::Float64, weight_kg::Float64, bmi::Float64, idx::Int, category::String)
    path = joinpath(@__DIR__, "user_data.csv")
    newfile = !isfile(path)
    open(path, "a") do io
        if newfile
            println(io, "timestamp,age,gender,height_cm,weight_kg,bmi,index,category")
        end
        ts = Dates.format(now(), dateformat"yyyy-mm-dd HH:MM:SS")
        @printf(io, "%s,%d,%s,%.2f,%.2f,%.2f,%d,%s\n", ts, age, gender, height_cm, weight_kg, bmi, idx, category)
    end
end

# --- Build UI ---
win = GtkWindow("BMI Calculator", 820, 600)
grid = GtkGrid()
set_gtk_property!(grid, :column_spacing, 12)
set_gtk_property!(grid, :row_spacing, 10)
push!(win, grid)

age_label = GtkLabel("Age (years):")
gender_label = GtkLabel("Gender:")
height_label = GtkLabel("Height (cm):")
weight_label = GtkLabel("Weight (kg):")
for lbl in (age_label, gender_label, height_label, weight_label)
    set_gtk_property!(lbl, :halign, GtkAlign.END)
end

age_entry = GtkEntry()
height_entry = GtkEntry()
weight_entry = GtkEntry()
for (e, ph) in zip((age_entry, height_entry, weight_entry), ("e.g., 25", "e.g., 170", "e.g., 65"))
    try
        set_gtk_property!(e, :placeholder_text, ph)
    catch
    end
    set_gtk_property!(e, :width_chars, 16)
end

gender_box = GtkBox(:h)
set_gtk_property!(gender_box, :spacing, 10)
male_btn = GtkRadioButton("Male")
female_btn = GtkRadioButton(male_btn, "Female")
set_gtk_property!(male_btn, :active, true)
push!(gender_box, male_btn)
push!(gender_box, female_btn)

submit_btn = GtkButton("Submit")
result_label = GtkLabel("")
set_gtk_property!(result_label, :wrap, true)
set_gtk_property!(result_label, :justify, GtkJustification.CENTER)
set_gtk_property!(result_label, :halign, GtkAlign.CENTER)

grid[1, 1] = age_label
grid[2, 1] = age_entry
grid[1, 2] = gender_label
grid[2, 2] = gender_box
grid[1, 3] = height_label
grid[2, 3] = height_entry
grid[1, 4] = weight_label
grid[2, 4] = weight_entry
grid[1:2, 5] = submit_btn
grid[1:2, 6] = result_label

function show_error(msg::String)
    try
        dlg = MessageDialog(win, MessageType.ERROR, ButtonsType.CLOSE, msg)
        showall(dlg); run(dlg); destroy(dlg); return
    catch
        dlg = GtkDialog()
        set_gtk_property!(dlg, :title, "Error")
        content = GtkBox(:v)
        lbl = GtkLabel(msg)
        btn = GtkButton("Close")
        signal_connect(btn, "clicked") do _
            destroy(dlg)
        end
        push!(content, lbl)
        push!(content, btn)
        push!(dlg, content)
        showall(dlg); run(dlg); destroy(dlg)
    end
end

function on_submit(_)
    try
        age = parse(Int, get_gtk_property(age_entry, :text, String))
        height = parse(Float64, get_gtk_property(height_entry, :text, String))
        weight = parse(Float64, get_gtk_property(weight_entry, :text, String))
        gender = get_gtk_property(male_btn, :active, Bool) ? "Male" : "Female"

        if age <= 0 || height <= 0 || weight <= 0
            show_error("Values must be positive numbers.")
            return
        end

        bmi = weight / (height / 100)^2
        idx = bmi_index(bmi)
        cat = bmi_category(bmi)

        set_gtk_property!(result_label, :label,
            @sprintf("BMI: %.2f  |  Category: %s  |  Index: %d", bmi, cat, idx))

        save_user_data(age, gender, height, weight, bmi, idx, cat)
    catch
        show_error("Invalid input. Please enter valid numeric values.")
    end
end

signal_connect(on_submit, submit_btn, "clicked")

showall(win)
Gtk.gtk_main()

