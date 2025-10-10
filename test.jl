using CSV
using DataFrames
using Gtk


file_path = ("C:\\Users\\Simran\\OneDrive\\Desktop\\BMI Calculator Analysis\\BMI-Calculator-Analysis\\clean_dataset.csv", DataFrame)
df = CSV.read(file_path, DataFrame)

using Pkg
Pkg.rm("Gtk"; force=true); Pkg.gc()

# If you’re behind a corporate proxy or downloads fail, try:
ENV["JULIA_PKG_SERVER"] = ""      # force direct GitHub downloads
# (Optional) set your proxies if you have them:
# ENV["HTTP_PROXY"]="http://user:pass@host:port"
# ENV["HTTPS_PROXY"]="http://user:pass@host:port"

Pkg.add("Gtk")
Pkg.build("Gtk")

@info Gtk.version()
w = GtkWindow("GTK OK", 300, 120); show(w)


