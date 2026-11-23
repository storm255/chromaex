defmodule ChromaEx.Color.Oklch do
  @moduledoc """
  OKLab and OKLCH (Björn Ottosson, 2020).

  OKLCH is a perceptual space where equal steps look roughly equal: lightness `l`
  runs 0..1, chroma `c` from 0 (grey) to about 0.37 at the edge of sRGB, and hue `h`
  is in degrees. Rotating the hue keeps a colour's lightness and saturation, which
  is what harmonies need, and changing `l` alone gives clean tints and shades.

  Not every OKLCH triple fits in sRGB. `from_oklch/1` brings an out-of-gamut colour
  back by reducing chroma at the same lightness and hue, so the colour keeps its
  place and loses only saturation.
  """

  alias ChromaEx.Color

  @type oklab :: {float(), float(), float()}
  @type oklch :: {float(), float(), float()}

  @doc "OKLab `{l, a, b}` of a colour."
  @spec to_oklab(Color.t()) :: oklab()
  def to_oklab(%Color{r: r, g: g, b: b}) do
    {r, g, b} = {linear(r), linear(g), linear(b)}

    l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

    {
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    }
  end

  @doc "OKLCH `{l, c, h}` of a colour; `h` is 0.0 for greys."
  @spec to_oklch(Color.t()) :: oklch()
  def to_oklch(%Color{} = color) do
    {l, a, b} = to_oklab(color)
    c = :math.sqrt(a * a + b * b)
    h = if c < 1.0e-6, do: 0.0, else: normalize_hue(:math.atan2(b, a) * 180 / :math.pi())
    {l, c, h}
  end

  @doc """
  The colour for OKLab `{l, a, b}`, unclamped: `{:ok, color}` when it's in sRGB,
  `{:out_of_gamut, clamped}` when it isn't.
  """
  @spec from_oklab(oklab()) :: {:ok | :out_of_gamut, Color.t()}
  def from_oklab({l, a, b}) do
    l_ = l + 0.3963377774 * a + 0.2158037573 * b
    m_ = l - 0.1055613458 * a - 0.0638541728 * b
    s_ = l - 0.0894841775 * a - 1.2914855480 * b

    {l3, m3, s3} = {l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_}

    rgb = [
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
    ]

    status = if Enum.all?(rgb, &(&1 >= -1.0e-4 and &1 <= 1.0001)), do: :ok, else: :out_of_gamut
    [r, g, b] = Enum.map(rgb, &(&1 |> clamp() |> gamma()))
    {status, %Color{r: r, g: g, b: b}}
  end

  @doc """
  The sRGB colour for OKLCH `{l, c, h}`, reducing chroma until it fits if it's out
  of gamut.
  """
  @spec from_oklch(oklch()) :: Color.t()
  def from_oklch({l, c, h}) do
    l = clamp(l)
    c = max(c, 0.0)

    case lch_to_rgb(l, c, h) do
      {:ok, color} -> color
      {:out_of_gamut, _} -> fit_chroma(l, 0.0, c, h, 20)
    end
  end

  # Binary search for the largest chroma at this lightness and hue that fits sRGB
  defp fit_chroma(l, lo, _hi, h, 0), do: lch_to_rgb(l, lo, h) |> elem(1)

  defp fit_chroma(l, lo, hi, h, n) do
    mid = (lo + hi) / 2

    case lch_to_rgb(l, mid, h) do
      {:ok, _} -> fit_chroma(l, mid, hi, h, n - 1)
      {:out_of_gamut, _} -> fit_chroma(l, lo, mid, h, n - 1)
    end
  end

  defp lch_to_rgb(l, c, h) do
    rad = h * :math.pi() / 180
    from_oklab({l, c * :math.cos(rad), c * :math.sin(rad)})
  end

  @doc "A hue in degrees brought into 0..360."
  def normalize_hue(h) do
    h = :math.fmod(h, 360.0)
    if h < 0, do: h + 360.0, else: h
  end

  defp linear(v) when v <= 0.04045, do: v / 12.92
  defp linear(v), do: :math.pow((v + 0.055) / 1.055, 2.4)

  defp gamma(v) when v <= 0.0031308, do: 12.92 * v
  defp gamma(v), do: 1.055 * :math.pow(v, 1 / 2.4) - 0.055

  defp cbrt(v) when v < 0, do: -:math.pow(-v, 1 / 3)
  defp cbrt(v), do: :math.pow(v, 1 / 3)

  defp clamp(v), do: v |> max(0.0) |> min(1.0)
end
