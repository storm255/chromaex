defmodule ChromaEx.Annealing.Optimizer do
  @moduledoc """
  Implements simulated annealing algorithm for optimizing color palettes.

  This module uses simulated annealing to find an optimal set of colors based on
  multiple criteria including perceptual distance, accessibility, and visual appeal.
  """

  alias ChromaEx.Color
  alias ChromaEx.Annealing.Evaluation

  @doc """
  Generates an optimized color palette using simulated annealing.

  ## Parameters

  - `count`: Number of colors to generate
  - `opts`: Keyword list of options:
    - `:initial_colors`: Optional list of initial colors to start with
    - `:fixed_colors`: Optional list of colors that should not be modified
    - `:target_colors`: Optional list of colors to stay close to
    - `:avoid_colors`: Optional list of colors to avoid
    - `:background_color`: Background color for contrast calculation
    - `:weights`: Map of weights for different factors
    - `:min_contrast`: WCAG ratio each colour should reach on the background (see
      `ChromaEx.Annealing.Evaluation.cost/2`)
    - `:temperature`: Starting temperature (default: 1000)
    - `:cooling_rate`: Rate at which temperature decreases (default: 0.99)
    - `:cutoff`: Temperature at which to stop (default: 0.0001)
    - `:debug`: Whether to output debug information (default: false)
    - `:seed`: An integer; when given the run is reproducible (the same seed and
      options give the same palette). The caller's `:rand` state is restored after.

  ## Examples

      iex> ChromaEx.Annealing.Optimizer.optimize(5)
      [
        %ChromaEx.Color{r: 0.0, g: 0.51, b: 0.74},
        %ChromaEx.Color{r: 0.91, g: 0.0, b: 0.31},
        %ChromaEx.Color{r: 1.0, g: 0.51, b: 0.12},
        %ChromaEx.Color{r: 0.19, g: 0.51, b: 0.0},
        %ChromaEx.Color{r: 0.59, g: 0.39, b: 0.95}
      ]
  """
  def optimize(count, opts \\ []) do
    case Keyword.pop(opts, :seed) do
      {nil, opts} -> run(count, opts)
      {seed, opts} when is_integer(seed) -> with_seed(seed, fn -> run(count, opts) end)
    end
  end

  defp with_seed(seed, fun) do
    saved = :rand.export_seed()
    :rand.seed(:exsss, seed)

    try do
      fun.()
    after
      if saved == :undefined, do: :rand.seed(:exsss), else: :rand.seed(saved)
    end
  end

  defp run(count, opts) do
    # Get options or use defaults
    initial_colors = Keyword.get(opts, :initial_colors, [])
    fixed_colors = Keyword.get(opts, :fixed_colors, [])
    target_colors = Keyword.get(opts, :target_colors, [])
    avoid_colors = Keyword.get(opts, :avoid_colors, [])
    background_color = Keyword.get(opts, :background_color, Color.new("#FFFFFF"))
    weights = Keyword.get(opts, :weights, %{})

    temperature = Keyword.get(opts, :temperature, 1000.0)
    cooling_rate = Keyword.get(opts, :cooling_rate, 0.99)
    cutoff = Keyword.get(opts, :cutoff, 0.0001)
    debug = Keyword.get(opts, :debug, false)

    # Build initial list of colors
    # Fixed colours always come first and are kept; initial colours fill what's left
    colors = fixed_colors ++ Enum.take(initial_colors, max(count - length(fixed_colors), 0))

    # If we don't have enough colors, generate random ones
    colors =
      if length(colors) < count do
        colors ++ Enum.map(1..(count - length(colors)), fn _ -> Color.random() end)
      else
        colors
      end

    # Initialize evaluation options
    eval_opts = [
      target_colors: target_colors,
      avoid_colors: avoid_colors,
      background_color: background_color,
      weights: weights,
      min_contrast: Keyword.get(opts, :min_contrast)
    ]

    # Track original colors and cost for debugging
    start_colors = colors
    start_cost = Evaluation.cost(colors, eval_opts)

    if debug do
      IO.puts("Starting optimization with #{count} colors")
      IO.puts("Initial cost: #{start_cost}")
    end

    # Run the simulated annealing algorithm
    {optimized_colors, final_cost} =
      annealing_loop(
        colors,
        temperature,
        cooling_rate,
        cutoff,
        length(fixed_colors),
        eval_opts,
        debug
      )

    # Print debug results if requested
    if debug do
      IO.puts("\nOptimization complete:")
      IO.puts("Start colors: #{inspect(Enum.map(start_colors, &Color.to_hex/1))}")
      IO.puts("Start cost: #{start_cost}")
      IO.puts("Final colors: #{inspect(Enum.map(optimized_colors, &Color.to_hex/1))}")
      IO.puts("Final cost: #{final_cost}")
      IO.puts("Cost improvement: #{start_cost - final_cost}")
    end

    optimized_colors
  end

  # Main annealing loop
  defp annealing_loop(colors, temperature, cooling_rate, cutoff, fixed_count, eval_opts, debug) do
    annealing_loop(
      colors,
      temperature,
      cooling_rate,
      cutoff,
      fixed_count,
      eval_opts,
      debug,
      0,
      nil
    )
  end

  defp annealing_loop(
         colors,
         temperature,
         cooling_rate,
         cutoff,
         fixed_count,
         eval_opts,
         debug,
         iteration,
         prev_cost
       ) do
    # Stop if temperature is below cutoff
    if temperature <= cutoff do
      cost = Evaluation.cost(colors, eval_opts)
      {colors, cost}
    else
      current_cost = if prev_cost, do: prev_cost, else: Evaluation.cost(colors, eval_opts)

      # Print debug info periodically
      if debug && rem(iteration, 100) == 0 do
        IO.puts("Iteration #{iteration}, Temperature: #{temperature}, Cost: #{current_cost}")
      end

      # For each color that isn't fixed
      {new_colors, new_cost} =
        Enum.reduce_while(
          fixed_count..(length(colors) - 1)//1,
          {colors, current_cost},
          fn i, {current_colors, current_cost} ->
            # Create new state with a random nearby color
            new_colors = List.update_at(current_colors, i, &Color.random_nearby/1)
            new_cost = Evaluation.cost(new_colors, eval_opts)

            delta = new_cost - current_cost

            # Accept if better (lower cost), or a worse one with probability
            # exp(-delta / T). Only computed for delta >= 0: for a large
            # improvement at low T the exponent would overflow.
            if delta < 0 or :rand.uniform() < :math.exp(-delta / temperature) do
              {:cont, {new_colors, new_cost}}
            else
              {:cont, {current_colors, current_cost}}
            end
          end
        )

      # Cool down the temperature and continue
      annealing_loop(
        new_colors,
        temperature * cooling_rate,
        cooling_rate,
        cutoff,
        fixed_count,
        eval_opts,
        debug,
        iteration + 1,
        new_cost
      )
    end
  end
end
