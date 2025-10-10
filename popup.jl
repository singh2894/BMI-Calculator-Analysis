using Gtk

# Function to prompt user input (robust across Gtk.jl versions)
function get_input(prompt::String)
    dialog = GtkDialog(prompt, "OK" => 1)
    entry = GtkEntry()
    # Attach entry to content area using property getter
    content = nothing
    try
        content = get_gtk_property(dialog, :content_area, GtkWidget)
    catch
    end
    if content !== nothing
        push!(content, entry)
    else
        box = GtkBox(:v)
        push!(box, entry)
        push!(dialog, box)
    end
    showall(dialog)
    _ = run(dialog)
    txt = try
        get_gtk_property(entry, :text, String)
    catch
        # Older Gtk.jl may expose Gtk.text
        try
            Gtk.text(entry)
        catch
            ""
        end
    end
    destroy(dialog)
    return strip(txt)
end

# Prompt for inputs
age_str = get_input("Enter your age:")
height_str = get_input("Enter your height in meters (e.g., 1.75):")
weight_str = get_input("Enter your weight in kg (e.g., 70):")

# Convert to numeric
age = parse(Int, age_str)
height = parse(Float64, height_str)
weight = parse(Float64, weight_str)


