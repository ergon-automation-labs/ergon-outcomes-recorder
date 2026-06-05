defmodule BotArmyOutcomesRecorder.Schemas.OutcomesMonthlyReport do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outcomes_monthly_reports" do
    field(:month, :date)
    field(:metrics, :map, default: %{})
    field(:narrative, :string)
    field(:top_wins, {:array, :map}, default: [])
    field(:suggestions, {:array, :map}, default: [])
    field(:agentic_alignment_score, :float)
    field(:alignment_trend_vs_last_month, :float)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :month,
      :metrics,
      :narrative,
      :top_wins,
      :suggestions,
      :agentic_alignment_score,
      :alignment_trend_vs_last_month
    ])
    |> validate_required([:month])
    |> unique_constraint(:month, name: "outcomes_monthly_reports_month_index")
  end
end
