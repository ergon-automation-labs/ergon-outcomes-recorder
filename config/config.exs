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
  backends: [:console],
  default_formatter: {BotArmyRuntime.LoggerFormatter, []}

config :logger, :console,
  format: {BotArmyRuntime.LoggerFormatter, []},
  metadata: [:correlation_id]