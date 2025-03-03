defmodule ChromaEx.Color do
  @moduledoc """
  Core color representation and operations module.

  This module provides the main Color struct and functions for basic color operations.
  """

  alias ChromaEx.Color.Conversion

  @type t :: %__MODULE__{
          r: float(),
          g: float(),
          b: float(),
          alpha: float()
        }

  defstruct [:r, :g, :b, alpha: 1.0]

  @doc """
  Creates a new color from various inputs.

  ## Examples

      iex> ChromaEx.Color.new("#FF0000")
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}

      iex> ChromaEx.Color.new(255, 0, 0)
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}

      iex> ChromaEx.Color.new({1.0, 0.0, 0.0})
      %ChromaEx.Color{r: 1.0, g: 0.0, b: 0.0, alpha: 1.0}
  """
  def new(hex) when is_binary(hex) do
    Conversion.hex_to_rgb(hex)
  end

  def new({r, g, b}) when is_float(r) and is_float(g) and is_float(b) do
    %__MODULE__{r: r, g: g, b: b}
  end

  def new({r, g, b}) when is_integer(r) and is_integer(g) and is_integer(b) do
    new(r, g, b)
  end

  def new(r, g, b) when is_integer(r) and is_integer(g) and is_integer(b) do
    %__MODULE__{
      r: r / 255,
      g: g / 255,
      b: b / 255
    }
  end

  @doc """
  Creates a random color.

  ## Examples

      iex> ChromaEx.Color.random()
      %ChromaEx.Color{r: 0.2, g: 0.5, b: 0.9, alpha: 1.0} # Random values
  """
  def random do
    %__MODULE__{
      r: :rand.uniform(),
      g: :rand.uniform(),
      b: :rand.uniform()
    }
  end

  @doc """
  Converts a color to RGB values (0-255).

  ## Examples

      iex> color = ChromaEx.Color.new("#FF0000")
      iex> ChromaEx.Color.to_rgb(color)
      {255, 0, 0}
  """
  def to_rgb(%__MODULE__{r: r, g: g, b: b}) do
    {round(r * 255), round(g * 255), round(b * 255)}
  end

  @doc """
  Converts a color to a hex string.

  ## Examples

      iex> color = ChromaEx.Color.new(255, 0, 0)
      iex> ChromaEx.Color.to_hex(color)
      "#ff0000"
  """
  def to_hex(%__MODULE__{} = color) do
    {r, g, b} = to_rgb(color)
    "#" <> Integer.to_string(r, 16) <> Integer.to_string(g, 16) <> Integer.to_string(b, 16)
  end

  @doc """
  Modifies a specific channel of a color.

  ## Examples

      iex> color = ChromaEx.Color.new("#FF0000")
      iex> ChromaEx.Color.set(color, :g, 0.5)
      %ChromaEx.Color{r: 1.0, g: 0.5, b: 0.0, alpha: 1.0}
  """
  def set(%__MODULE__{} = color, :r, value) when is_float(value) and value >= 0 and value <= 1 do
    %{color | r: value}
  end

  def set(%__MODULE__{} = color, :g, value) when is_float(value) and value >= 0 and value <= 1 do
    %{color | g: value}
  end

  def set(%__MODULE__{} = color, :b, value) when is_float(value) and value >= 0 and value <= 1 do
    %{color | b: value}
  end

  def set(%__MODULE__{} = color, :alpha, value)
      when is_float(value) and value >= 0 and value <= 1 do
    %{color | alpha: value}
  end

  @doc """
  Creates a randomly modified version of the input color.

  ## Examples

      iex> color = ChromaEx.Color.new("#FF0000")
      iex> modified = ChromaEx.Color.random_nearby(color)
      iex> modified.r != color.r or modified.g != color.g or modified.b != color.b
      true
  """
  def random_nearby(%__MODULE__{} = color) do
    # Choose a random channel to modify
    channel = Enum.random([:r, :g, :b])

    # Get the current value of that channel
    current_value = Map.get(color, channel)

    # Create a random adjustment between -0.05 and 0.05
    adjustment = :rand.uniform() * 0.1 - 0.05

    # Calculate the new value, ensuring it stays between 0 and 1
    new_value = (current_value + adjustment) |> max(0.0) |> min(1.0)

    # Apply the change to the selected channel
    set(color, channel, new_value)
  end
end
