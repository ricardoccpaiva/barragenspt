defmodule Barragenspt.ApiUsage.EtsHolder do
  @moduledoc false
  use GenServer

  @table :barragenspt_api_usage_counters

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    _ =
      :ets.new(@table, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{}}
  end
end
