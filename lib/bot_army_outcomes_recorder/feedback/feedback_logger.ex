defmodule BotArmyOutcomesRecorder.Feedback.FeedbackLogger do
  @moduledoc """
  Logs feedback loop changes with before/after metrics.

  Writes JSONL entries tracking system configuration adjustments,
  their rationale, and impact metrics for auditability and learning.
  """

  require Logger

  alias BotArmyOutcomesRecorder.Repo
  alias BotArmyOutcomesRecorder.Schemas.FeedbackChange
  import Ecto.Query

  @doc """
  Log a feedback change with before/after metrics.
  """
  def log_change(component, action, rationale, before_metrics, after_metrics) do
    change = %FeedbackChange{
      id: Ecto.UUID.generate(),
      component: component,
      action: action,
      rationale: rationale,
      before_metrics: before_metrics,
      after_metrics: after_metrics,
      timestamp: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    case Repo.insert(change) do
      {:ok, inserted_change} ->
        Logger.info("[FeedbackLogger] Change logged",
          component: component,
          action: action,
          change_id: inserted_change.id
        )

        write_to_jsonl(inserted_change)
        {:ok, inserted_change}

      {:error, changeset} ->
        Logger.warning("[FeedbackLogger] Failed to log change",
          component: component,
          action: action,
          error: inspect(changeset)
        )

        {:error, changeset}
    end
  end

  @doc """
  Retrieve feedback change history for a component.
  """
  def get_change_history(component, limit \\ 20) do
    FeedbackChange
    |> where([c], c.component == ^component)
    |> order_by([c], desc: c.timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Summarize feedback changes over a time period.
  """
  def summarize_changes(start_date, end_date) do
    changes =
      FeedbackChange
      |> where([c], c.timestamp >= ^start_date and c.timestamp <= ^end_date)
      |> order_by([c], :component)
      |> Repo.all()

    changes
    |> Enum.group_by(& &1.component)
    |> Enum.into(%{}, fn {component, component_changes} ->
      {
        component,
        %{
          "change_count" => length(component_changes),
          "actions" => component_changes |> Enum.map(& &1.action) |> Enum.uniq(),
          "latest_change" => List.first(component_changes).timestamp
        }
      }
    end)
  end

  # Private helpers

  defp write_to_jsonl(change) do
    log_dir = "/var/log/bot_army"
    log_file = Path.join(log_dir, "feedback_changes.jsonl")

    entry = %{
      "timestamp" => change.timestamp |> DateTime.to_iso8601(),
      "change_id" => change.id,
      "component" => change.component,
      "action" => change.action,
      "rationale" => change.rationale,
      "before_metrics" => change.before_metrics,
      "after_metrics" => change.after_metrics
    }

    jsonl_line = Jason.encode!(entry) <> "\n"

    try do
      File.write(log_file, jsonl_line, [:append])
    rescue
      e ->
        Logger.warning("[FeedbackLogger] Failed to write to JSONL",
          error: inspect(e)
        )
    end
  end
end
