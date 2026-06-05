defmodule BotArmyOutcomesRecorder.Aggregator do
  use GenServer
  require Logger

  alias BotArmyOutcomesRecorder.Repo
  alias BotArmyOutcomesRecorder.Schemas.{OutcomesEvent, OutcomesDailyRollup}
  import Ecto.Query

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Run aggregation every hour
    schedule_aggregation(3600)
    {:ok, %{last_aggregated: nil}}
  end

  @impl true
  def handle_info(:aggregate, state) do
    aggregate_daily()
    schedule_aggregation(3600)
    {:noreply, %{state | last_aggregated: DateTime.utc_now()}}
  end

  defp schedule_aggregation(interval_seconds) do
    Process.send_after(self(), :aggregate, interval_seconds * 1000)
  end

  # Aggregate events from the past 24 hours into daily rollups
  defp aggregate_daily do
    today = Date.utc_today()

    metrics = [
      "deep_work_hours",
      "completion_rate",
      "decomposition_quality",
      "mode_prediction_accuracy",
      "notification_efficacy",
      "agentic_alignment_score",
      "learning_outcome_accuracy",
      "behavioral_pattern_cycles",
      "responder_latency_p95",
      "system_reliability"
    ]

    Enum.each(metrics, fn metric ->
      compute_rollup(today, metric)
    end)
  end

  defp compute_rollup(date, metric_name) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    # Fetch events for the metric
    events =
      Repo.all(
        from(e in OutcomesEvent,
          where:
            e.metric_name == ^metric_name and
              e.recorded_at >= ^start_of_day and
              e.recorded_at <= ^end_of_day,
          select: e.value
        )
      )

    if Enum.empty?(events) do
      Logger.debug("No events for metric", metric: metric_name, date: date)
    else
      values = Enum.filter(events, &is_number/1)

      rollup_attrs = %{
        date: date,
        metric_name: metric_name,
        value: compute_average(values),
        p50: compute_percentile(values, 0.5),
        p95: compute_percentile(values, 0.95),
        p99: compute_percentile(values, 0.99)
      }

      # Add trend if we have previous data
      rollup_attrs =
        case fetch_previous_period_value(date, metric_name) do
          {:ok, prev_value} ->
            trend_pct =
              case rollup_attrs.value do
                nil -> nil
                v when is_number(v) -> ((v - prev_value) / prev_value * 100) |> Float.round(1)
              end

            Map.merge(rollup_attrs, %{
              value_previous_period: prev_value,
              trend_pct: trend_pct
            })

          :error ->
            rollup_attrs
        end

      # Check for anomalies
      rollup_attrs = detect_anomalies(metric_name, rollup_attrs)

      # Insert or update
      case Repo.get_by(OutcomesDailyRollup, date: date, metric_name: metric_name) do
        nil ->
          OutcomesDailyRollup.changeset(%OutcomesDailyRollup{}, rollup_attrs)
          |> Repo.insert()

        existing ->
          OutcomesDailyRollup.changeset(existing, rollup_attrs)
          |> Repo.update()
      end
    end
  end

  defp compute_average(values) when is_list(values) and length(values) > 0 do
    (Enum.sum(values) / length(values)) |> Float.round(2)
  end

  defp compute_average(_), do: nil

  defp compute_percentile(values, percentile) when is_list(values) and length(values) > 0 do
    sorted = Enum.sort(values)
    idx = max(0, round(length(sorted) * percentile) - 1)
    (Enum.at(sorted, idx) || 0) |> Float.round(2)
  end

  defp compute_percentile(_, _), do: nil

  defp fetch_previous_period_value(date, metric_name) do
    previous_date = Date.add(date, -1)

    case Repo.get_by(OutcomesDailyRollup, date: previous_date, metric_name: metric_name) do
      nil -> :error
      rollup -> {:ok, rollup.value}
    end
  end

  defp detect_anomalies(metric_name, rollup_attrs) do
    case metric_name do
      "deep_work_hours" ->
        case rollup_attrs[:trend_pct] do
          pct when is_number(pct) and pct < -40 ->
            Map.merge(rollup_attrs, %{
              is_anomaly: true,
              anomaly_reason: "Deep work time dropped #{abs(pct)}%"
            })

          _ ->
            rollup_attrs
        end

      _ ->
        rollup_attrs
    end
  end
end
