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

    subjects = ["outcomes.report.weekly"]

    subscriptions =
      Enum.reduce(subjects, [], fn subject, acc ->
        case subscribe_to_subject(subject) do
          {:ok, sub} ->
            Logger.debug("Subscribed to #{subject}")
            [{subject, sub} | acc]

          {:error, reason} ->
            Logger.warning("Failed to subscribe to #{subject}: #{reason}")
            acc
        end
      end)

    if Enum.empty?(subscriptions) do
      Logger.warning("[ReportHandler] Failed to subscribe, retrying in 2s")
      Process.send_after(self(), :subscribe_retry, 2000)
      {:noreply, state}
    else
      Logger.info("[ReportHandler] Successfully subscribed to #{length(subscriptions)} subjects")
      {:noreply, %{state | subscriptions: subscriptions}}
    end
  end

  def handle_info(:subscribe_retry, state) do
    current_subjects = state.subscriptions |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    all_subjects = ["outcomes.report.weekly"]
    missing_subjects = Enum.reject(all_subjects, &MapSet.member?(current_subjects, &1))

    new_subs =
      Enum.reduce(missing_subjects, state.subscriptions, fn subject, acc ->
        case subscribe_to_subject(subject) do
          {:ok, sub} ->
            Logger.info("[ReportHandler] Subscribed to #{subject} (retry)")
            [{subject, sub} | acc]

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

  defp subscribe_to_subject(subject) do
    try do
      Gnat.sub(:nats_connection, self(), subject)
    rescue
      e ->
        Logger.debug("Exception subscribing to #{subject}: #{inspect(e)}")
        {:error, "NATS exception"}
    catch
      :exit, reason ->
        Logger.debug("Exit subscribing to #{subject}: #{inspect(reason)}")
        {:error, "NATS exit"}

      kind, reason ->
        Logger.debug("Caught #{kind} subscribing to #{subject}: #{inspect(reason)}")
        {:error, "NATS error"}
    end
  end

  @impl true
  def handle_info({:msg, %{body: body, reply_to: reply_to, topic: topic}}, state) do
    Task.start(fn -> handle_request(body, reply_to, topic) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{topic: topic}}, state) do
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
