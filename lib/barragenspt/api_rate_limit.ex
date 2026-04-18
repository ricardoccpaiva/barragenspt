defmodule Barragenspt.ApiRateLimit do
  @moduledoc """
  API rate limiting via [Hammer](https://github.com/ExHammer/hammer) ETS backend
  and a **fixed window** counter.

  Each `window_ms` interval allows at most `limit` hits per key. See
  `config :barragenspt, Barragenspt.ApiRateLimit`.
  """
  use Hammer, backend: :ets, algorithm: :fix_window

  @doc """
  Records one request for `key` in the current fixed window.

  Returns `{:allow, count}` or `{:deny, retry_after_ms}` until the window resets.
  """
  @spec hit(term()) :: {:allow, non_neg_integer()} | {:deny, non_neg_integer()}
  def hit(key) do
    {window_ms, limit} = limits()
    __MODULE__.hit(key, window_ms, limit, 1)
  end

  defp limits do
    opts = Application.get_env(:barragenspt, __MODULE__, [])

    {
      Keyword.get(opts, :window_ms, :timer.minutes(1)),
      Keyword.get(opts, :limit, 60)
    }
  end
end
