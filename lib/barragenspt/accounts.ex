defmodule Barragenspt.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Barragenspt.Repo

  alias Barragenspt.Accounts.{User, UserToken, UserNotifier, TelegramLinkToken}

  @telegram_link_validity_in_minutes 10

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, NaiveDateTime) do
    NaiveDateTime.after?(ts, NaiveDateTime.utc_now() |> NaiveDateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Barragenspt.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Barragenspt.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for Telegram delivery settings.
  """
  def change_user_telegram_settings(user, attrs \\ %{}) do
    User.telegram_settings_changeset(user, attrs)
  end

  @doc """
  Updates Telegram delivery settings for the given user.
  """
  def update_user_telegram_settings(user, attrs) do
    user
    |> User.telegram_settings_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a short-lived token used to link a Telegram chat.
  """
  def create_telegram_link_token(%User{} = user) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, @telegram_link_validity_in_minutes * 60, :second)
    token = TelegramLinkToken.generate_token()

    Repo.transact(fn ->
      Repo.update_all(
        from(t in TelegramLinkToken, where: t.user_id == ^user.id and t.status == "pending"),
        set: [status: "expired"]
      )

      case %TelegramLinkToken{}
           |> TelegramLinkToken.changeset(%{
             token: token,
             status: "pending",
             expires_at: expires_at,
             user_id: user.id
           })
           |> Repo.insert() do
        {:ok, link_token} -> {:ok, link_token}
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns the latest pending Telegram link token for a user, if not expired.
  """
  def get_pending_telegram_link_token(%User{} = user) do
    now = DateTime.utc_now()

    case Repo.one(
           from(t in TelegramLinkToken,
             where: t.user_id == ^user.id and t.status == "pending" and t.expires_at > ^now,
             order_by: [desc: t.inserted_at],
             limit: 1
           )
         ) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  @doc """
  Gets a Telegram link token scoped to the given user.
  """
  def get_telegram_link_token_for_user(%User{} = user, token) when is_binary(token) do
    case Repo.get_by(TelegramLinkToken, user_id: user.id, token: token) do
      nil -> {:error, :not_found}
      link_token -> {:ok, link_token}
    end
  end

  @doc """
  Marks a Telegram link token as expired.
  """
  def expire_telegram_link_token(%TelegramLinkToken{} = link_token) do
    link_token
    |> TelegramLinkToken.changeset(%{status: "expired"})
    |> Repo.update()
  end

  @doc """
  Consumes a Telegram link token and links the chat id to the user.
  """
  def consume_telegram_link_token(token, chat_id)
      when is_binary(token) and is_binary(chat_id) do
    now = DateTime.utc_now()

    Repo.transact(fn ->
      case Repo.get_by(TelegramLinkToken, token: token) do
        nil ->
          Repo.rollback(:not_found)

        %TelegramLinkToken{} = link_token ->
          cond do
            link_token.status != "pending" ->
              Repo.rollback(:already_used)

            DateTime.compare(link_token.expires_at, now) != :gt ->
              _ = expire_telegram_link_token(link_token)
              Repo.rollback(:expired)

            true ->
              user = get_user!(link_token.user_id)

              with {:ok, _updated_user} <-
                     update_user_telegram_settings(user, %{
                       telegram_enabled: true,
                       telegram_chat_id: chat_id
                     }),
                   {:ok, updated_token} <-
                     link_token
                     |> TelegramLinkToken.changeset(%{
                       status: "linked",
                       used_at: now,
                       chat_id: chat_id
                     })
                     |> Repo.update() do
                {:ok, updated_token}
              else
                {:error, reason} -> Repo.rollback(reason)
              end
          end
      end
    end)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
