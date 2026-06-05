import Config

# Database configuration from environment
database_url =
  System.get_env("DATABASE_URL") ||
    "ecto://postgres:postgres@localhost:35432/bot_army_outcomes_recorder"

config :bot_army_outcomes_recorder, BotArmyOutcomesRecorder.Repo,
  url: database_url,
  ssl: System.get_env("DATABASE_SSL") == "true",
  pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "5")),
  show_sensitive_data_on_error: System.get_env("SHOW_SENSITIVE_DATA", "false") == "true"

# NATS configuration from environment
nats_servers =
  System.get_env("NATS_SERVERS", "nats://localhost:4223")
  |> String.split(",")
  |> Enum.map(&String.trim/1)

config :gnat,
  servers: nats_servers,
  current_user: System.get_env("NATS_USER", ""),
  current_password: System.get_env("NATS_PASS", ""),
  seed: System.get_env("NATS_SEED", "")

# Logger configuration
log_level = System.get_env("LOG_LEVEL", "info") |> String.to_atom()

config :logger,
  level: log_level,
  backends: [:console]

# Outcomes recorder specific configuration
config :bot_army_outcomes_recorder,
  aggregation_interval_seconds:
    String.to_integer(System.get_env("AGGREGATION_INTERVAL_SECONDS", "3600")),
  anomaly_detection_enabled: System.get_env("ANOMALY_DETECTION_ENABLED", "true") == "true",
  deep_work_drop_threshold_pct:
    String.to_float(System.get_env("DEEP_WORK_DROP_THRESHOLD_PCT", "40.0"))
