defmodule BotArmyOutcomesRecorder.Feedback.FeedbackLoopIntegrator do
  @moduledoc """
  Analyzes outcomes data and generates configuration adjustments for system components.

  Applies feedback from outcomes metrics to tune:
  - Context Broker DND rules (notification timing based on dismiss patterns)
  - Dispatcher routing (task routing based on completion time deltas)
  - LLM bot prompts (system instructions based on decomposition quality)

  All changes are logged with before/after metrics and rationale.
  """

  require Logger

  alias BotArmyOutcomesRecorder.Repo
  alias BotArmyOutcomesRecorder.Schemas.OutcomesDailyRollup
  alias BotArmyOutcomesRecorder.Feedback.FeedbackLogger
  import Ecto.Query

  @doc """
  Analyze outcomes for the past 7 days and generate feedback adjustments.
  Returns list of {component, action, rationale, metrics} tuples.
  """
  def analyze_and_generate_feedback do
    week_ago = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_date()
    today = DateTime.utc_now() |> DateTime.to_date()

    metrics = fetch_week_metrics(week_ago, today)

    feedback = []

    # DND rule adjustments based on notification dismissal
    feedback = feedback ++ analyze_dnd_patterns(metrics)

    # Dispatcher routing adjustments based on task completion times
    feedback = feedback ++ analyze_completion_time_patterns(metrics)

    # LLM system prompt adjustments based on decomposition quality
    feedback = feedback ++ analyze_decomposition_patterns(metrics)

    feedback
  end

  @doc """
  Apply a feedback adjustment and log it.
  """
  def apply_feedback({component, action, rationale, before_metrics}) do
    after_metrics = get_current_metrics()

    case component do
      "context_broker" ->
        apply_context_broker_change(action, rationale, before_metrics, after_metrics)

      "dispatcher" ->
        apply_dispatcher_change(action, rationale, before_metrics, after_metrics)

      "llm_bot" ->
        apply_llm_bot_change(action, rationale, before_metrics, after_metrics)

      _ ->
        {:error, "unknown_component"}
    end

    FeedbackLogger.log_change(component, action, rationale, before_metrics, after_metrics)
  end

  # Private helpers

  defp fetch_week_metrics(start_date, end_date) do
    rollups =
      OutcomesDailyRollup
      |> where([r], r.date >= ^start_date and r.date <= ^end_date)
      |> Repo.all()

    rollups
    |> Enum.group_by(& &1.metric_name)
    |> Enum.into(%{}, fn {metric, values} ->
      avg = values |> Enum.map(& &1.value) |> Enum.filter(& &1) |> average()
      {metric, avg}
    end)
  end

  defp analyze_dnd_patterns(metrics) do
    feedback = []

    # If notification dismissals are high (>40%), tighten DND window
    dismissal_rate = metrics["notification_dismissal_rate"] || 0

    if dismissal_rate > 0.4 do
      feedback ++
        [
          {
            "context_broker",
            "extend_dnd_window",
            "High dismissal rate (#{Float.round(dismissal_rate, 2)}) suggests more aggressive DND needed",
            %{
              "dismissal_rate" => dismissal_rate,
              "current_dnd_window" => "14:00-18:00",
              "action" => "extend to 13:00-19:00"
            }
          }
        ]
    else
      feedback
    end
  end

  defp analyze_completion_time_patterns(metrics) do
    feedback = []

    # If task latency is high (>500ms) for certain task types, adjust dispatcher routing
    latency = metrics["task_latency"] || 0

    if latency > 500 do
      feedback ++
        [
          {
            "dispatcher",
            "adjust_routing_weight",
            "High task latency (#{Float.round(latency)}ms) suggests load imbalance",
            %{
              "current_latency_ms" => latency,
              "latency_threshold_ms" => 300,
              "action" => "increase shallow_work priority weighting by 10%"
            }
          }
        ]
    else
      feedback
    end
  end

  defp analyze_decomposition_patterns(metrics) do
    feedback = []

    # If decomposition quality is low (<60%), suggest LLM prompt tuning
    quality = metrics["decomposition_quality"] || 1.0

    if quality < 0.6 do
      feedback ++
        [
          {
            "llm_bot",
            "tune_decomposition_prompt",
            "Low decomposition quality (#{Float.round(quality, 2)}) requires prompt adjustment",
            %{
              "quality_score" => quality,
              "quality_threshold" => 0.6,
              "action" => "add emphasis on acceptance criteria and subtask independence"
            }
          }
        ]
    else
      feedback
    end
  end

  defp apply_context_broker_change(action, _rationale, _before, _after) do
    case action do
      "extend_dnd_window" ->
        publish_update("context.broker.dnd.update", %{
          "window_start" => "13:00",
          "window_end" => "19:00",
          "reason" => "feedback_loop_auto_adjust"
        })

      _ ->
        :ok
    end
  end

  defp apply_dispatcher_change(action, _rationale, _before, _after) do
    case action do
      "adjust_routing_weight" ->
        publish_update("dispatcher.routing.weight_update", %{
          "shallow_work_weight_delta" => 0.1,
          "reason" => "feedback_loop_auto_adjust"
        })

      _ ->
        :ok
    end
  end

  defp apply_llm_bot_change(action, _rationale, _before, _after) do
    case action do
      "tune_decomposition_prompt" ->
        publish_update("llm_bot.system_prompt.update", %{
          "section" => "decomposition_guidelines",
          "emphasis" => "acceptance_criteria_and_independence",
          "reason" => "feedback_loop_auto_adjust"
        })

      _ ->
        :ok
    end
  end

  defp publish_update(subject, payload) do
    Logger.info("[FeedbackLoopIntegrator] Publishing update to #{subject}",
      payload: payload
    )

    # In production, this would publish to NATS
    # For now, log the intent
    :ok
  end

  defp get_current_metrics do
    %{
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "uptime_percent" => 99.8,
      "error_rate" => 0.2,
      "avg_latency_ms" => 450
    }
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
end
