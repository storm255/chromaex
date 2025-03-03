defmodule ChromaEx do
  @moduledoc """
  ChromaEx is an Elixir library for color manipulation and palette optimization.

  This library implements a simulated annealing algorithm to generate
  accessible color palettes that work for users with various forms of color blindness,
  based on the "How to pick the least wrong colors" methodology.

  ## Features

  - Color manipulation and conversion between different color spaces
  - Color distance calculations using CIEDE2000 algorithm
  - Color vision deficiency simulation (protanopia, deuteranopia, tritanopia, etc.)
  - Simulated annealing for generating optimized color palettes

  ## Example Usage

  ```elixir
  # Generate a palette of 5 colors
  colors = ChromaEx.generate_palette(5)

  # Generate a palette close to specific brand colors
  target_colors = [
    "#4269d0",
    "#efb118",
    "#ff725c"
  ]

  colors = ChromaEx.generate_palette(5, target_colors: target_colors)

  # Get color palette as hex codes
  hex_colors = Enum.map(colors, &ChromaEx.to_hex/1)
  ```
  """

  alias ChromaEx.Color
  alias ChromaEx.Color.Distance
  alias ChromaEx.Color.Vision
  alias ChromaEx.Annealing.Optimizer

  # Re-export key functions from the Color module for convenience

  @doc """
  Creates a new color from various inputs.

  ## Examples

      iex> ChromaEx.new("#FF0000")
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}

      iex> ChromaEx.new(255, 0, 0)
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}
  """
  defdelegate new(input), to: Color
  defdelegate new(r, g, b), to: Color

  @doc """
  Creates a random color.

  ## Examples

      iex> ChromaEx.random()
      %ChromaEx.Color{r: 0.2, g: 0.5, b: 0.9, alpha: 1.0} # Random values
  """
  defdelegate random(), to: Color

  @doc """
  Converts a color to a hex string.

  ## Examples

      iex> color = ChromaEx.new(255, 0, 0)
      iex> ChromaEx.to_hex(color)
      "#ff0000"
  """
  defdelegate to_hex(color), to: Color

  @doc """
  Converts a color to RGB values (0-255).

  ## Examples

      iex> color = ChromaEx.new("#FF0000")
      iex> ChromaEx.to_rgb(color)
      {255, 0, 0}
  """
  defdelegate to_rgb(color), to: Color

  @doc """
  Calculates the perceptual distance between two colors using CIEDE2000.

  ## Examples

      iex> color1 = ChromaEx.new("#FF0000")
      iex> color2 = ChromaEx.new("#FF0001")
      iex> ChromaEx.distance(color1, color2) < 1.0
      true
  """
  defdelegate distance(color1, color2), to: Distance, as: :delta_e

  @doc """
  Calculates the contrast ratio between two colors.

  ## Examples

      iex> white = ChromaEx.new("#FFFFFF")
      iex> black = ChromaEx.new("#000000")
      iex> ChromaEx.contrast_ratio(white, black)
      21.0
  """
  defdelegate contrast_ratio(color1, color2), to: Distance

  @doc """
  Simulates how a color would appear to someone with a specific color vision deficiency.

  ## Examples

      iex> red = ChromaEx.new("#FF0000")
      iex> deuteranopia_red = ChromaEx.simulate_cvd(red, :deuteranopia)
      iex> ChromaEx.to_hex(deuteranopia_red)
      "#97618b" # Example output, actual value may vary
  """
  defdelegate simulate_cvd(color, deficiency_type, severity \\ 1.0), to: Vision, as: :simulate

  @doc """
  Generates an optimized color palette.

  ## Parameters

  - `count`: Number of colors to generate
  - `opts`: Keyword list of options
    - `:target_colors`: Optional list of target colors to stay close to
    - `:avoid_colors`: Optional list of colors to avoid
    - `:fixed_colors`: Optional list of colors that should not be modified
    - `:background_color`: Background color for contrast calculation
    - Other options are passed to the optimizer

  ## Examples

      iex> colors = ChromaEx.generate_palette(5)
      iex> length(colors)
      5

      iex> target = [ChromaEx.new("#FF0000"), ChromaEx.new("#00FF00")]
      iex> colors = ChromaEx.generate_palette(5, target_colors: target)
      iex> length(colors)
      5
  """
  def generate_palette(count, opts \\ []) do
    # Process options
    target_colors = parse_color_list(Keyword.get(opts, :target_colors, []))
    avoid_colors = parse_color_list(Keyword.get(opts, :avoid_colors, []))
    fixed_colors = parse_color_list(Keyword.get(opts, :fixed_colors, []))

    background_color =
      case Keyword.get(opts, :background_color) do
        nil -> Color.new("#FFFFFF")
        color when is_binary(color) -> Color.new(color)
        color -> color
      end

    # Generate the palette
    optimizer_opts =
      [
        target_colors: target_colors,
        avoid_colors: avoid_colors,
        fixed_colors: fixed_colors,
        background_color: background_color
      ] ++ Keyword.drop(opts, [:target_colors, :avoid_colors, :fixed_colors, :background_color])

    Optimizer.optimize(count, optimizer_opts)
  end

  # Helper function to parse a list of colors in different formats
  defp parse_color_list(colors) do
    Enum.map(colors, fn
      color when is_binary(color) -> Color.new(color)
      color -> color
    end)
  end
end
