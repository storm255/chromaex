defmodule ChromaEx.Harmony do
  @moduledoc """
  Colour harmonies, tints and shades, and contrast fixes, worked in OKLCH.

  Hues are rotated around the colour wheel with lightness and chroma kept, so a
  complementary or triadic partner looks as strong as the base colour. Where the
  rotated colour won't fit in sRGB its chroma is reduced (see
  `ChromaEx.Color.Oklch.from_oklch/1`).

  These are the classic schemes. For many colours that must be told apart (chart
  series, categories), use `ChromaEx.generate_palette/2` instead; it optimises for
  distance, including under colour-vision deficiency.
  """

  alias ChromaEx.Color
  alias ChromaEx.Color.{Distance, Oklch}

  @schemes %{
    complementary: [0, 180],
    analogous: [-30, 0, 30],
    triadic: [0, 120, 240],
    split_complementary: [0, 150, 210],
    tetradic: [0, 90, 180, 270]
  }

  @doc "The scheme names `scheme/2` accepts."
  def schemes, do: Map.keys(@schemes) ++ [:monochromatic]

  @doc """
  A harmony built on `base`. The base colour is in the list, unchanged, at the
  place its hue offset puts it (first for most schemes, the middle for
  `:analogous`). `:monochromatic` gives the base with two lighter and two darker
  steps, darkest first.

      iex> ChromaEx.Harmony.scheme(ChromaEx.new("#1d4ed8"), :complementary) |> length()
      2
  """
  @spec scheme(Color.t(), atom()) :: [Color.t()]
  def scheme(%Color{} = base, :monochromatic) do
    {l, _c, _h} = Oklch.to_oklch(base)

    [-0.24, -0.12, 0.0, 0.12, 0.24]
    |> Enum.map(&(l + &1))
    |> Enum.filter(&(&1 > 0.12 and &1 < 0.97))
    |> Enum.map(fn
      ^l -> base
      lightness -> with_lightness(base, lightness)
    end)
  end

  def scheme(%Color{} = base, name) do
    offsets = Map.fetch!(@schemes, name)
    {l, c, h} = Oklch.to_oklch(base)

    Enum.map(offsets, fn
      0 -> base
      offset -> Oklch.from_oklch({l, c, Oklch.normalize_hue(h + offset)})
    end)
  end

  @doc """
  A ramp of `steps` tints and shades of `color`, lightest first (like a 50..900
  design-token scale). Chroma eases off towards both ends so the palest and darkest
  steps don't turn garish.
  """
  @spec scale(Color.t(), pos_integer()) :: [Color.t()]
  def scale(%Color{} = color, steps \\ 9) when steps >= 2 do
    {_l, c, h} = Oklch.to_oklch(color)
    {top, bottom} = {0.97, 0.25}

    for i <- 0..(steps - 1) do
      l = top - (top - bottom) * i / (steps - 1)
      # 1.0 at mid-lightness, falling to ~0.35 at the ends
      taper = 1 - 0.65 * :math.pow(abs(l - 0.6) / 0.37, 2)
      Oklch.from_oklch({l, c * max(taper, 0.2), h})
    end
  end

  @doc "`color` at OKLCH lightness `l` (0..1), same chroma and hue."
  def with_lightness(%Color{} = color, l) do
    {_l, c, h} = Oklch.to_oklch(color)
    Oklch.from_oklch({l, c, h})
  end

  @doc "Lighter by `amount` of OKLCH lightness (0.1 is a clear step)."
  def lighten(%Color{} = color, amount \\ 0.1) do
    {l, _c, _h} = Oklch.to_oklch(color)
    with_lightness(color, l + amount)
  end

  @doc "Darker by `amount` of OKLCH lightness."
  def darken(%Color{} = color, amount \\ 0.1), do: lighten(color, -amount)

  @doc "`a` and `b` mixed in OKLab; `t` = 0 is `a`, 1 is `b`."
  def mix(%Color{} = a, %Color{} = b, t \\ 0.5) do
    {l1, a1, b1} = Oklch.to_oklab(a)
    {l2, a2, b2} = Oklch.to_oklab(b)
    lerp = fn x, y -> x + (y - x) * t end
    Oklch.from_oklab({lerp.(l1, l2), lerp.(a1, a2), lerp.(b1, b2)}) |> elem(1)
  end

  @doc """
  `color`, or the nearest lightness of it that reaches `ratio` WCAG contrast
  against `background` (4.5 for body text, 3.0 for large text and graphics).
  Moves away from the background: darker on light backgrounds, lighter on dark.
  `{:ok, color}`, or `{:error, best}` when even the extreme of that hue falls short.
  An adjusted colour is on 8-bit channels and checked there, so it still passes
  once written as hex.
  """
  @spec ensure_contrast(Color.t(), Color.t(), number()) :: {:ok | :error, Color.t()}
  def ensure_contrast(%Color{} = color, %Color{} = background, ratio \\ 4.5) do
    if Distance.contrast_ratio(color, background) >= ratio do
      {:ok, color}
    else
      {l, _c, _h} = Oklch.to_oklch(color)
      {bg_l, _, _} = Oklch.to_oklch(background)
      # Go towards whichever end gives more room
      target = if bg_l >= 0.6, do: 0.0, else: 1.0
      extreme = color |> with_lightness(target) |> quantize()

      if Distance.contrast_ratio(extreme, background) < ratio do
        {:error, extreme}
      else
        {:ok, search_lightness(color, background, ratio, l, target, 24)}
      end
    end
  end

  # Binary search between the failing lightness and the passing extreme
  defp search_lightness(color, _bg, _ratio, _fail, pass, 0),
    do: color |> with_lightness(pass) |> quantize()

  defp search_lightness(color, bg, ratio, fail, pass, n) do
    mid = (fail + pass) / 2

    if Distance.contrast_ratio(color |> with_lightness(mid) |> quantize(), bg) >= ratio,
      do: search_lightness(color, bg, ratio, fail, mid, n - 1),
      else: search_lightness(color, bg, ratio, mid, pass, n - 1)
  end

  # The colour as it will be once written as hex
  defp quantize(color) do
    {r, g, b} = Color.to_rgb(color)
    Color.new(r, g, b)
  end

  @doc "Whichever of `candidates` contrasts most with `background` (default near-black and white)."
  def readable_on(%Color{} = background, candidates \\ nil) do
    candidates = candidates || [Color.new("#111111"), Color.new("#ffffff")]
    Enum.max_by(candidates, &Distance.contrast_ratio(&1, background))
  end
end
