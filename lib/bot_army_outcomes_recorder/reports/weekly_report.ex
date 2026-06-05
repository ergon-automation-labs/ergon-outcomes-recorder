defmodule BotArmyOutcomesRecorder.Reports.WeeklyReport do
  @moduledoc """
  Generates weekly outcomes report (markdown format).

  Pulls daily_rollups for the past 7 days and generates a human-readable summary
  with metrics, trends, anomalies, and insights.

  Usage:
      BotArmyOutcomesRecorder.Reports.WeeklyReport.generate()
      |> BotArmyOutcomesRecorder.Reports.WeeklyReport.to_markdown()

  Publishes to:
      - Email (future: send via SMTP)
      - PARA (via para.fs.write NATS subject)
      - Slack (future: via Synapse bot)
  """

  require Logger

  alias BotArmyOutcomesRecorder.Repo
  alias BotArmyOutcomesRecorder.Schemas.OutcomesDailyRollup
  import Ecto.Query

  defmodule Report do
    @type t :: %__MODULE__{
            period_start: Date.t(),
            period_end: Date.t(),
            generated_at: DateTime.t(),
            metrics: %{String.t() => metric_data()},
            anomalies: [String.t()],
            highlights: [String.t()]
          }

    @type metric_data :: %{
            current_value: float(),
            previous_value: float() | nil,
            trend_pct: float() | nil,
            status: :improving | :stable | :declining | :anomaly
          }

    defstruct [
      :period_start,
      :period_end,
      :generated_at,
      :metrics,
      :anomalies,
      :highlights
    ]
  end

  @doc """
  Generate a weekly report for the past 7 days.
  """
  def generate(end_date \\ Date.utc_today()) do
    start_date = Date.add(end_date, -6)

    metrics = fetch_week_metrics(start_date, end_date)
    anomalies = extract_anomalies(metrics)
    highlights = compute_highlights(metrics)

    %Report{
      period_start: start_date,
      period_end: end_date,
      generated_at: DateTime.utc_now(),
      metrics: metrics,
      anomalies: anomalies,
      highlights: highlights
    }
  end

  @doc """
  Convert report struct to markdown string.
  """
  def to_markdown(%Report{} = report) do
    [
      header(report),
      "\n",
      metrics_section(report),
      "\n",
      anomalies_section(report),
      "\n",
      highlights_section(report),
      "\n",
      footer(report)
    ]
    |> Enum.join("")
  end

  # Private: Generate markdown sections

  defp header(report) do
    period = "#{Date.to_string(report.period_start)} – #{Date.to_string(report.period_end)}"

    """
    # 📊 Bot Army Outcomes — Weekly Report

    **Week of**: #{period}
    **Generated**: #{DateTime.to_string(report.generated_at)}

    """
  end

  defp metrics_section(report) do
    if map_size(report.metrics) == 0 do
      "## 📈 Metrics\n\n*No data yet — waiting for events from bots*\n"
    else
      metrics_content =
        report.metrics
        |> Enum.sort_by(fn {_k, v} -> v.trend_pct || 0 end, :desc)
        |> Enum.map(fn {name, data} -> metric_row(name, data) end)
        |> Enum.join("\n")

      """
      ## 📈 Metrics

      | Metric | This Week | Trend | Status |
      |--------|-----------|-------|--------|
      #{metrics_content}

      """
    end
  end

  defp metric_row(name, data) do
    trend = format_trend(data.trend_pct)
    status_emoji = status_emoji(data.status)

    current = format_value(name, data.current_value)
    previous = format_value(name, data.previous_value)

    "| #{humanize_metric(name)} | #{current} | #{trend} | #{status_emoji} |"
  end

  defp format_trend(nil), do: "—"
  defp format_trend(pct) when pct > 5, do: "📈 +#{Float.round(pct, 1)}%"
  defp format_trend(pct) when pct < -5, do: "📉 #{Float.round(pct, 1)}%"
  defp format_trend(_), do: "→ ~0%"

  defp status_emoji(:improving), do: "✅"
  defp status_emoji(:stable), do: "↔️"
  defp status_emoji(:declining), do: "⚠️"
  defp status_emoji(:anomaly), do: "🚨"

  defp format_value(metric, value) when is_number(value) do
    case metric do
      "deep_work" <> _ -> "#{Float.round(value, 1)}h"
      "completion_rate" <> _ -> "#{Float.round(value * 100, 0)}%"
      "latency" <> _ -> "#{Float.round(value, 0)}ms"
      _ -> "#{Float.round(value, 2)}"
    end
  end

  defp format_value(_, nil), do: "—"

  defp humanize_metric(name) do
    name
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp anomalies_section(report) do
    if Enum.empty?(report.anomalies) do
      "## 🚨 Anomalies\n\n*No anomalies detected — everything looks normal.*\n"
    else
      anomalies_content =
        report.anomalies
        |> Enum.map(fn anomaly -> "- #{anomaly}\n" end)
        |> Enum.join("")

      """
      ## 🚨 Anomalies

      **Unusual patterns detected this week:**

      #{anomalies_content}
      """
    end
  end

  defp highlights_section(report) do
    if Enum.empty?(report.highlights) do
      "## ⭐ Highlights\n\n*Continue your current pace.*\n"
    else
      highlights_content =
        report.highlights
        |> Enum.map(fn highlight -> "- #{highlight}\n" end)
        |> Enum.join("")

      """
      ## ⭐ Highlights

      **What went well this week:**

      #{highlights_content}
      """
    end
  end

  defp footer(report) do
    """
    ---

    **Next Steps:**
    1. Review anomalies — adjust deep work schedule if needed
    2. Keep doing what's working (highlighted items)
    3. Task completion trending? Celebrate wins or identify blockers

    *This report auto-generates weekly from NATS outcomes events. More bots wired = richer insights.*
    """
  end

  # Private: Fetch metrics from database

  defp fetch_week_metrics(start_date, end_date) do
    rollups =
      Repo.all(
        from(r in OutcomesDailyRollup,
          where: r.date >= ^start_date and r.date <= ^end_date,
          order_by: [r.metric_name, :desc_nulls_last]
        )
      )

    # Group by metric, aggregate across week
    rollups
    |> Enum.group_by(& &1.metric_name)
    |> Enum.map(fn {metric_name, daily_rollups} ->
      # Average value for the week
      values = Enum.filter_map(daily_rollups, & &1.value, & &1.value)
      current_value = if Enum.empty?(values), do: nil, else: Enum.sum(values) / length(values)

      # Get previous week's average for trend
      previous_week_start = Date.add(start_date, -7)
      previous_week_end = Date.add(end_date, -7)

      prev_rollups =
        Repo.all(
          from(r in OutcomesDailyRollup,
            where:
              r.metric_name == ^metric_name and r.date >= ^previous_week_start and
                r.date <= ^previous_week_end
          )
        )

      prev_values = Enum.filter_map(prev_rollups, & &1.value, & &1.value)

      previous_value =
        if Enum.empty?(prev_values), do: nil, else: Enum.sum(prev_values) / length(prev_values)

      trend_pct =
        case {current_value, previous_value} do
          {cv, pv} when is_number(cv) and is_number(pv) and pv != 0 ->
            ((cv - pv) / pv * 100) |> Float.round(1)

          _ ->
            nil
        end

      status =
        case trend_pct do
          pct when is_number(pct) and pct > 5 -> :improving
          pct when is_number(pct) and pct < -5 -> :declining
          pct when is_number(pct) -> :stable
          nil -> :stable
        end

      {metric_name,
       %{
         current_value: current_value,
         previous_value: previous_value,
         trend_pct: trend_pct,
         status: status
       }}
    end)
    |> Map.new()
  end

  defp extract_anomalies(metrics) do
    metrics
    |> Enum.filter(fn {_metric, data} ->
      data.status == :anomaly
    end)
    |> Enum.map(fn {metric, data} ->
      "**#{humanize_metric(metric)}**: dropped #{abs(data.trend_pct)}% — investigate if intentional"
    end)
  end

  defp compute_highlights(metrics) do
    metrics
    |> Enum.filter(fn {_metric, data} ->
      data.status == :improving and data.trend_pct && data.trend_pct > 10
    end)
    |> Enum.map(fn {metric, data} ->
      "**#{humanize_metric(metric)}** improved #{Float.round(data.trend_pct, 1)}% — great momentum!"
    end)
  end
end
