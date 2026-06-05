defmodule BotArmyOutcomesRecorder.HealthReporter do
  use GenServer
  require Logger

  alias BotArmyOutcomesRecorder.Repo

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_health_check(30_000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:health_check, state) do
    report_health()
    schedule_health_check(60_000)
    {:noreply, state}
  end

  defp schedule_health_check(interval_ms) do
    Process.send_after(self(), :health_check, interval_ms)
  end

  defp report_health do
    case check_database_health() do
      :ok ->
        Logger.info("OutcomesRecorder healthy")
        publish_health(:healthy)

      {:error, reason} ->
        Logger.warning("OutcomesRecorder health check failed", reason: reason)
        publish_health(:degraded)
    end
  end

  defp check_database_health do
    case Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp publish_health(status) do
    # Future: publish to NATS system.health.outcomes_recorder
    Logger.debug("Health status", status: status)
  end
end
