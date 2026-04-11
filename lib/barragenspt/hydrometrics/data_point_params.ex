defmodule Barragenspt.Hydrometrics.DataPointParams do
  @moduledoc """
  Canonical SNIRH parameter ids, `data_points.param_name` slugs, Portuguese descriptions,
  and helpers for API, exports, dashboard, and ingestion workers.

  Unknown slugs passed to `label/1` are returned unchanged so ad-hoc parameters still display.
  """

  @catalog [
    %{id: 212_296_818, slug: "effluent_daily_flow", description: "Caudal efluente médio diário (m³/s)"},
    %{id: 1_629_599_726, slug: "elevation", description: "Cota da albufeira (m)"},
    %{id: 354_895_424, slug: "elevation_last_hour", description: "Cota da albufeira na última hora (m)"},
    %{id: 2284, slug: "ouput_flow_rate_daily", description: "Caudal descarregado médio diário (m³/s)"},
    %{id: 2279, slug: "tributary_daily_flow", description: "Caudal afluente médio diário (m³/s)"},
    %{id: 2282, slug: "turbocharged_daily_flow", description: "Caudal turbinado médio diário (m³/s)"},
    %{id: 1_629_599_798, slug: "volume", description: "Volume armazenado (dam³)"},
    %{id: 304_545_050, slug: "volume_last_day_month", description: "Volume armazenado no último dia do mês (dam³)"},
    %{id: 354_895_398, slug: "volume_last_hour", description: "Volume armazenado na última hora (dam³)"}
  ]

  @doc """
  All catalogued parameters in API order: `id`, `slug`, `description`.
  """
  def all, do: @catalog

  @doc """
  `{parameter_id, slug}` tuples for workers and ingestion.
  """
  def tuples do
    Enum.map(@catalog, fn %{id: id, slug: slug} -> {id, slug} end)
  end

  @doc "Display label for a stored `param_name` slug, or the slug if unknown."
  @spec label(String.t() | nil) :: String.t()
  def label(nil), do: "—"

  def label(slug) when is_binary(slug) do
    case Enum.find(@catalog, &(&1.slug == slug)) do
      nil -> slug
      %{description: d} -> d
    end
  end
end
