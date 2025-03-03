defmodule ChromaEx.Color.Vision do
  @moduledoc """
  Functions for simulating color vision deficiencies.

  This module implements the Brettel, Viénot, and Mollon (1997) model
  for simulating various types of color blindness.
  """

  alias ChromaEx.Color
  alias ChromaEx.Color.Conversion

  @doc """
  Simulates how a color would appear to someone with a specific color vision deficiency.

  ## Parameters

  - `color`: A Color struct
  - `deficiency_type`: Atom representing the type of color vision deficiency
    - `:protanopia` - absence of red cones (affects ~1% of males)
    - `:deuteranopia` - absence of green cones (affects ~1% of males)
    - `:tritanopia` - absence of blue cones (extremely rare)
    - `:protanomaly` - anomalous red cones (affects ~1% of males)
    - `:deuteranomaly` - anomalous green cones (affects ~5% of males)
    - `:tritanomaly` - anomalous blue cones (extremely rare)
  - `severity`: Float between 0.0 and 1.0, where 1.0 is complete deficiency

  ## Examples

      iex> red = ChromaEx.Color.new("#FF0000")
      iex> protanopia_red = ChromaEx.Color.Vision.simulate(red, :protanopia)
      iex> ChromaEx.Color.to_rgb(protanopia_red)
      {87, 87, 0} # Approximate values, appears dark yellow to those without CVD
  """
  def simulate(%Color{} = color, deficiency_type, severity \\ 1.0) do
    # Extract RGB values
    {r, g, b} = Color.to_rgb(color)

    # Apply the appropriate simulation
    simulated =
      case deficiency_type do
        :normal -> {r, g, b}
        :protanopia -> brettel_simulation(r, g, b, :protan, severity)
        :protanomaly -> brettel_simulation(r, g, b, :protan, severity * 0.6)
        :deuteranopia -> brettel_simulation(r, g, b, :deutan, severity)
        :deuteranomaly -> brettel_simulation(r, g, b, :deutan, severity * 0.6)
        :tritanopia -> brettel_simulation(r, g, b, :tritan, severity)
        :tritanomaly -> brettel_simulation(r, g, b, :tritan, severity * 0.6)
        :achromatopsia -> monochrome_simulation(r, g, b, severity)
        :achromatomaly -> monochrome_simulation(r, g, b, severity * 0.6)
      end

    # Convert back to a Color struct
    {r_sim, g_sim, b_sim} = simulated
    Color.new(r_sim, g_sim, b_sim)
  end

  # Brettel et al. simulation parameters for different types of color vision deficiency
  @brettel_params %{
    protan: %{
      rgb_cvd_from_rgb_1: [
        0.1451,
        1.20165,
        -0.34675,
        0.10447,
        0.85316,
        0.04237,
        0.00429,
        -0.00603,
        1.00174
      ],
      rgb_cvd_from_rgb_2: [
        0.14115,
        1.16782,
        -0.30897,
        0.10495,
        0.8573,
        0.03776,
        0.00431,
        -0.00586,
        1.00155
      ],
      separation_plane_normal: [0.00048, 0.00416, -0.00464]
    },
    deutan: %{
      rgb_cvd_from_rgb_1: [
        0.36198,
        0.86755,
        -0.22953,
        0.26099,
        0.64512,
        0.09389,
        -0.01975,
        0.02686,
        0.99289
      ],
      rgb_cvd_from_rgb_2: [
        0.37009,
        0.8854,
        -0.25549,
        0.25767,
        0.63782,
        0.10451,
        -0.0195,
        0.02741,
        0.99209
      ],
      separation_plane_normal: [-0.00293, -0.00645, 0.00938]
    },
    tritan: %{
      rgb_cvd_from_rgb_1: [
        1.01354,
        0.14268,
        -0.15622,
        -0.01181,
        0.87561,
        0.13619,
        0.07707,
        0.81208,
        0.11085
      ],
      rgb_cvd_from_rgb_2: [
        0.93337,
        0.19999,
        -0.13336,
        0.05809,
        0.82565,
        0.11626,
        -0.37923,
        1.13825,
        0.24098
      ],
      separation_plane_normal: [0.0396, -0.02831, -0.01129]
    }
  }

  # Implementing the Brettel algorithm for color vision deficiency simulation
  defp brettel_simulation(r, g, b, deficiency_type, severity) do
    # Convert sRGB values to linear RGB
    rgb = [
      Conversion.srgb_to_linear_rgb(r),
      Conversion.srgb_to_linear_rgb(g),
      Conversion.srgb_to_linear_rgb(b)
    ]

    # Get the parameters for this type of deficiency
    params = @brettel_params[deficiency_type]
    separation_plane_normal = params.separation_plane_normal

    # Check which transform to use based on the separation plane
    dot_with_sep_plane =
      Enum.at(rgb, 0) * Enum.at(separation_plane_normal, 0) +
        Enum.at(rgb, 1) * Enum.at(separation_plane_normal, 1) +
        Enum.at(rgb, 2) * Enum.at(separation_plane_normal, 2)

    rgb_cvd_from_rgb =
      if dot_with_sep_plane >= 0 do
        params.rgb_cvd_from_rgb_1
      else
        params.rgb_cvd_from_rgb_2
      end

    # Apply the transform to get the simulated color
    rgb_cvd = [
      Enum.at(rgb_cvd_from_rgb, 0) * Enum.at(rgb, 0) +
        Enum.at(rgb_cvd_from_rgb, 1) * Enum.at(rgb, 1) +
        Enum.at(rgb_cvd_from_rgb, 2) * Enum.at(rgb, 2),
      Enum.at(rgb_cvd_from_rgb, 3) * Enum.at(rgb, 0) +
        Enum.at(rgb_cvd_from_rgb, 4) * Enum.at(rgb, 1) +
        Enum.at(rgb_cvd_from_rgb, 5) * Enum.at(rgb, 2),
      Enum.at(rgb_cvd_from_rgb, 6) * Enum.at(rgb, 0) +
        Enum.at(rgb_cvd_from_rgb, 7) * Enum.at(rgb, 1) +
        Enum.at(rgb_cvd_from_rgb, 8) * Enum.at(rgb, 2)
    ]

    # Apply severity factor (linear interpolation)
    rgb_cvd = [
      Enum.at(rgb_cvd, 0) * severity + Enum.at(rgb, 0) * (1.0 - severity),
      Enum.at(rgb_cvd, 1) * severity + Enum.at(rgb, 1) * (1.0 - severity),
      Enum.at(rgb_cvd, 2) * severity + Enum.at(rgb, 2) * (1.0 - severity)
    ]

    # Convert back to sRGB for display
    {
      Conversion.linear_rgb_to_srgb(Enum.at(rgb_cvd, 0)),
      Conversion.linear_rgb_to_srgb(Enum.at(rgb_cvd, 1)),
      Conversion.linear_rgb_to_srgb(Enum.at(rgb_cvd, 2))
    }
  end

  # Monochrome simulation (grayscale)
  defp monochrome_simulation(r, g, b, severity) do
    # Calculate grayscale value using standard luminance formula
    z = round(r * 0.299 + g * 0.587 + b * 0.114)

    # Apply severity
    r_new = round(z * severity + (1.0 - severity) * r)
    g_new = round(z * severity + (1.0 - severity) * g)
    b_new = round(z * severity + (1.0 - severity) * b)

    {r_new, g_new, b_new}
  end
end
