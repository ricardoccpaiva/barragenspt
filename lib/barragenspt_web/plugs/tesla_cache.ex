defmodule Tesla.Middleware.Cache do
  use Nebulex.Caching

  @behaviour Tesla.Middleware

  def call(env, next, ttl: ttl) do
    env
    |> get_from_cache(env.method)
    |> run(next)
    |> set_to_cache(ttl)
  end

  defp get_from_cache(env, :get) do
    {Barragenspt.Cache.get(cache_key(env)), env}
  end

  defp get_from_cache(env, _), do: {nil, env}

  defp run({nil, env}, next) do
    {:ok, env} = Tesla.run(env, next)
    {:miss, env}
  end

  defp run({cached_env, _env}, _next) do
    {:hit, cached_env}
  end

  defp set_to_cache({:miss, %Tesla.Env{status: status} = env}, ttl) when status == 200 do
    Barragenspt.Cache.put(cache_key(env), env, ttl: ttl)
    {:ok, env}
  end

  defp set_to_cache({:miss, env}, _ttl), do: {:ok, env}
  defp set_to_cache({:hit, env}, _ttl), do: {:ok, env}

  defp cache_key(%Tesla.Env{url: url, query: query}), do: Tesla.build_url(url, query)
end
