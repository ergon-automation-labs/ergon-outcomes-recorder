defmodule BotArmyOutcomesRecorder.NATS.Consumer do
  use GenServer
  require Logger

  alias BotArmyOutcomesRecorder.Repo
  alias BotArmyOutcomesRecorder.Schemas.OutcomesEvent

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{subscriptions: []}, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subscribe, state) do
    topics = [
      "outcomes.task.>",
      "outcomes.decomposition.>",
      "outcomes.context.>",
      "outcomes.notification.>",
      "outcomes.learning.>",
      "outcomes.bridge.>",
      "system.health.>"
    ]

    Logger.info("Starting NATS subscriptions for outcomes_recorder", topics: topics)

    try do
      subscriptions =
        Enum.map(topics, fn topic ->
          {:ok, sub} = Gnat.sub(:nats_connection, self(), topic)
          {topic, sub}
        end)

      {:noreply, %{state | subscriptions: subscriptions}}
    rescue
      e ->
        Logger.warning("Failed to subscribe to NATS topics, retrying in 5s", error: inspect(e))
        Process.send_after(self(), :subscribe_retry, 5000)
        {:noreply, state}
    end
  end

  def handle_info(:subscribe_retry, state) do
    send(self(), {:continue, :subscribe})
    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{body: body, topic: topic}}, state) do
    Task.start(fn -> process_event(body, topic) end)
    {:noreply, state}
  end

  defp process_event(body, topic) do
    case Jason.decode(body) do
      {:ok, data} ->
        event = %OutcomesEvent{
          event_type: parse_event_type(topic),
          bot_name: extract_bot_name(data),
          value: data["value"],
          metric_name: data["metric_name"] || extract_metric_from_topic(topic),
          metadata: extract_metadata(data)
        }

        case Repo.insert(event) do
          {:ok, _} ->
            Logger.debug("Recorded outcomes event", event_type: event.event_type, topic: topic)

          {:error, reason} ->
            Logger.warning("Failed to record outcomes event", reason: reason, topic: topic)
        end

      {:error, reason} ->
        Logger.warning("Failed to decode outcomes event", reason: reason, topic: topic)
    end
  end

  defp parse_event_type(topic) do
    topic
    |> String.split(".")
    |> Enum.take(3)
    |> Enum.join(".")
  end

  defp extract_bot_name(data) do
    data["bot_name"] || data["source"]
  end

  defp extract_metric_from_topic(topic) do
    topic
    |> String.split(".")
    |> Enum.drop(1)
    |> Enum.join("_")
  end

  defp extract_metadata(data) do
    Map.drop(data, ["value", "metric_name", "bot_name", "source"])
  end
end
