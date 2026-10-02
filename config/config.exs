import Config

config :bot_army_outcomes_recorder, BotArmyOutcomesRecorder.Repo,
  database: "bot_army_outcomes_recorder",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 35432,
  show_sensitive_data_on_error: true,
  pool_size: 5

config :logger,
  level: :info,
  backends: [:console]

config :logger, :console,
  format: "[$time] [$level] $message\n",
  # Every key the bot actually passes to Logger. credo's
  # MissedMetadataKeyInLoggerConfig check fails `make push` for undeclared keys, and
  # the format above renders none of them, so declaring them costs nothing.
  metadata: [
    :correlation_id,
    :action,
    :change_id,
    :component,
    :date,
    :error,
    :event,
    :event_type,
    :metric,
    :month,
    :payload,
    :reason,
    :status,
    :topic,
    :year
  ]