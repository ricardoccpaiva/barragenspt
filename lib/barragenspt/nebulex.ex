defmodule Barragenspt.Cache do
  use Nebulex.Cache,
    otp_app: :barragenspt,
    adapter: Nebulex.Adapters.Local
end

defmodule Barragenspt.MeteoDataCache do
  use Nebulex.Cache,
    otp_app: :barragenspt,
    adapter: Nebulex.Adapters.Local
end

defmodule Barragenspt.RealtimeDataPointsCache do
  use Nebulex.Cache,
    otp_app: :barragenspt,
    adapter: Nebulex.Adapters.Local
end

defmodule Barragenspt.ApiTokenCache do
  @moduledoc """
  Short-lived cache for resolved API bearer tokens. Separate from `Barragenspt.Cache`, which
  is flushed by hydrometrics ingestion jobs.
  """
  use Nebulex.Cache,
    otp_app: :barragenspt,
    adapter: Nebulex.Adapters.Local
end
