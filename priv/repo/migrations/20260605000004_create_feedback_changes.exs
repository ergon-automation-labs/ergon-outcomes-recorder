defmodule BotArmyOutcomesRecorder.Repo.Migrations.CreateFeedbackChanges do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:feedback_changes, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:component, :string, null: false)
      add(:action, :string, null: false)
      add(:rationale, :text)
      add(:before_metrics, :map)
      add(:after_metrics, :map)
      add(:timestamp, :utc_datetime)

      timestamps()
    end

    create_if_not_exists(index(:feedback_changes, [:component, :timestamp]))
    create_if_not_exists(index(:feedback_changes, [:timestamp]))
  end
end
