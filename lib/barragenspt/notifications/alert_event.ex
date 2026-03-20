defmodule Barragenspt.Notifications.AlertEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alert_events" do
    field :triggered_at, :utc_datetime_usec
    field :value_at_trigger, :float
    field :notified, :boolean, default: false

    belongs_to :alert, Barragenspt.Notifications.UserAlert, foreign_key: :alert_id
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:triggered_at, :value_at_trigger, :notified, :alert_id])
    |> validate_required([:triggered_at, :value_at_trigger, :alert_id])
    |> foreign_key_constraint(:alert_id)
  end
end
