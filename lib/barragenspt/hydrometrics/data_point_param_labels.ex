defmodule Barragenspt.Hydrometrics.DataPointParamLabels do
  @moduledoc """
  Portuguese labels for `data_points.param_name` values (SNIRH-derived slugs).

  Unknown slugs are returned unchanged so ad-hoc or future parameters still display.
  """

  @labels %{
    "volume_last_hour" => "Volume armazenado na última hora (dam³)",
    "volume_last_day_month" => "Volume armazenado no último dia do mês (dam³)",
    "elevation_last_hour" => "Cota da albufeira na última hora (m)",
    "ouput_flow_rate_daily" => "Caudal descarregado médio diário (m³/s)",
    "tributary_daily_flow" => "Caudal afluente médio diário (m³/s)",
    "effluent_daily_flow" => "Caudal efluente médio diário (m³/s)",
    "turbocharged_daily_flow" => "Caudal turbinado médio diário (m³/s)",
    "volume" => "Volume armazenado (dam³)",
    "elevation" => "Cota da albufeira (m)"
  }

  @doc "Returns the display label for a stored `param_name`, or the slug if unknown."
  @spec label(String.t() | nil) :: String.t()
  def label(nil), do: "—"

  def label(slug) when is_binary(slug) do
    Map.get(@labels, slug, slug)
  end
end
