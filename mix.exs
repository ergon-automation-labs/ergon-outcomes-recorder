defmodule BotArmyOutcomesRecorder.MixProject do
  use Mix.Project

  def project do
    [
      app: :bot_army_outcomes_recorder,
      version: "0.1.32",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {BotArmyOutcomesRecorder.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gnat, "~> 1.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:bot_army_library_runtime, path: "../bot_army_library_runtime", override: true},
      {:bot_army_library_core, path: "../bot_army_library_core"},
      # The shared makefile's push pipeline runs `make credo` (mix credo --only warning).
      # Without this dep that task cannot even load, so `make push` failed for every
      # change and the repo could not be released through the standard path at all
      # (found 2026-10-02: it had drifted to runtime 0.14.62 while the fleet moved on).
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
