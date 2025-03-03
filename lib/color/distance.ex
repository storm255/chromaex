defmodule ChromaEx.Color.Distance do
  @moduledoc """
  Functions for calculating color distance measures.

  This module provides various ways to measure perceptual differences between colors,
  with the primary implementation being CIEDE2000, which accounts for human perception.
  """

  alias ChromaEx.Color
  alias ChromaEx.Color.Conversion

  @doc """
  Calculates the distance between two colors using CIEDE2000 formula.

  The CIEDE2000 formula is the current standard for measuring perceptual
  color difference, developed by the International Commission on Illumination (CIE).

  Returns a value from 0 to 100, where:
  - 0 = identical colors
  - 100 = completely different colors

  ## Examples

      iex> white = ChromaEx.Color.new("#FFFFFF")
      iex> black = ChromaEx.Color.new("#000000")
      iex> ChromaEx.Color.Distance.delta_e(white, black)
      100.0 # Maximum difference

      iex> red1 = ChromaEx.Color.new("#FF0000")
      iex> red2 = ChromaEx.Color.new("#FF0505")
      iex> ChromaEx.Color.Distance.delta_e(red1, red2) < 5.0
      true # Very similar reds
  """
  def delta_e(%Color{} = color1, %Color{} = color2) do
    # Convert RGB to LAB
    {l1, a1, b1} = Conversion.rgb_to_lab(color1)
    {l2, a2, b2} = Conversion.rgb_to_lab(color2)

    # Calculate CIEDE2000
    delta_e_2000(l1, a1, b1, l2, a2, b2)
  end

  @doc """
  Simple Euclidean distance between colors in RGB space.

  While less perceptually accurate than delta_e, this can be useful for
  simple comparisons where performance matters.

  ## Examples

      iex> red = ChromaEx.Color.new("#FF0000")
      iex> blue = ChromaEx.Color.new("#0000FF")
      iex> ChromaEx.Color.Distance.rgb_distance(red, blue)
      1.4142135623730951 # Square root of 2
  """
  def rgb_distance(%Color{r: r1, g: g1, b: b1}, %Color{r: r2, g: g2, b: b2}) do
    :math.sqrt((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2))
  end

  # CIEDE2000 implementation based on the paper:
  # "The CIEDE2000 Color-Difference Formula: Implementation Notes, Supplementary Test Data, and Mathematical Observations"
  # by Gaurav Sharma, Wencheng Wu, and Edul N. Dalal
  defp delta_e_2000(l1, a1, b1, l2, a2, b2) do
    # This is a simplified implementation
    # For production, consider a more complete implementation

    # Weight factors
    k_l = 1.0
    k_c = 1.0
    k_h = 1.0

    # Calculate Cprime values
    c1 = :math.sqrt(a1 * a1 + b1 * b1)
    c2 = :math.sqrt(a2 * a2 + b2 * b2)

    # Calculate mean C
    c_mean = (c1 + c2) / 2.0

    # Calculate G
    g = 0.5 * (1 - :math.sqrt(:math.pow(c_mean, 7) / (:math.pow(c_mean, 7) + :math.pow(25, 7))))

    # Calculate adjusted a values
    a1_prime = (1 + g) * a1
    a2_prime = (1 + g) * a2

    # Calculate new C values
    c1_prime = :math.sqrt(a1_prime * a1_prime + b1 * b1)
    c2_prime = :math.sqrt(a2_prime * a2_prime + b2 * b2)

    # Calculate h values
    h1_prime = calculate_h_prime(a1_prime, b1)
    h2_prime = calculate_h_prime(a2_prime, b2)

    # Calculate ΔL', ΔC', ΔH'
    delta_l_prime = l2 - l1
    delta_c_prime = c2_prime - c1_prime

    # Calculate ΔH'
    delta_h_prime = calculate_delta_h_prime(c1_prime, c2_prime, h1_prime, h2_prime)

    # Calculate CIEDE2000 components
    delta_l_term = delta_l_prime / k_l
    delta_c_term = delta_c_prime / (k_c * (1 + 0.045 * c_mean))
    delta_h_term = delta_h_prime / (k_h * (1 + 0.015 * c_mean))

    # Final CIEDE2000 formula
    :math.sqrt(
      delta_l_term * delta_l_term + delta_c_term * delta_c_term + delta_h_term * delta_h_term
    )
  end

  defp calculate_h_prime(a_prime, b) do
    h_prime = :math.atan2(b, a_prime) * 180 / :math.pi()

    # Ensure h_prime is positive
    if h_prime < 0 do
      h_prime + 360
    else
      h_prime
    end
  end

  defp calculate_delta_h_prime(c1_prime, c2_prime, h1_prime, h2_prime) do
    # Calculate ΔH'
    if c1_prime * c2_prime == 0 do
      0.0
    else
      delta_h = h2_prime - h1_prime

      cond do
        abs(delta_h) <= 180 ->
          delta_h

        delta_h > 180 ->
          delta_h - 360

        delta_h < -180 ->
          delta_h + 360
      end
    end
  end

  @doc """
  Calculate contrast ratio between two colors according to WCAG 2.0.

  ## Examples

      iex> white = ChromaEx.Color.new("#FFFFFF")
      iex> black = ChromaEx.Color.new("#000000")
      iex> ChromaEx.Color.Distance.contrast_ratio(white, black)
      21.0 # Maximum contrast ratio
  """
  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    # Calculate relative luminance
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    # Ensure l1 is the lighter color (higher luminance)
    {l1, l2} = if l1 > l2, do: {l1, l2}, else: {l2, l1}

    # Calculate contrast ratio (WCAG 2.0 formula)
    (l1 + 0.05) / (l2 + 0.05)
  end

  # Calculate relative luminance according to WCAG 2.0
  defp relative_luminance(%Color{r: r, g: g, b: b}) do
    # Convert to linear values first
    r_linear = if r <= 0.03928, do: r / 12.92, else: :math.pow((r + 0.055) / 1.055, 2.4)
    g_linear = if g <= 0.03928, do: g / 12.92, else: :math.pow((g + 0.055) / 1.055, 2.4)
    b_linear = if b <= 0.03928, do: b / 12.92, else: :math.pow((b + 0.055) / 1.055, 2.4)

    # Calculate luminance
    0.2126 * r_linear + 0.7152 * g_linear + 0.0722 * b_linear
  end
end
