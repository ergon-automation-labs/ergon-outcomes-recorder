defmodule BotArmyOutcomesRecorder.Schemas.FeedbackChange do
  @moduledoc """
  Schema for tracking feedback loop configuration changes.

  Records when and why system components (context_broker, dispatcher, llm_bot)
  are automatically tuned based on outcomes analysis.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}

  schema "feedback_changes" do
    field(:component, :string)
    field(:action, :string)
    field(:rationale, :string)
    field(:before_metrics, :map)
    field(:after_metrics, :map)
    field(:timestamp, :utc_datetime)

    timestamps()
  end

  def changeset(change, attrs) do
    change
    |> cast(attrs, [:component, :action, :rationale, :before_metrics, :after_metrics, :timestamp])
    |> validate_required([:component, :action, :rationale])
  end
end
