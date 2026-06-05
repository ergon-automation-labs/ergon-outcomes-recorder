defmodule BotArmyOutcomesRecorder.NATS.Responders.MonthlyReportResponder do
  @moduledoc """
  Handles monthly report requests via NATS.

  Request: outcomes.report.monthly with {"year": 2026, "month": 5}
  Response: markdown report for that month
  """

  require Logger

  alias BotArmyOutcomesRecorder.Reports.MonthlyReport

  def handle_request(request) do
    year = request["year"] || DateTime.utc_now().year
    month = request["month"] || DateTime.utc_now().month

    try do
      report = MonthlyReport.generate(year, month)
      markdown = MonthlyReport.to_markdown(report)

      ok_response(%{
        "data" => markdown,
        "year" => year,
        "month" => month,
        "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    rescue
      e ->
        Logger.warning("[MonthlyReportResponder] Error generating report",
          year: year,
          month: month,
          error: inspect(e)
        )

        error_response("failed_to_generate_report", inspect(e))
    end
  end

  defp ok_response(data) do
    Jason.encode!(%{
      "ok" => true,
      "data" => data,
      "schema_version" => "1.0"
    })
  end

  defp error_response(error_code, reason) do
    Jason.encode!(%{
      "ok" => false,
      "error" => error_code,
      "reason" => reason,
      "schema_version" => "1.0"
    })
  end
end
