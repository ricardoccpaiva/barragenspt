defmodule Barragenspt.Activity.UserActivityEvent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_activity_events" do
    field :event_type, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :user, Barragenspt.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :event_type, :metadata, :occurred_at])
    |> validate_required([:user_id, :event_type, :occurred_at])
    |> foreign_key_constraint(:user_id)
  end
end
