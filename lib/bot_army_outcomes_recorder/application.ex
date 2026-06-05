defmodule BotArmyOutcomesRecorder.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        BotArmyOutcomesRecorder.Repo,
        BotArmyOutcomesRecorder.NATS.Consumer,
        BotArmyOutcomesRecorder.NATS.ReportHandler,
        BotArmyOutcomesRecorder.Aggregator,
        BotArmyOutcomesRecorder.HealthReporter,
        maybe_add_feedback_consumer()
      ]
      |> Enum.filter(& &1)

    opts = [strategy: :one_for_one, name: BotArmyOutcomesRecorder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_feedback_consumer do
    if Mix.env() != :test do
      BotArmyOutcomesRecorder.NATS.FeedbackChangeConsumer
    end
  end
end
