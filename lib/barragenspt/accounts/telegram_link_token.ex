defmodule Barragenspt.Accounts.TelegramLinkToken do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending linked expired)

  schema "telegram_link_tokens" do
    field :token, :string
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime_usec
    field :used_at, :utc_datetime_usec
    field :chat_id, :string

    belongs_to :user, Barragenspt.Accounts.User

    timestamps()
  end

  def changeset(link_token, attrs) do
    link_token
    |> cast(attrs, [:token, :status, :expires_at, :used_at, :chat_id, :user_id])
    |> validate_required([:token, :status, :expires_at, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end

  def generate_token do
    24
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
