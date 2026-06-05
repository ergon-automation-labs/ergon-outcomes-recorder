defmodule BotArmyOutcomesRecorder.Schemas.OutcomesEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "outcomes_events" do
    field(:event_type, :string)
    field(:bot_name, :string)
    field(:value, :float)
    field(:metric_name, :string)
    field(:metadata, :map, default: %{})
    field(:recorded_at, :utc_datetime_usec)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :bot_name, :value, :metric_name, :metadata, :recorded_at])
    |> validate_required([:event_type, :metric_name])
  end
end
