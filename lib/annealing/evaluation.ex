defmodule ChromaEx.Annealing.Evaluation do
  @moduledoc """
  Functions for evaluating color palettes as part of the simulated annealing process.

  This module provides the cost/loss functions used to score how "good" a color
  palette is according to various criteria.
  """

  alias ChromaEx.Color
  alias ChromaEx.Color.Distance
  alias ChromaEx.Color.Vision

  @doc """
  Calculate the cost of a color palette based on multiple weighted factors.

  Returns a numeric score where lower values indicate a better palette.

  ## Parameters

  - `colors`: List of Color structs representing the palette
  - `opts`: Keyword list of options:
    - `:target_colors`: Optional list of target colors to stay close to
    - `:avoid_colors`: Optional list of colors to avoid
    - `:background_color`: Background color for contrast calculation
    - `:weights`: Map of weights for different factors

  ## Examples

      iex> colors = [ChromaEx.Color.new("#FF0000"), ChromaEx.Color.new("#00FF00")]
      iex> ChromaEx.Annealing.Evaluation.cost(colors)
      120.5 # Example score
  """
  def cost(colors, opts \\ []) do
    # Get options or use defaults
    target_colors = Keyword.get(opts, :target_colors, [])
    avoid_colors = Keyword.get(opts, :avoid_colors, [])
    background_color = Keyword.get(opts, :background_color, Color.new("#FFFFFF"))

    # Default weights
    default_weights = %{
      # How differentiable the colors are
      energy: 1.25,
      # How uniformly spread the colors are
      range: 1.0,
      # How close to target colors
      target: 0.75,
      # How far from colors to avoid
      avoid: 0.5,
      # How good is contrast with background
      contrast: 0.25,

      # Color vision deficiency weights
      protanopia: 0.1,
      protanomaly: 0.1,
      deuteranopia: 0.1,
      deuteranomaly: 0.5,
      tritanopia: 0.05,
      tritanomaly: 0.05
    }

    weights = Map.merge(default_weights, Keyword.get(opts, :weights, %{}))

    # Calculate normal color distances
    normal_distances = calculate_all_distances(colors)

    # Calculate color distances for various types of color vision deficiency
    cvd_distances = %{
      protanopia: calculate_all_distances(colors, :protanopia),
      protanomaly: calculate_all_distances(colors, :protanomaly),
      deuteranopia: calculate_all_distances(colors, :deuteranopia),
      deuteranomaly: calculate_all_distances(colors, :deuteranomaly),
      tritanopia: calculate_all_distances(colors, :tritanopia),
      tritanomaly: calculate_all_distances(colors, :tritanomaly)
    }

    # Calculate scores
    energy_score = 100 - mean(normal_distances)
    range_score = range(normal_distances)

    target_score =
      if Enum.empty?(target_colors),
        do: 0,
        else: average_distance_from_colors(colors, target_colors)

    avoid_score =
      if Enum.empty?(avoid_colors),
        do: 0,
        else: 100 - min_distance_from_colors(colors, avoid_colors)

    # Color vision deficiency scores
    cvd_scores = %{
      protanopia: 100 - mean(cvd_distances.protanopia),
      protanomaly: 100 - mean(cvd_distances.protanomaly),
      deuteranopia: 100 - mean(cvd_distances.deuteranopia),
      deuteranomaly: 100 - mean(cvd_distances.deuteranomaly),
      tritanopia: 100 - mean(cvd_distances.tritanopia),
      tritanomaly: 100 - mean(cvd_distances.tritanomaly)
    }

    # Calculate contrast score
    # Theoretical maximum WCAG contrast ratio
    max_possible_contrast = 21.0

    min_contrast =
      Enum.reduce(colors, max_possible_contrast, fn color, acc ->
        min(Distance.contrast_ratio(color, background_color), acc)
      end)

    contrast_score = 100 - min_contrast / max_possible_contrast * 100

    # Apply weights and sum up the final cost
    weighted_cost =
      weights.energy * energy_score +
        weights.range * range_score +
        weights.target * target_score +
        weights.avoid * avoid_score +
        weights.contrast * contrast_score +
        weights.protanopia * cvd_scores.protanopia +
        weights.protanomaly * cvd_scores.protanomaly +
        weights.deuteranopia * cvd_scores.deuteranopia +
        weights.deuteranomaly * cvd_scores.deuteranomaly +
        weights.tritanopia * cvd_scores.tritanopia +
        weights.tritanomaly * cvd_scores.tritanomaly

    weighted_cost
  end

  @doc """
  Calculate all pairwise distances between colors in a palette.

  ## Parameters

  - `colors`: List of Color structs
  - `cvd_type`: Optional atom representing color vision deficiency type

  ## Returns

  List of distance values between each pair of colors
  """
  def calculate_all_distances(colors, cvd_type \\ :normal) do
    # Apply color vision deficiency simulation if needed
    colors =
      if cvd_type == :normal do
        colors
      else
        Enum.map(colors, &Vision.simulate(&1, cvd_type))
      end

    # Calculate all pairwise distances
    for i <- 0..(length(colors) - 2),
        j <- (i + 1)..(length(colors) - 1) do
      color_i = Enum.at(colors, i)
      color_j = Enum.at(colors, j)
      Distance.delta_e(color_i, color_j)
    end
  end

  @doc """
  Calculate the average distance from each color in a palette to the closest color in another palette.

  This is used to measure how similar a palette is to a target palette.
  """
  def average_distance_from_colors(test_colors, given_colors) do
    distances =
      Enum.map(test_colors, fn color ->
        closest_color = Enum.min_by(given_colors, &Distance.delta_e(color, &1))
        Distance.delta_e(color, closest_color)
      end)

    mean(distances)
  end

  @doc """
  Find the minimum distance from any color in a palette to the closest color in another palette.

  This is used to measure how well a palette avoids certain colors.
  """
  def min_distance_from_colors(test_colors, given_colors) do
    distances =
      Enum.map(test_colors, fn color ->
        closest_color = Enum.min_by(given_colors, &Distance.delta_e(color, &1))
        Distance.delta_e(color, closest_color)
      end)

    Enum.min(distances)
  end

  # Helper functions

  # Calculate the arithmetic mean of a list of numbers
  defp mean([]), do: 0

  defp mean(list) when is_list(list) do
    Enum.sum(list) / length(list)
  end

  # Calculate the range (max - min) of a list of numbers
  defp range([]), do: 0

  defp range(list) when is_list(list) do
    Enum.max(list) - Enum.min(list)
  end
end
