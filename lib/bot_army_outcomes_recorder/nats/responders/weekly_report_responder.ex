defmodule BotArmyOutcomesRecorder.NATS.Responders.WeeklyReportResponder do
  @moduledoc """
  NATS responder for weekly outcomes reports.

  Subject: `outcomes.report.weekly`

  Request:
  ```json
  {
    "end_date": "2026-06-05" (optional, default: today)
  }
  ```

  Response:
  ```json
  {
    "ok": true,
    "report_markdown": "# 📊 Bot Army Outcomes...",
    "metrics": {...},
    "anomalies": [...],
    "highlights": [...]
  }
  ```
  """

  require Logger

  alias BotArmyOutcomesRecorder.Reports.WeeklyReport

  def handle_request(message) do
    payload = message["payload"] || %{}
    event_id = message["event_id"]

    end_date =
      case payload["end_date"] do
        str when is_binary(str) ->
          case Date.from_iso8601(str) do
            {:ok, date} -> date
            {:error, _} -> Date.utc_today()
          end

        _ ->
          Date.utc_today()
      end

    Logger.info("[WeeklyReportResponder] Generating report for #{end_date}")

    report = WeeklyReport.generate(end_date)
    markdown = WeeklyReport.to_markdown(report)

    response = %{
      "ok" => true,
      "event_id" => event_id,
      "schema_version" => "1.0",
      "report_markdown" => markdown,
      "period_start" => Date.to_string(report.period_start),
      "period_end" => Date.to_string(report.period_end),
      "metrics" =>
        report.metrics
        |> Enum.map(fn {name, data} ->
          {name,
           %{
             "current" => data.current_value,
             "previous" => data.previous_value,
             "trend_pct" => data.trend_pct,
             "status" => Atom.to_string(data.status)
           }}
        end)
        |> Map.new(),
      "anomalies" => report.anomalies,
      "highlights" => report.highlights
    }

    case Jason.encode(response) do
      {:ok, json} -> json
      {:error, reason} -> error_response(event_id, reason)
    end
  end

  defp error_response(event_id, reason) do
    Jason.encode!(%{
      "ok" => false,
      "event_id" => event_id,
      "error" => inspect(reason)
    })
  end
end
