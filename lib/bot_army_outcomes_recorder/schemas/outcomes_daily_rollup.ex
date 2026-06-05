defmodule BotArmyOutcomesRecorder.Schemas.OutcomesDailyRollup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outcomes_daily_rollups" do
    field(:date, :date)
    field(:metric_name, :string)
    field(:value, :float)
    field(:value_previous_period, :float)
    field(:trend_pct, :float)
    field(:p50, :float)
    field(:p95, :float)
    field(:p99, :float)
    field(:segments, :map, default: %{})
    field(:is_anomaly, :boolean, default: false)
    field(:anomaly_reason, :string)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(rollup, attrs) do
    rollup
    |> cast(attrs, [
      :date,
      :metric_name,
      :value,
      :value_previous_period,
      :trend_pct,
      :p50,
      :p95,
      :p99,
      :segments,
      :is_anomaly,
      :anomaly_reason
    ])
    |> validate_required([:date, :metric_name])
    |> unique_constraint(:date_metric, name: "outcomes_daily_rollups_date_metric_index")
  end
end
