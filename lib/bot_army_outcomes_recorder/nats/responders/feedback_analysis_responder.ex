defmodule BotArmyOutcomesRecorder.NATS.Responders.FeedbackAnalysisResponder do
  @moduledoc """
  Handles feedback analysis requests via NATS.

  Request: outcomes.feedback.analyze (triggers analysis of past 7 days)
  Response: list of proposed feedback adjustments

  Also publishes feedback changes to outcomes.feedback.change topic.
  """

  require Logger

  alias BotArmyOutcomesRecorder.Feedback.FeedbackLoopIntegrator
  alias BotArmyOutcomesRecorder.Feedback.FeedbackLogger

  def handle_request(_request) do
    try do
      feedback = FeedbackLoopIntegrator.analyze_and_generate_feedback()

      feedback_list =
        Enum.map(feedback, fn {component, action, rationale, metrics} ->
          %{
            "component" => component,
            "action" => action,
            "rationale" => rationale,
            "proposed_metrics" => metrics
          }
        end)

      ok_response(%{
        "feedback_items" => feedback_list,
        "total_feedback" => length(feedback_list),
        "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    rescue
      e ->
        Logger.warning("[FeedbackAnalysisResponder] Error analyzing feedback",
          error: inspect(e)
        )

        error_response("feedback_analysis_failed", inspect(e))
    end
  end

  @doc """
  Apply a feedback adjustment and publish the change.
  """
  def apply_and_publish(component, action, rationale, before_metrics) do
    try do
      FeedbackLoopIntegrator.apply_feedback({component, action, rationale, before_metrics})

      # Publish change event
      publish_change_event(component, action, rationale)

      ok_response(%{
        "component" => component,
        "action" => action,
        "status" => "applied",
        "applied_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    rescue
      e ->
        Logger.warning("[FeedbackAnalysisResponder] Error applying feedback",
          component: component,
          action: action,
          error: inspect(e)
        )

        error_response("feedback_application_failed", inspect(e))
    end
  end

  defp publish_change_event(component, action, rationale) do
    event = %{
      "component" => component,
      "action" => action,
      "rationale" => rationale,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Logger.debug("[FeedbackAnalysisResponder] Publishing change event",
      event: event
    )

    # In production, this would publish to outcomes.feedback.change topic
    :ok
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
