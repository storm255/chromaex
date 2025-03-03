# ChromaEx

ChromaEx is an Elixir library for color manipulation and optimization, based on the "How to pick the least wrong colors" methodology. It implements a simulated annealing algorithm to generate accessible color palettes that work for users with various forms of color blindness.

## Features

- Color manipulation and conversion between different color spaces
- Color distance calculations using CIEDE2000 algorithm
- Color vision deficiency simulation (protanopia, deuteranopia, tritanopia, etc.)
- Simulated annealing for generating optimized color palettes

## Installation

Add `chromaex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chromaex, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Color Operations

```elixir
# Create colors from various formats
red = ChromaEx.new("#FF0000")
green = ChromaEx.new(0, 255, 0)
blue = ChromaEx.new({0.0, 0.0, 1.0})

# Get color values
ChromaEx.to_hex(red)    # => "#ff0000"
ChromaEx.to_rgb(green)  # => {0, 255, 0}

# Calculate color distance (perceptual difference)
distance = ChromaEx.distance(red, blue) # => 76.98 (approximate)

# Calculate contrast ratio
contrast = ChromaEx.contrast_ratio(red, blue) # => 2.14 (approximate)

# Simulate color vision deficiency
deuteranopia_red = ChromaEx.simulate_cvd(red, :deuteranopia)
ChromaEx.to_hex(deuteranopia_red) # => "#a57e02" (approximate)
```

### Generating Color Palettes

```elixir
# Generate a basic palette of 5 colors
colors = ChromaEx.generate_palette(5)
hex_colors = Enum.map(colors, &ChromaEx.to_hex/1)
# => ["#1a52f0", "#e82c7a", "#2dd159", "#ffc130", "#9a55eb"] (example)

# Generate a palette with specific weights for different factors
colors = ChromaEx.generate_palette(5,
  weights: %{
    energy: 1.5,       # Emphasize differentiability
    deuteranomaly: 0.8 # Emphasize deuteranomaly accessibility
  }
)

# Generate a palette close to specific brand colors
target_colors = [
  "#4269d0", # Bluish
  "#efb118", # Yellow
  "#ff725c"  # Reddish
]

colors = ChromaEx.generate_palette(7,
  target_colors: target_colors,
  temperature: 2000.0, # Higher starting temperature for more exploration
  cooling_rate: 0.995  # Slower cooling for more thorough optimization
)

# Generate a palette with some fixed colors
fixed_colors = [
  ChromaEx.new("#4269d0"), # Primary brand color
  ChromaEx.new("#efb118")  # Secondary brand color
]

colors = ChromaEx.generate_palette(8,
  fixed_colors: fixed_colors,
  background_color: "#f5f5f5" # Light gray background
)

# Avoid specific colors
avoid_colors = ["#FF0000", "#00FF00", "#0000FF"] # Avoid pure RGB

colors = ChromaEx.generate_palette(6,
  avoid_colors: avoid_colors,
  debug: true # Print debug information during optimization
)
```

### Advanced Usage

For more advanced use cases, you can directly use the modules:

```elixir
alias ChromaEx.Color
alias ChromaEx.Color.Distance
alias ChromaEx.Color.Vision
alias ChromaEx.Annealing.Optimizer
alias ChromaEx.Annealing.Evaluation

# Calculate the cost of a palette
colors = [
  Color.new("#FF0000"),
  Color.new("#00FF00"),
  Color.new("#0000FF")
]

# Evaluate how good this palette is (lower score is better)
score = Evaluation.cost(colors,
  weights: %{
    energy: 1.0,
    protanopia: 0.5,
    deuteranopia: 0.5
  }
)

# Calculate all pairwise distances
distances = Evaluation.calculate_all_distances(colors)
avg_distance = Enum.sum(distances) / length(distances)

# Calculate all pairwise distances for users with protanopia
distances_protanopia = Evaluation.calculate_all_distances(colors, :protanopia)
```

## How It Works

ChromaEx uses simulated annealing to optimize color palettes according to multiple criteria:

1. **Energy**: How differentiable the colors are from each other
2. **Range**: How uniformly spread the colors are in perceptual space
3. **Target**: How close the colors are to desired target colors
4. **Avoid**: How far the colors are from colors to avoid
5. **Contrast**: How good the contrast is with the background
6. **Accessibility**: How differentiable the colors are for people with various color vision deficiencies

The algorithm starts with a random or provided set of colors and gradually refines them through thousands of iterations, balancing these criteria according to configurable weights.

## Resources

For more information on the theory behind this library:

- [How to pick the least wrong colors](https://matthewstrom.com/writing/how-to-pick-the-least-wrong-colors/) by Matthew Ström
- [The CIEDE2000 Color-Difference Formula](http://www2.ece.rochester.edu/~gsharma/ciede2000/ciede2000noteCRNA.pdf) by Sharma, Wu and Dalal
- [Computerized simulation of color appearance for dichromats](http://vision.psychol.cam.ac.uk/jdmollon/papers/Dichromatsimulation.pdf) by Brettel, Viénot and Mollon

## License

ChromaEx is released under the MIT License.
