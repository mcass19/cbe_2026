defmodule SlidesTui.MixProject do
  use Mix.Project

  def project do
    [
      app: :slides_tui,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        summary: [threshold: 100],
        ignore_modules: [
          # `mix slides.tui` boots a real terminal session via
          # `SlidesTui.run/1`. The CLI shell is thin glue; the work it
          # delegates to is covered directly.
          Mix.Tasks.Slides.Tui,
          # Test fixtures — scaffolding for the test suite, not library code
          ~r/^SlidesTui\.Test\./,
          # The talk deck under lib/slides/ — presentation content, hand-tuned
          # visually rather than asserted on. The runner it exercises is
          # covered directly.
          ~r/^TuisEverywhere\./
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SlidesTui.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_ratatui, "~> 0.11"}
    ]
  end
end
