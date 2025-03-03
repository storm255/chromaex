defmodule ChromaEx.Color.Conversion do
  @moduledoc """
  Provides functions for converting between different color spaces.

  This module handles color space conversions including:
  - RGB <-> Hex
  - RGB <-> Linear RGB
  - RGB <-> LAB
  - RGB <-> LMS (for colorblindness simulation)
  """

  alias ChromaEx.Color

  @doc """
  Converts a hex color string to an RGB Color struct.

  ## Examples

      iex> ChromaEx.Color.Conversion.hex_to_rgb("#FF0000")
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}

      iex> ChromaEx.Color.Conversion.hex_to_rgb("#ff0000")
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}

      iex> ChromaEx.Color.Conversion.hex_to_rgb("FF0000")
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}
  """
  def hex_to_rgb(hex) do
    # Remove leading # if present
    hex = String.replace(hex, ~r/^#/, "")

    # Parse the hex string
    {r, g, b} =
      case String.length(hex) do
        3 ->
          # Short form: #RGB
          [r, g, b] = for c <- String.graphemes(hex), do: String.duplicate(c, 2)

          {
            String.to_integer(r, 16) / 255,
            String.to_integer(g, 16) / 255,
            String.to_integer(b, 16) / 255
          }

        6 ->
          # Long form: #RRGGBB
          <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex

          {
            String.to_integer(r, 16) / 255,
            String.to_integer(g, 16) / 255,
            String.to_integer(b, 16) / 255
          }

        _ ->
          raise ArgumentError, "Invalid hex color format: #{hex}"
      end

    %Color{r: r, g: g, b: b}
  end

  @doc """
  Converts a linear RGB value to sRGB (0-255 range).

  ## Examples

      iex> ChromaEx.Color.Conversion.linear_rgb_to_srgb(0.0)
      0

      iex> ChromaEx.Color.Conversion.linear_rgb_to_srgb(1.0)
      255
  """
  def linear_rgb_to_srgb(v) when v <= 0.0, do: 0
  def linear_rgb_to_srgb(v) when v >= 1.0, do: 255

  def linear_rgb_to_srgb(v) when v < 0.0031308 do
    round(0.5 + v * 12.92 * 255)
  end

  def linear_rgb_to_srgb(v) do
    round(0.5 + 255 * (:math.pow(v, 1.0 / 2.4) * 1.055 - 0.055))
  end

  @doc """
  Converts an sRGB value (0-255) to linear RGB (0.0-1.0 range).

  ## Examples

      iex> ChromaEx.Color.Conversion.srgb_to_linear_rgb(0)
      0.0

      iex> ChromaEx.Color.Conversion.srgb_to_linear_rgb(255)
      1.0
  """
  def srgb_to_linear_rgb(v) do
    fv = v / 255.0

    if fv < 0.04045 do
      fv / 12.92
    else
      :math.pow((fv + 0.055) / 1.055, 2.4)
    end
  end

  @doc """
  Converts a color from RGB to the CIELAB color space.
  """
  def rgb_to_lab(%Color{r: r, g: g, b: b}) do
    # First convert RGB to XYZ
    r = rgb_to_xyz_helper(r)
    g = rgb_to_xyz_helper(g)
    b = rgb_to_xyz_helper(b)

    # D65 standard referent
    x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

    # Then convert XYZ to LAB
    # Reference-X, Y and Z refer to specific illuminants and observers
    # Common reference is D65/2° (daylight, sRGB)
    ref_x = 0.95047
    ref_y = 1.0
    ref_z = 1.08883

    x = x / ref_x
    y = y / ref_y
    z = z / ref_z

    x = xyz_to_lab_helper(x)
    y = xyz_to_lab_helper(y)
    z = xyz_to_lab_helper(z)

    l = 116 * y - 16
    a = 500 * (x - y)
    b = 200 * (y - z)

    {l, a, b}
  end

  defp rgb_to_xyz_helper(r) do
    if r > 0.04045 do
      :math.pow((r + 0.055) / 1.055, 2.4)
    else
      r / 12.92
    end
  end

  defp xyz_to_lab_helper(x) do
    if x > 0.008856 do
      :math.pow(x, 1 / 3)
    else
      7.787 * x + 16 / 116
    end
  end

  @doc """
  Converts RGB values to LMS color space (Long, Medium, Short wavelength cone responses).
  This is used as a step in colorblindness simulation.
  """
  def rgb_to_lms(%Color{r: r, g: g, b: b}) do
    # RGB to LMS matrix
    l = r * 0.31399022 + g * 0.63951294 + b * 0.04649755
    m = r * 0.15537241 + g * 0.75789446 + b * 0.08670142
    s = r * 0.01775239 + g * 0.10944209 + b * 0.87256922

    {l, m, s}
  end

  @doc """
  Converts from LMS back to RGB color space.
  """
  def lms_to_rgb({l, m, s}) do
    # LMS to RGB matrix (inverse of the RGB to LMS matrix)
    r = 5.47221206 * l - 4.6419601 * m + 0.16963708 * s
    g = -1.1252419 * l + 2.29317094 * m - 0.1678952 * s
    b = 0.02980165 * l - 0.19318073 * m + 1.16364789 * s

    # Ensure values are in range
    r = max(0.0, min(1.0, r))
    g = max(0.0, min(1.0, g))
    b = max(0.0, min(1.0, b))

    %Color{r: r, g: g, b: b}
  end
end
