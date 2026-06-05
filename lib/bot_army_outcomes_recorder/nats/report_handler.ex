defmodule BotArmyOutcomesRecorder.NATS.ReportHandler do
  @moduledoc """
  Handles incoming report requests and publishes responses via NATS.

  Subscribes to:
  - outcomes.report.weekly (request/reply) — generates weekly report

  This GenServer handles the request/reply pattern for report generation.
  """

  use GenServer
  require Logger

  alias BotArmyOutcomesRecorder.NATS.Responders.WeeklyReportResponder

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{subscriptions: []}, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subscribe, state) do
    Logger.info("[ReportHandler] Subscribing to report request subjects")

    # Subscribe to report request subjects (request/reply pattern)
    subjects = ["outcomes.report.weekly"]

    subscriptions =
      Enum.map(subjects, fn subject ->
        {:ok, sub} = Gnat.sub(:nats_connection, self(), subject)
        {subject, sub}
      end)

    {:noreply, %{state | subscriptions: subscriptions}}
  end

  @impl true
  def handle_info({:msg, %{body: body, reply_to: reply_to, topic: topic}}, state) do
    Task.start(fn -> handle_request(body, reply_to, topic) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{body: body, topic: topic}}, state) do
    Logger.debug("Received message without reply_to (pub/sub only)", topic: topic)
    {:noreply, state}
  end

  defp handle_request(body, reply_to, topic) do
    case Jason.decode(body) do
      {:ok, message} ->
        Logger.info("[ReportHandler] Processing report request", topic: topic)

        response =
          case topic do
            "outcomes.report.weekly" ->
              WeeklyReportResponder.handle_request(message)

            _ ->
              Jason.encode!(%{"ok" => false, "error" => "Unknown report type"})
          end

        case Gnat.pub(:nats_connection, reply_to, response) do
          :ok ->
            Logger.debug("[ReportHandler] Published report response")

          {:error, reason} ->
            Logger.warning("[ReportHandler] Failed to publish response", reason: reason)
        end

      {:error, reason} ->
        Logger.warning("[ReportHandler] Failed to decode request", reason: reason)
    end
  end
end
