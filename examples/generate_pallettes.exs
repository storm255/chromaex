# Example script to generate and compare color palettes
# Run with: mix run examples/generate_palettes.exs

# Target colors from the original JavaScript library
target_colors = [
  "#4269d0",
  "#efb118",
  "#ff725c",
  "#6cc5b0",
  "#3ca951",
  "#ff8ab7",
  "#a463f2",
  "#97bbf5",
  "#9c6b4e",
  "#9498a0"
]

# Background color (white)
background_color = "#ffffff"

# Colors to avoid
avoid_colors = ["#FF0000", "#000000"]

IO.puts("Generating a palette of 5 colors...")

# Generate a 5-color palette with default settings
colors_default = ChromaEx.generate_palette(5, debug: true)
hex_colors_default = Enum.map(colors_default, &ChromaEx.to_hex/1)

IO.puts("\nDefault 5-color palette:")
IO.puts(Enum.join(hex_colors_default, ", "))

# Generate a 5-color palette with target colors
IO.puts("\nGenerating a palette of 5 colors with target colors...")
colors_with_target = ChromaEx.generate_palette(5,
  target_colors: target_colors,
  background_color: background_color,
  debug: true
)
hex_colors_with_target = Enum.map(colors_with_target, &ChromaEx.to_hex/1)

IO.puts("\n5-color palette with target colors:")
IO.puts(Enum.join(hex_colors_with_target, ", "))

# Generate a 10-color accessible palette
IO.puts("\nGenerating a 10-color colorblind-friendly palette...")
accessible_palette = ChromaEx.generate_palette(10,
  avoid_colors: avoid_colors,
  background_color: background_color,
  weights: %{
    energy: 1.0,         # Standard weight for differentiation
    protanopia: 0.3,     # Increase weight for protanopia
    deuteranopia: 0.3,   # Increase weight for deuteranopia
    tritanopia: 0.2,     # Slightly increase weight for tritanopia
    contrast: 0.5        # Increase weight for contrast with background
  },
  temperature: 2000.0,   # Higher temperature for more exploration
  cooling_rate: 0.993,   # Slower cooling for more thorough search
  debug: true
)
hex_colors_accessible = Enum.map(accessible_palette, &ChromaEx.to_hex/1)

IO.puts("\n10-color accessible palette:")
IO.puts(Enum.join(hex_colors_accessible, ", "))

# Generate HTML to visualize the palettes
html = """
<!DOCTYPE html>
<html>
<head>
  <title>ChromaEx Generated Color Palettes</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
    h1 { margin-top: 40px; }
    .palette { display: flex; margin: 20px 0; }
    .color { width: 80px; height: 80px; margin-right: 10px; border-radius: 5px; display: flex; align-items: center; justify-content: center; color: #fff; text-shadow: 0 0 2px rgba(0,0,0,0.7); box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    .dark-text { color: #000; text-shadow: 0 0 2px rgba(255,255,255,0.7); }
  </style>
</head>
<body>
  <h1>ChromaEx Generated Color Palettes</h1>

  <h2>Default 5-color palette</h2>
  <div class="palette">
    #{Enum.map(hex_colors_default, fn color ->
      "<div class='color' style='background-color: #{color}'>#{color}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>5-color palette with target colors</h2>
  <div class="palette">
    #{Enum.map(hex_colors_with_target, fn color ->
      "<div class='color' style='background-color: #{color}'>#{color}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>10-color accessible palette</h2>
  <div class="palette">
    #{Enum.map(hex_colors_accessible, fn color ->
      "<div class='color' style='background-color: #{color}'>#{color}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>Original target colors</h2>
  <div class="palette">
    #{Enum.map(target_colors, fn color ->
      "<div class='color' style='background-color: #{color}'>#{color}</div>"
    end) |> Enum.join("")}
  </div>
</body>
</html>
"""

# Save the HTML to a file
File.write!("palette_visualization.html", html)
IO.puts("\nGenerated HTML visualization at palette_visualization.html")
