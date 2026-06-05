defmodule BotArmyOutcomesRecorder.Repo.Migrations.CreateOutcomesTables do
  use Ecto.Migration

  def change do
    # outcomes_events table
    create_if_not_exists table(:outcomes_events, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:event_type, :string, null: false)
      add(:bot_name, :string)
      add(:value, :float)
      add(:metric_name, :string, null: false)
      add(:metadata, :jsonb, default: "{}")
      add(:recorded_at, :utc_datetime_usec, default: fragment("NOW()"))
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists(index(:outcomes_events, [:event_type, :recorded_at]))
    create_if_not_exists(index(:outcomes_events, [:bot_name, :recorded_at]))
    create_if_not_exists(index(:outcomes_events, [:metric_name, :recorded_at]))

    # outcomes_daily_rollups table
    create_if_not_exists table(:outcomes_daily_rollups, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:date, :date, null: false)
      add(:metric_name, :string, null: false)
      add(:value, :float)
      add(:value_previous_period, :float)
      add(:trend_pct, :float)
      add(:p50, :float)
      add(:p95, :float)
      add(:p99, :float)
      add(:segments, :jsonb, default: "{}")
      add(:is_anomaly, :boolean, default: false)
      add(:anomaly_reason, :string)
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists(
      unique_index(:outcomes_daily_rollups, [:date, :metric_name],
        name: "outcomes_daily_rollups_date_metric_index"
      )
    )

    create_if_not_exists(index(:outcomes_daily_rollups, [:date]))

    # outcomes_monthly_reports table
    create_if_not_exists table(:outcomes_monthly_reports, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:month, :date, null: false)
      add(:metrics, :jsonb, default: "{}")
      add(:narrative, :text)
      add(:top_wins, {:array, :jsonb}, default: [])
      add(:suggestions, {:array, :jsonb}, default: [])
      add(:agentic_alignment_score, :float)
      add(:alignment_trend_vs_last_month, :float)
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists(
      unique_index(:outcomes_monthly_reports, [:month],
        name: "outcomes_monthly_reports_month_index"
      )
    )

    create_if_not_exists(index(:outcomes_monthly_reports, [:month]))
  end
end
