defmodule BotArmyOutcomesRecorder.NATS.FeedbackChangeConsumer do
  @moduledoc """
  Consumes feedback change events and routes them to system components.

  Subscribes to outcomes.feedback.change topic and publishes configuration
  updates to:
  - context.broker.dnd.update
  - dispatcher.routing.weight_update
  - llm_bot.system_prompt.update
  """

  use GenServer
  require Logger

  alias BotArmyOutcomesRecorder.Feedback.FeedbackLoopIntegrator

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, gnat} = BotArmyRuntime.NATS.Connection.get()

    {:ok, _sub} =
      Gnat.sub(gnat, self(), "outcomes.feedback.change", queue_group: "feedback_consumers")

    Logger.info("[FeedbackChangeConsumer] Subscribed to outcomes.feedback.change")

    {:ok, %{gnat: gnat}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    try do
      payload = Jason.decode!(msg.body)
      route_feedback_change(payload, state.gnat)
    rescue
      e ->
        Logger.warning("[FeedbackChangeConsumer] Error decoding feedback change",
          error: inspect(e)
        )
    end

    {:noreply, state}
  end

  defp route_feedback_change(payload, gnat) do
    component = payload["component"]
    action = payload["action"]
    rationale = payload["rationale"] || ""

    case component do
      "context_broker" ->
        publish_context_broker_update(gnat, action, rationale, payload)

      "dispatcher" ->
        publish_dispatcher_update(gnat, action, rationale, payload)

      "llm_bot" ->
        publish_llm_bot_update(gnat, action, rationale, payload)

      _ ->
        Logger.warning("[FeedbackChangeConsumer] Unknown component",
          component: component
        )
    end
  end

  defp publish_context_broker_update(gnat, action, rationale, payload) do
    update = %{
      "action" => action,
      "rationale" => rationale,
      "config" => extract_config(payload),
      "applied_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Gnat.pub(gnat, "context.broker.dnd.update", Jason.encode!(update))

    Logger.info("[FeedbackChangeConsumer] Published context broker update",
      action: action
    )
  end

  defp publish_dispatcher_update(gnat, action, rationale, payload) do
    update = %{
      "action" => action,
      "rationale" => rationale,
      "config" => extract_config(payload),
      "applied_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Gnat.pub(gnat, "dispatcher.routing.weight_update", Jason.encode!(update))

    Logger.info("[FeedbackChangeConsumer] Published dispatcher update",
      action: action
    )
  end

  defp publish_llm_bot_update(gnat, action, rationale, payload) do
    update = %{
      "action" => action,
      "rationale" => rationale,
      "config" => extract_config(payload),
      "applied_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Gnat.pub(gnat, "llm_bot.system_prompt.update", Jason.encode!(update))

    Logger.info("[FeedbackChangeConsumer] Published LLM bot update",
      action: action
    )
  end

  defp extract_config(payload) do
    payload["proposed_metrics"] || payload["config"] || %{}
  end
end
