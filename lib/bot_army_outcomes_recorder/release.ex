defmodule BotArmyOutcomesRecorder.Release do
  @moduledoc """
  Release tasks for the Outcomes Recorder bot.

  Migrations are run via the shared BotArmyRuntime.Ecto.MigrationRunner:

      /path/to/outcomes_recorder_bot/bin/outcomes_recorder_bot eval 'BotArmyOutcomesRecorder.Release.migrate()'

  Called from Salt during bot deployment, before the bot starts.
  """

  alias BotArmyRuntime.Ecto.MigrationRunner

  @app :bot_army_outcomes_recorder

  def migrate do
    MigrationRunner.run(
      repo_module: BotArmyOutcomesRecorder.Repo,
      app_module: @app
    )
  end
end
