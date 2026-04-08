defmodule Barragenspt.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :avatar_url, :string
    field :email_notifications_enabled, :boolean, default: true
    field :telegram_chat_id, :string
    field :telegram_enabled, :boolean, default: false
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :authenticated_at, :naive_datetime, virtual: true

    has_many :user_api_tokens, Barragenspt.Accounts.UserApiToken

    timestamps()
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Barragenspt.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Updates `avatar_url` from Google OAuth (`info.image`).

  Invalid or non-Google HTTPS URLs are rejected; use `nil` to clear.
  """
  def avatar_url_changeset(user, attrs) do
    user
    |> cast(attrs, [:avatar_url])
    |> validate_google_avatar_url()
  end

  defp validate_google_avatar_url(changeset) do
    case get_change(changeset, :avatar_url) do
      nil ->
        changeset

      "" ->
        put_change(changeset, :avatar_url, nil)

      url when is_binary(url) ->
        trimmed = String.trim(url)

        if trimmed == "" do
          put_change(changeset, :avatar_url, nil)
        else
          if google_avatar_https_url?(trimmed) do
            put_change(changeset, :avatar_url, trimmed)
          else
            delete_change(changeset, :avatar_url)
          end
        end
    end
  end

  @doc false
  def google_oauth_registration_changeset(%__MODULE__{} = user, email, oauth_image_url)
      when is_binary(email) do
    cs =
      user
      |> email_changeset(%{email: email}, validate_unique: true)
      |> put_change(:confirmed_at, NaiveDateTime.utc_now(:second))

    case oauth_image_url |> to_string() |> String.trim() do
      "" ->
        cs

      url ->
        cs
        |> cast(%{avatar_url: url}, [:avatar_url])
        |> validate_google_avatar_url()
    end
  end

  @doc false
  def google_avatar_https_url?(url) when is_binary(url) do
    url = String.trim(url)

    case URI.parse(url) do
      %URI{scheme: "https", host: host} when is_binary(host) ->
        host = String.downcase(host)

        String.ends_with?(host, ".googleusercontent.com") or host == "googleusercontent.com"

      _ ->
        false
    end
  end

  def google_avatar_https_url?(_), do: false

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Changeset for Telegram delivery preferences.
  """
  def telegram_settings_changeset(user, attrs) do
    user
    |> cast(attrs, [:email_notifications_enabled, :telegram_enabled, :telegram_chat_id])
    |> update_change(:telegram_chat_id, &normalize_chat_id/1)
    |> validate_length(:telegram_chat_id, max: 64)
    |> validate_format(:telegram_chat_id, ~r/^-?\d+$/,
      message: "must be a numeric Telegram chat id"
    )
    |> validate_chat_id_if_enabled()
  end

  defp normalize_chat_id(nil), do: nil
  defp normalize_chat_id(v) when is_binary(v), do: v |> String.trim() |> blank_to_nil()
  defp normalize_chat_id(v), do: v |> to_string() |> String.trim() |> blank_to_nil()

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp validate_chat_id_if_enabled(changeset) do
    enabled? = get_field(changeset, :telegram_enabled)
    chat_id = get_field(changeset, :telegram_chat_id)

    if enabled? && is_nil(chat_id) do
      add_error(changeset, :telegram_chat_id, "can't be blank when Telegram is enabled")
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Barragenspt.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
