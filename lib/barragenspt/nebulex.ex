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
