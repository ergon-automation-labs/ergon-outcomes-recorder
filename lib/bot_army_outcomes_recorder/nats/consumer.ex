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
    # Schedule first subscription attempt after 500ms to give NATS time to initialize
    Process.send_after(self(), :subscribe, 500)
    {:ok, %{subscriptions: [], retry_count: 0}}
  end

  def handle_info(:subscribe, state) do
    # First subscription attempt (called directly, not via continue)
    topics = [
      "outcomes.task.>",
      "outcomes.decomposition.>",
      "outcomes.context.>",
      "outcomes.notification.>",
      "outcomes.learning.>",
      "outcomes.bridge.>",
      "system.health.>"
    ]

    Logger.info("Starting NATS subscriptions for outcomes_recorder")

    subscriptions =
      Enum.reduce(topics, [], fn topic, acc ->
        case subscribe_to_topic(topic) do
          {:ok, sub} ->
            Logger.debug("Subscribed to #{topic}")
            [{topic, sub} | acc]

          {:error, reason} ->
            Logger.warning("Failed to subscribe to #{topic}: #{reason}")
            acc
        end
      end)

    if Enum.empty?(subscriptions) do
      Logger.warning("No NATS subscriptions succeeded, retrying in 2s")
      Process.send_after(self(), :subscribe_retry, 2000)
      {:noreply, state}
    else
      Logger.info("Successfully subscribed to #{length(subscriptions)} topics")
      {:noreply, %{state | subscriptions: subscriptions, retry_count: 0}}
    end
  end

  def handle_info(:subscribe_retry, state) do
    # Retry subscribing to any missing topics
    current_topics = state.subscriptions |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    all_topics = [
      "outcomes.task.>",
      "outcomes.decomposition.>",
      "outcomes.context.>",
      "outcomes.notification.>",
      "outcomes.learning.>",
      "outcomes.bridge.>",
      "system.health.>"
    ]

    missing_topics = Enum.reject(all_topics, &MapSet.member?(current_topics, &1))

    new_subs =
      Enum.reduce(missing_topics, state.subscriptions, fn topic, acc ->
        case subscribe_to_topic(topic) do
          {:ok, sub} ->
            Logger.info("Subscribed to #{topic} (retry)")
            [{topic, sub} | acc]

          {:error, _reason} ->
            acc
        end
      end)

    if Enum.count(new_subs) == Enum.count(state.subscriptions) do
      {:noreply, %{state | subscriptions: new_subs}}
    else
      Process.send_after(self(), :subscribe_retry, 2000)
      {:noreply, %{state | subscriptions: new_subs}}
    end
  end

  defp subscribe_to_topic(topic) do
    try do
      Gnat.sub(:nats_connection, self(), topic)
    rescue
      e ->
        Logger.debug("Exception subscribing to #{topic}: #{inspect(e)}")
        {:error, "NATS exception"}
    catch
      :exit, reason ->
        Logger.debug("Exit subscribing to #{topic}: #{inspect(reason)}")
        {:error, "NATS exit"}

      kind, reason ->
        Logger.debug("Caught #{kind} subscribing to #{topic}: #{inspect(reason)}")
        {:error, "NATS error"}
    end
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
