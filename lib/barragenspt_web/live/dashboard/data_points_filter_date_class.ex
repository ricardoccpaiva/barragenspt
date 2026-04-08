defmodule BarragensptWeb.DataPointsFilterDateClass do
  @moduledoc false

  @doc "Shared Tailwind for data-points date inputs (matches custom dropdown chrome)."
  @spec class :: String.t()
  def class do
    "block w-full min-w-0 cursor-pointer rounded-md border border-slate-300 bg-white px-3 py-2 text-left text-[13px] text-slate-900 shadow-sm ring-brand-500 hover:border-slate-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:hover:border-slate-500 dark:[color-scheme:dark]"
  end
end
