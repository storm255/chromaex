# Example script to recreate the functionality of the original JavaScript library
# Run with: mix run examples/recreate_original.exs

# Import target colors from the original JavaScript library
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

# Colors to avoid
avoid_colors = ["#FF0000", "#000000"]

# Background color
background_color = "#ffffff"

# Number of fixed colors (from the original script)
fixed_colors_count = 0

# Set up the weight configuration to match the original JavaScript
weights = %{
  energy: 1.25,         # How differentiable the colors are
  range: 1.0,           # How uniformly spread the colors are
  target: 0.75,         # How close to target colors
  avoid: 0.5,           # How far from colors to avoid
  contrast: 0.25,       # How good is contrast with background

  # Color vision deficiency weights
  protanopia: 0.1,
  protanomaly: 0.1,
  deuteranopia: 0.1,
  deuteranomaly: 0.5,
  tritanopia: 0.05,
  tritanomaly: 0.05
}

# Start with random colors
initial_colors = Enum.map(1..10, fn _ -> ChromaEx.random() end)

# Print initial state
hex_initial = Enum.map(initial_colors, &ChromaEx.to_hex/1)
IO.puts("Starting with colors: #{Enum.join(hex_initial, ", ")}")

# Perform the optimization
IO.puts("\nRunning simulated annealing optimization...")
optimized_colors = ChromaEx.generate_palette(
  length(initial_colors),
  initial_colors: initial_colors,
  fixed_colors: Enum.take(initial_colors, fixed_colors_count),
  target_colors: target_colors,
  avoid_colors: avoid_colors,
  background_color: background_color,
  weights: weights,
  temperature: 1000.0,
  cooling_rate: 0.99,
  cutoff: 0.0001,
  debug: true
)

# Print results
hex_optimized = Enum.map(optimized_colors, &ChromaEx.to_hex/1)
IO.puts("\nOptimized colors: #{Enum.join(hex_optimized, ", ")}")

# Calculate color blindness simulations for the palette
IO.puts("\nSimulating color blindness for the optimized palette:")

defmodencies = [
  {:protanopia, "Protanopia (red-blind)"},
  {:deuteranopia, "Deuteranopia (green-blind)"},
  {:tritanopia, "Tritanopia (blue-blind)"}
]

# Create a function to simulate and print a palette for a specific deficiency
simulate_palette = fn palette, {deficiency, name} ->
  simulated = Enum.map(palette, &ChromaEx.simulate_cvd(&1, deficiency))
  hex_simulated = Enum.map(simulated, &ChromaEx.to_hex/1)
  IO.puts("#{name}: #{Enum.join(hex_simulated, ", ")}")
  {deficiency, simulated}
end

# Simulate for each type of color vision deficiency
simulated_palettes = Enum.map(defmodencies, &simulate_palette.(optimized_colors, &1))

# Generate HTML visualization
IO.puts("\nGenerating HTML visualization...")

html = """
<!DOCTYPE html>
<html>
<head>
  <title>ChromaEx Color Palette Optimization</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 1000px; margin: 0 auto; padding: 20px; }
    h1, h2 { margin-top: 30px; }
    .palette { display: flex; flex-wrap: wrap; margin: 20px 0; }
    .color { width: 80px; height: 80px; margin: 0 10px 10px 0; display: flex; align-items: center; justify-content: center; color: #fff; text-shadow: 0 0 2px rgba(0,0,0,0.5); font-size: 12px; border-radius: 4px; }
    .dark { color: #000; text-shadow: 0 0 2px rgba(255,255,255,0.5); }
    .sample { padding: 15px; margin-bottom: 20px; border-radius: 8px; }
    .code { font-family: monospace; background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { text-align: left; padding: 8px; border-bottom: 1px solid #ddd; }
    th { background-color: #f5f5f5; }
  </style>
</head>
<body>
  <h1>ChromaEx Color Palette Optimization</h1>

  <h2>Initial Random Colors</h2>
  <div class="palette">
    #{Enum.map(initial_colors, fn color ->
      hex = ChromaEx.to_hex(color)
      "<div class='color' style='background-color: #{hex}'>#{hex}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>Target Colors</h2>
  <div class="palette">
    #{Enum.map(target_colors, fn hex ->
      "<div class='color' style='background-color: #{hex}'>#{hex}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>Optimized Palette</h2>
  <div class="palette">
    #{Enum.map(optimized_colors, fn color ->
      hex = ChromaEx.to_hex(color)
      "<div class='color' style='background-color: #{hex}'>#{hex}</div>"
    end) |> Enum.join("")}
  </div>

  <h2>Color Blindness Simulations</h2>

    #{Enum.map(simulated_palettes, fn {deficiency, simulated} ->
      """
      <h3>#{Atom.to_string(deficiency) |> String.capitalize()}</h3>
      <div class="palette">
        #{Enum.map(simulated, fn color ->
          hex = ChromaEx.to_hex(color)
          "<div class='color' style='background-color: #{hex}'>#{hex}</div>"
        end) |> Enum.join("")}
      </div>
      """
    end) |> Enum.join("")}

  <h2>Usage Examples</h2>

  <h3>Data Visualization Examples</h3>

  <div class="sample" style="background-color: #f8f9fa;">
    <h4>Bar Chart</h4>
    <svg width="800" height="300" viewBox="0 0 800 300">
      <rect x="50" y="50" width="80" height="200" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 0))}" />
      <rect x="150" y="80" width="80" height="170" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 1))}" />
      <rect x="250" y="110" width="80" height="140" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 2))}" />
      <rect x="350" y="140" width="80" height="110" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 3))}" />
      <rect x="450" y="170" width="80" height="80" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 4))}" />
      <rect x="550" y="70" width="80" height="180" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 5))}" />
      <rect x="650" y="100" width="80" height="150" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 6))}" />
    </svg>
  </div>

  <div class="sample" style="background-color: #f8f9fa;">
    <h4>Pie Chart</h4>
    <svg width="400" height="400" viewBox="0 0 400 400">
      <g transform="translate(200, 200)">
        <!-- Simple pie chart segments -->
        <path d="M0,0 L200,0 A200,200 0 0,1 141,141 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 0))}" />
        <path d="M0,0 L141,141 A200,200 0 0,1 0,200 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 1))}" />
        <path d="M0,0 L0,200 A200,200 0 0,1 -141,141 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 2))}" />
        <path d="M0,0 L-141,141 A200,200 0 0,1 -200,0 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 3))}" />
        <path d="M0,0 L-200,0 A200,200 0 0,1 -141,-141 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 4))}" />
        <path d="M0,0 L-141,-141 A200,200 0 0,1 0,-200 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 5))}" />
        <path d="M0,0 L0,-200 A200,200 0 0,1 200,0 Z" fill="#{ChromaEx.to_hex(Enum.at(optimized_colors, 6))}" />
      </g>
    </svg>
  </div>

  <h2>Elixir Code Example</h2>

  <div class="code">
    <pre>
# Generate an optimized 10-color palette
colors = ChromaEx.generate_palette(10,
  target_colors: [
    "#4269d0", "#efb118", "#ff725c", "#6cc5b0", "#3ca951"
  ],
  weights: %{
    energy: 1.25,
    range: 1.0,
    target: 0.75,
    deuteranomaly: 0.5
  }
)

# Convert to hex codes for use in your application
hex_colors = Enum.map(colors, &ChromaEx.to_hex/1)
    </pre>
  </div>

</body>
</html>
"""

# Save the HTML to a file
File.write!("optimized_palette_visualization.html", html)
IO.puts("Generated HTML visualization at optimized_palette_visualization.html")
