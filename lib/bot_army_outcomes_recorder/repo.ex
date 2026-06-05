defmodule BotArmyOutcomesRecorder.Repo do
  use Ecto.Repo,
    otp_app: :bot_army_outcomes_recorder,
    adapter: Ecto.Adapters.Postgres
end
