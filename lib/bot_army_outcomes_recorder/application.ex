defmodule BotArmyOutcomesRecorder.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BotArmyOutcomesRecorder.Repo,
      BotArmyOutcomesRecorder.NATS.Consumer,
      BotArmyOutcomesRecorder.NATS.ReportHandler,
      BotArmyOutcomesRecorder.Aggregator,
      BotArmyOutcomesRecorder.HealthReporter
    ]

    opts = [strategy: :one_for_one, name: BotArmyOutcomesRecorder.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
