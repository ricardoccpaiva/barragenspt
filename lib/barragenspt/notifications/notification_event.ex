defmodule Barragenspt.Notifications.NotificationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_events" do
    field :triggered_at, :utc_datetime_usec
    field :value_at_trigger, :float
    field :notified, :boolean, default: false
    field :notification_channels, {:array, :string}, default: []

    belongs_to :notification, Barragenspt.Notifications.UserNotification, foreign_key: :notification_id
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:triggered_at, :value_at_trigger, :notified, :notification_channels, :notification_id])
    |> validate_required([:triggered_at, :value_at_trigger, :notification_id])
    |> foreign_key_constraint(:notification_id)
  end
end
