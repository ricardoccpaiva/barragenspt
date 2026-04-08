defmodule Barragenspt.Accounts.UserApiToken do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @allowed_scopes ~w(dams basins data_points)
  @max_active_tokens_per_user 5

  schema "user_api_tokens" do
    field :token_digest, :binary
    field :token_prefix, :string
    field :scopes, {:array, :string}, default: []
    field :revoked_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec

    belongs_to :user, Barragenspt.Accounts.User

    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(token, attrs) do
    token
    |> cast(attrs, [:user_id, :token_digest, :token_prefix, :scopes, :revoked_at, :deleted_at])
    |> validate_required([:user_id, :token_digest, :token_prefix, :scopes])
    |> validate_scopes()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_scopes(changeset) do
    scopes = get_field(changeset, :scopes) || []

    cond do
      scopes == [] ->
        add_error(changeset, :scopes, "escolhe pelo menos um âmbito")

      length(scopes) > 3 ->
        add_error(changeset, :scopes, "no máximo 3 âmbitos")

      length(scopes) != length(Enum.uniq(scopes)) ->
        add_error(changeset, :scopes, "âmbitos duplicados")

      not Enum.all?(scopes, &(&1 in @allowed_scopes)) ->
        add_error(changeset, :scopes, "âmbito inválido")

      true ->
        changeset
    end
  end

  @doc """
  Allowed scope slugs for API tokens (`dams`, `basins`, `data_points`).
  """
  def allowed_scopes, do: @allowed_scopes

  @doc """
  Human-readable labels (PT) for each scope slug.
  """
  def scope_labels do
    %{
      "dams" => "Barragens",
      "basins" => "Bacias",
      "data_points" => "Pontos de dados"
    }
  end

  @doc false
  def max_active_per_user, do: @max_active_tokens_per_user

  def active?(%__MODULE__{revoked_at: nil}), do: true
  def active?(%__MODULE__{}), do: false

  @doc false
  def discarded?(%__MODULE__{deleted_at: nil}), do: false
  def discarded?(%__MODULE__{}), do: true
end
