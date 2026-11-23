defmodule ChromaExTest do
  use ExUnit.Case, async: true
  doctest ChromaEx.Harmony

  alias ChromaEx.Color.Oklch

  test "to_hex pads each channel and is lowercase" do
    assert ChromaEx.to_hex(ChromaEx.new("#000000")) == "#000000"
    assert ChromaEx.to_hex(ChromaEx.new("#0A0B0C")) == "#0a0b0c"
    assert ChromaEx.to_hex(ChromaEx.new(255, 0, 0)) == "#ff0000"
    assert ChromaEx.to_hex(ChromaEx.new(1.0, 0.5, 0.0)) == "#ff8000"
  end

  test "fixed colours are all kept, first, even when they are most of the palette" do
    fixed = ~w(#1d3557 #e63946 #000000 #f1faee)
    palette = ChromaEx.generate_palette(5, fixed_colors: fixed, seed: 3, cooling_rate: 0.9)
    assert length(palette) == 5
    assert palette |> Enum.take(4) |> Enum.map(&ChromaEx.to_hex/1) == fixed
  end

  test "a palette that is all fixed colours comes back as given" do
    palette = ChromaEx.generate_palette(2, fixed_colors: ~w(#112233 #445566), seed: 1)
    assert Enum.map(palette, &ChromaEx.to_hex/1) == ~w(#112233 #445566)
  end

  test "a seed makes palettes reproducible and leaves the caller's :rand alone" do
    :rand.seed(:exsss, 42)
    before = :rand.uniform()
    :rand.seed(:exsss, 42)

    a = ChromaEx.generate_palette(4, seed: 7, cooling_rate: 0.9)
    b = ChromaEx.generate_palette(4, seed: 7, cooling_rate: 0.9)
    assert Enum.map(a, &ChromaEx.to_hex/1) == Enum.map(b, &ChromaEx.to_hex/1)
    assert :rand.uniform() == before
  end

  test "min_contrast keeps generated colours off the background" do
    bg = ChromaEx.new("#111827")

    palette =
      ChromaEx.generate_palette(5,
        fixed_colors: ["#facc15"],
        background_color: bg,
        min_contrast: 3.0,
        seed: 5
      )

    for color <- palette, do: assert(ChromaEx.contrast_ratio(color, bg) >= 2.9)
  end

  test "OKLCH round-trips sRGB colours" do
    for hex <- ~w(#000000 #ffffff #ff0000 #1d4ed8 #7c3aed #22c55e #808080) do
      assert hex |> ChromaEx.new() |> Oklch.to_oklch() |> Oklch.from_oklch() |> ChromaEx.to_hex() ==
               hex
    end
  end

  test "out-of-gamut OKLCH is brought in by reducing chroma" do
    color = Oklch.from_oklch({0.9, 0.4, 264.0})
    {l, c, _h} = Oklch.to_oklch(color)
    assert_in_delta l, 0.9, 0.01
    assert c < 0.4
  end

  test "harmonies rotate hue and keep lightness" do
    base = ChromaEx.new("#1d4ed8")
    {l, _c, h} = ChromaEx.to_oklch(base)

    [^base, comp] = ChromaEx.scheme(base, :complementary)
    {l2, _c2, h2} = ChromaEx.to_oklch(comp)
    assert_in_delta l2, l, 0.02
    assert_in_delta Oklch.normalize_hue(h2 - h), 180, 3

    assert length(ChromaEx.scheme(base, :triadic)) == 3
    assert Enum.at(ChromaEx.scheme(base, :analogous), 1) == base
    assert base in ChromaEx.scheme(base, :monochromatic)
  end

  test "scale runs light to dark" do
    ls = ChromaEx.new("#e63946") |> ChromaEx.scale(9) |> Enum.map(&elem(ChromaEx.to_oklch(&1), 0))
    assert length(ls) == 9
    assert ls == Enum.sort(ls, :desc)
  end

  test "ensure_contrast darkens on light backgrounds until the ratio is met" do
    white = ChromaEx.new("#ffffff")
    yellow = ChromaEx.new("#facc15")
    assert ChromaEx.contrast_ratio(yellow, white) < 4.5

    {:ok, fixed} = ChromaEx.ensure_contrast(yellow, white, 4.5)
    assert ChromaEx.contrast_ratio(fixed, white) >= 4.5
    # Still passes once written as hex
    assert ChromaEx.contrast_ratio(ChromaEx.new(ChromaEx.to_hex(fixed)), white) >= 4.5
    assert ChromaEx.contrast_ratio(fixed, white) < 5.0

    navy = ChromaEx.new("#0f172a")
    assert {:ok, ^navy} = ChromaEx.ensure_contrast(navy, white, 4.5)
  end

  test "readable_on picks the ink with more contrast" do
    assert ChromaEx.readable_on(ChromaEx.new("#0f172a")) |> ChromaEx.to_hex() == "#ffffff"
    assert ChromaEx.readable_on(ChromaEx.new("#fef3c7")) |> ChromaEx.to_hex() == "#111111"
  end
end
