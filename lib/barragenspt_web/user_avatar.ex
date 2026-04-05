defmodule BarragensptWeb.UserAvatar do
  @moduledoc """
  Resolves a display image URL for the navbar: stored Google `avatar_url`, else Gravatar identicon.
  """

  alias Barragenspt.Accounts.User

  @spec image_src(struct() | nil) :: String.t() | nil
  def image_src(%User{avatar_url: url}) when is_binary(url) and byte_size(url) > 0 do
    url
  end

  def image_src(%User{email: email}) when is_binary(email) and email != "" do
    gravatar_identicon_url(email)
  end

  def image_src(_), do: nil

  defp gravatar_identicon_url(email) do
    hash =
      email
      |> String.trim()
      |> String.downcase()
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)

    "https://www.gravatar.com/avatar/#{hash}?s=64&d=identicon&r=g"
  end
end
