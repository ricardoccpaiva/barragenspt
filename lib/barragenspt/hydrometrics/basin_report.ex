defmodule Barragenspt.Hydrometrics.BasinReport do
  @moduledoc """
  Aggregates compact hydro facts for a basin over a time window (UTC) for use in LLM prompts:

  - `:week` — últimos 7 dias corridos
  - `:month` — últimos 30 dias corridos
  - `:months_3` — últimos 3 meses (deslocamento calendarial com `Timex.shift/2`)
  - `:months_6` — últimos 6 meses (idem)

  Optional `compare_homologous: true` adds the same interval shifted back one calendar year (via `Timex.shift(..., years: -1)`).

  Optional `compare_previous_period: true` adds the immediately preceding window of the same length (e.g. for the last 7 days, the 7 days before that). Only one of the compare options should be `true`; if both are set, homologous wins.

  All `param_name` values present in the window are included in per-dam summaries (single DB aggregation
  without filtering by parameter). An additional query derives daily storage as % of total capacity only
  for `volume_last_hour` (same semantics as the rest of the app).
  """

  import Ecto.Query

  alias Barragenspt.Models.Hydrometrics.{Dam, DataPoint}
  alias Barragenspt.Repo

  @type period :: :week | :month | :months_3 | :months_6

  @volume_param "volume_last_hour"

  # Sentinel value for `summarize/3` first argument: agrega todas as bacias ao nível da bacia (sem detalhe por barragem).
  @all_basins_sentinel "__ALL_BASINS__"

  @doc """
  Valor do parâmetro `basin` em `summarize/3` para o relatório de todas as bacias (síntese agregada por bacia).
  """
  def all_basins_option_value, do: @all_basins_sentinel

  @doc """
  Returns `{:ok, summary}` or `{:error, reason}`.

  Options:
  - `:compare_homologous` — `true` to include facts for the same window one year earlier (UTC naive shift).
  - `:compare_previous_period` — `true` to include facts for the same-length window immediately before the main window (UTC).

  Pass `basin: all_basins_option_value/0` for a national brief: one block per hydrographic basin (parameters and
  storage aggregated across dams in that basin), without per-dam or river detail.

  Reasons: `:invalid_basin`, `:no_dams_in_basin`, `:no_hydro_data_in_window`.
  """
  @spec summarize(String.t(), period(), keyword()) ::
          {:ok, map()} | {:error, :invalid_basin | :no_dams_in_basin | :no_hydro_data_in_window}
  def summarize(basin, period, opts \\ []) when period in [:week, :month, :months_3, :months_6] do
    basin = if is_binary(basin), do: String.trim(basin), else: ""

    cond do
      basin == @all_basins_sentinel ->
        summarize_all_basins_aggregated(period, opts)

      basin == "" ->
        {:error, :invalid_basin}

      true ->
        summarize_single_basin(basin, period, opts)
    end
  end

  defp summarize_single_basin(basin, period, opts) do
    compare_mode = compare_mode_from_opts(opts)

    dams =
      from(d in Dam,
        where: d.basin == ^basin,
        order_by: [asc: d.name],
        select: %{site_id: d.site_id, name: d.name, total_capacity: d.total_capacity}
      )
      |> Repo.all()

    case dams do
      [] ->
        {:error, :no_dams_in_basin}

      dams ->
        {start_at, end_at, window_label} = window_bounds(period)
        site_ids = Enum.map(dams, & &1.site_id)

        case build_dams_out(dams, site_ids, start_at, end_at) do
          {:error, :no_hydro_data_in_window} ->
            {:error, :no_hydro_data_in_window}

          {:ok, dams_out} ->
            summary = %{
              scope: :single_basin,
              basin: basin,
              period: period,
              window_utc: %{start: start_at, end: end_at, label: window_label},
              dam_count: length(dams),
              basin_count: 1,
              dams: dams_out,
              compare_homologous: compare_mode == :homologous,
              compare_previous_period: compare_mode == :previous
            }

            summary =
              case compare_mode do
                :homologous ->
                  {h_start, h_end, h_label} = homologous_window_bounds(start_at, end_at)

                  homologous_piece =
                    case build_dams_out(dams, site_ids, h_start, h_end) do
                      {:ok, h_dams} ->
                        %{
                          homologous_window_utc: %{start: h_start, end: h_end, label: h_label},
                          homologous_dams: h_dams,
                          homologous_has_data: true
                        }

                      {:error, :no_hydro_data_in_window} ->
                        %{
                          homologous_window_utc: %{start: h_start, end: h_end, label: h_label},
                          homologous_dams: [],
                          homologous_has_data: false
                        }
                    end

                  Map.merge(summary, homologous_piece)

                :previous ->
                  {p_start, p_end, p_label} = previous_window_bounds(start_at, end_at)

                  previous_piece =
                    case build_dams_out(dams, site_ids, p_start, p_end) do
                      {:ok, p_dams} ->
                        %{
                          previous_window_utc: %{start: p_start, end: p_end, label: p_label},
                          previous_dams: p_dams,
                          previous_has_data: true
                        }

                      {:error, :no_hydro_data_in_window} ->
                        %{
                          previous_window_utc: %{start: p_start, end: p_end, label: p_label},
                          previous_dams: [],
                          previous_has_data: false
                        }
                    end

                  Map.merge(summary, previous_piece)

                :none ->
                  summary
              end

            {:ok, summary}
        end
    end
  end

  defp summarize_all_basins_aggregated(period, opts) do
    compare_mode = compare_mode_from_opts(opts)
    {start_at, end_at, window_label} = window_bounds(period)

    basins_main = build_basin_aggregate_rows(start_at, end_at)

    if not Enum.any?(basins_main, & &1.has_hydro_data) do
      {:error, :no_hydro_data_in_window}
    else
      total_dams = Enum.sum(Enum.map(basins_main, & &1.dam_count))

      summary = %{
        scope: :all_basins,
        basin: nil,
        period: period,
        window_utc: %{start: start_at, end: end_at, label: window_label},
        dam_count: total_dams,
        basin_count: length(basins_main),
        basins: basins_main,
        compare_homologous: compare_mode == :homologous,
        compare_previous_period: compare_mode == :previous
      }

      summary =
        case compare_mode do
          :homologous ->
            {h_start, h_end, h_label} = homologous_window_bounds(start_at, end_at)
            h_basins = build_basin_aggregate_rows(h_start, h_end)

            Map.merge(summary, %{
              homologous_window_utc: %{start: h_start, end: h_end, label: h_label},
              homologous_basins: h_basins,
              homologous_has_data: Enum.any?(h_basins, & &1.has_hydro_data)
            })

          :previous ->
            {p_start, p_end, p_label} = previous_window_bounds(start_at, end_at)
            p_basins = build_basin_aggregate_rows(p_start, p_end)

            Map.merge(summary, %{
              previous_window_utc: %{start: p_start, end: p_end, label: p_label},
              previous_basins: p_basins,
              previous_has_data: Enum.any?(p_basins, & &1.has_hydro_data)
            })

          :none ->
            summary
        end

      {:ok, summary}
    end
  end

  @doc """
  Builds the user message block with tabular facts for the model (Portuguese labels).
  """
  @spec facts_blob(map()) :: String.t()
  def facts_blob(%{scope: :all_basins} = summary) do
    main = facts_blob_all_basins_current(summary)

    cond do
      Map.get(summary, :compare_homologous, false) ->
        main <> "\n\n" <> facts_blob_all_basins_homologous(summary)

      Map.get(summary, :compare_previous_period, false) ->
        main <> "\n\n" <> facts_blob_all_basins_previous(summary)

      true ->
        main
    end
  end

  def facts_blob(%{} = summary) do
    main = facts_blob_current_window(summary)

    cond do
      Map.get(summary, :compare_homologous, false) ->
        main <> "\n\n" <> facts_blob_homologous_window(summary)

      Map.get(summary, :compare_previous_period, false) ->
        main <> "\n\n" <> facts_blob_previous_window(summary)

      true ->
        main
    end
  end

  defp facts_blob_all_basins_current(summary) do
    %{window_utc: w, basins: basins, dam_count: total_dams, basin_count: n_basins} = summary

    intro = """
    === Panorama nacional (todas as bacias, agregado por bacia) ===
    Janela (período analisado): #{w.label}
    Número de bacias hidrográficas (com barragens registadas): #{n_basins}
    Número total de barragens: #{total_dams}

    Os valores por parâmetro abaixo agregam todas as amostras da bacia na janela (min/méd/máx globais, sem detalhe por barragem ou rio).
    O armazenamento (%) usa somas diárias de volume_last_hour / capacidade total da bacia (mesma lógica que o detalhe por albufeira, agregada ao nível da bacia).

    """

    intro <> format_basin_aggregates_body(basins)
  end

  defp facts_blob_all_basins_homologous(summary) do
    w = summary.homologous_window_utc
    basins = Map.get(summary, :homologous_basins, [])

    intro = """
    === Período homólogo (ano anterior), agregado por bacia ===
    Janela: #{w.label}
    """

    cond do
      summary.homologous_has_data == false or basins == [] ->
        intro <> "Sem dados hidrométricos na base para este intervalo homólogo; indica isso na análise comparativa.\n"

      true ->
        intro <> "\n" <> format_basin_aggregates_body(basins)
    end
    |> String.trim()
  end

  defp facts_blob_all_basins_previous(summary) do
    w = summary.previous_window_utc
    basins = Map.get(summary, :previous_basins, [])

    intro = """
    === Período anterior imediato, agregado por bacia ===
    Janela: #{w.label}
    """

    cond do
      summary.previous_has_data == false or basins == [] ->
        intro <>
          "Sem dados hidrométricos na base para este intervalo anterior; indica isso na análise comparativa.\n"

      true ->
        intro <> "\n" <> format_basin_aggregates_body(basins)
    end
    |> String.trim()
  end

  defp format_basin_aggregates_body(basins) do
    basins
    |> Enum.map_join("\n\n", fn b ->
      base_header = "— Bacia: #{b.basin} (#{b.dam_count} barragens)"

      cond do
        not b.has_hydro_data ->
          "#{base_header}\n  Sem dados hidrométricos na janela para esta bacia."

        true ->
          params_block =
            b.param_summaries
            |> Enum.map_join("\n    ", fn p ->
              label =
                if p.param_name == @volume_param do
                  "#{p.param_name} (volume; ver também % capacidade abaixo)"
                else
                  p.param_name
                end

              "• #{label}: n=#{p.n} | mín #{fmt_num(p.v_min)} | méd #{fmt_num(p.v_avg)} | máx #{fmt_num(p.v_max)}"
            end)

          volume_line =
            if b.storage_days_with_data > 0 do
              """
              Armazenamento agregado na bacia (% da capacidade, #{@volume_param}, por dia): mín #{fmt(b.storage_pct_min)} | méd #{fmt(b.storage_pct_mean)} | máx #{fmt(b.storage_pct_max)}
              Primeiro dia: #{fmt_day(b.storage_first_day)} → #{fmt(b.storage_first_pct)}%
              Último dia: #{fmt_day(b.storage_last_day)} → #{fmt(b.storage_last_pct)}%
              Dias com dado de volume: #{b.storage_days_with_data}
              """
              |> String.trim()
            else
              "Sem dados de #{@volume_param} nesta janela para calcular % da capacidade ao nível da bacia."
            end

          """
          #{base_header}
            Parâmetros (agregados na bacia):
              #{params_block}
            #{volume_line}
          """
          |> String.trim()
      end
    end)
  end

  defp facts_blob_current_window(summary) do
    %{
      basin: basin,
      window_utc: w,
      dam_count: n,
      dams: dams
    } = summary

    header = """
    Bacia hidrográfica: #{basin}
    Janela (período analisado): #{w.label}
    Número de barragens na bacia: #{n}
    """

    body =
      dams
      |> Enum.map_join("\n\n", fn d ->
        params_block =
          d.param_summaries
          |> Enum.map_join("\n    ", fn p ->
            label =
              if p.param_name == @volume_param do
                "#{p.param_name} (volume; ver também % capacidade abaixo)"
              else
                p.param_name
              end

            "• #{label}: n=#{p.n} | mín #{fmt_num(p.v_min)} | méd #{fmt_num(p.v_avg)} | máx #{fmt_num(p.v_max)}"
          end)

        volume_line =
          if d.storage_days_with_data > 0 do
            """
            Armazenamento (% da capacidade, só #{@volume_param}, agregado por dia): mín #{fmt(d.storage_pct_min)} | méd #{fmt(d.storage_pct_mean)} | máx #{fmt(d.storage_pct_max)}
            Primeiro dia: #{fmt_day(d.storage_first_day)} → #{fmt(d.storage_first_pct)}%
            Último dia: #{fmt_day(d.storage_last_day)} → #{fmt(d.storage_last_pct)}%
            Dias com dado de volume: #{d.storage_days_with_data}
            """
            |> String.trim()
          else
            "Sem dados de #{@volume_param} nesta janela para calcular % da capacidade."
          end

        """
        — #{d.name} (site_id=#{d.site_id}, capacidade total #{d.total_capacity_m3} m³)
          Parâmetros (todos os tipos com amostras na janela):
            #{params_block}
          #{volume_line}
        """
        |> String.trim()
      end)

    (header <> "\n" <> body) |> String.trim()
  end

  defp facts_blob_homologous_window(summary) do
    w = summary.homologous_window_utc
    dams = Map.get(summary, :homologous_dams, [])

    intro = """
    === Período homólogo (ano anterior, para comparação) ===
    Janela: #{w.label}
    """

    if summary.homologous_has_data == false or dams == [] do
      intro <> "Sem dados hidrométricos na base para este intervalo homólogo; indica isso na análise comparativa.\n"
    else
      body =
        dams
        |> Enum.map_join("\n\n", fn d ->
          params_block =
            d.param_summaries
            |> Enum.map_join("\n    ", fn p ->
              label =
                if p.param_name == @volume_param do
                  "#{p.param_name} (volume; ver também % capacidade abaixo)"
                else
                  p.param_name
                end

              "• #{label}: n=#{p.n} | mín #{fmt_num(p.v_min)} | méd #{fmt_num(p.v_avg)} | máx #{fmt_num(p.v_max)}"
            end)

          volume_line =
            if d.storage_days_with_data > 0 do
              """
              Armazenamento (% da capacidade, só #{@volume_param}, agregado por dia): mín #{fmt(d.storage_pct_min)} | méd #{fmt(d.storage_pct_mean)} | máx #{fmt(d.storage_pct_max)}
              Primeiro dia: #{fmt_day(d.storage_first_day)} → #{fmt(d.storage_first_pct)}%
              Último dia: #{fmt_day(d.storage_last_day)} → #{fmt(d.storage_last_pct)}%
              Dias com dado de volume: #{d.storage_days_with_data}
              """
              |> String.trim()
            else
              "Sem dados de #{@volume_param} na janela homóloga para % da capacidade."
            end

          """
          — #{d.name} (site_id=#{d.site_id}, capacidade total #{d.total_capacity_m3} m³)
            Parâmetros (amostras na janela homóloga):
              #{params_block}
            #{volume_line}
          """
          |> String.trim()
        end)

      (intro <> "\n" <> body) |> String.trim()
    end
  end

  defp facts_blob_previous_window(summary) do
    w = summary.previous_window_utc
    dams = Map.get(summary, :previous_dams, [])

    intro = """
    === Período anterior imediato (mesma duração, antes da janela principal, para comparação) ===
    Janela: #{w.label}
    """

    if summary.previous_has_data == false or dams == [] do
      intro <>
        "Sem dados hidrométricos na base para este intervalo anterior; indica isso na análise comparativa.\n"
    else
      body =
        dams
        |> Enum.map_join("\n\n", fn d ->
          params_block =
            d.param_summaries
            |> Enum.map_join("\n    ", fn p ->
              label =
                if p.param_name == @volume_param do
                  "#{p.param_name} (volume; ver também % capacidade abaixo)"
                else
                  p.param_name
                end

              "• #{label}: n=#{p.n} | mín #{fmt_num(p.v_min)} | méd #{fmt_num(p.v_avg)} | máx #{fmt_num(p.v_max)}"
            end)

          volume_line =
            if d.storage_days_with_data > 0 do
              """
              Armazenamento (% da capacidade, só #{@volume_param}, agregado por dia): mín #{fmt(d.storage_pct_min)} | méd #{fmt(d.storage_pct_mean)} | máx #{fmt(d.storage_pct_max)}
              Primeiro dia: #{fmt_day(d.storage_first_day)} → #{fmt(d.storage_first_pct)}%
              Último dia: #{fmt_day(d.storage_last_day)} → #{fmt(d.storage_last_pct)}%
              Dias com dado de volume: #{d.storage_days_with_data}
              """
              |> String.trim()
            else
              "Sem dados de #{@volume_param} na janela anterior para % da capacidade."
            end

          """
          — #{d.name} (site_id=#{d.site_id}, capacidade total #{d.total_capacity_m3} m³)
            Parâmetros (amostras na janela anterior):
              #{params_block}
            #{volume_line}
          """
          |> String.trim()
        end)

      (intro <> "\n" <> body) |> String.trim()
    end
  end

  defp build_dams_out(dams, site_ids, start_at, end_at) do
    param_rows = all_param_stats_rows(site_ids, start_at, end_at)
    daily_volume = daily_volume_capacity_pct_rows(site_ids, start_at, end_at)

    if param_rows == [] do
      {:error, :no_hydro_data_in_window}
    else
      params_by_site =
        param_rows
        |> Enum.group_by(& &1.site_id, &param_row_to_summary/1)

      daily_by_site =
        daily_volume
        |> Enum.group_by(& &1.site_id)

      dams_out =
        Enum.map(dams, fn d ->
          param_summaries =
            params_by_site
            |> Map.get(d.site_id, [])
            |> Enum.sort_by(& &1.param_name)

          volume_days =
            daily_by_site
            |> Map.get(d.site_id, [])
            |> Enum.map(fn row ->
              %{date: row.date, storage_pct_of_capacity: ratio_to_pct_float(row.ratio)}
            end)
            |> Enum.sort_by(& &1.date, {:asc, Date})

          volume_stats = storage_stats_from_volume_days(volume_days)

          %{
            site_id: d.site_id,
            name: d.name,
            total_capacity_m3: d.total_capacity,
            param_summaries: param_summaries,
            volume_daily_pct: volume_days,
            storage_pct_min: volume_stats.storage_pct_min,
            storage_pct_max: volume_stats.storage_pct_max,
            storage_pct_mean: volume_stats.storage_pct_mean,
            storage_first_day: volume_stats.storage_first_day,
            storage_first_pct: volume_stats.storage_first_pct,
            storage_last_day: volume_stats.storage_last_day,
            storage_last_pct: volume_stats.storage_last_pct,
            storage_days_with_data: volume_stats.storage_days_with_data
          }
        end)

      {:ok, dams_out}
    end
  end

  defp param_row_to_summary(row) do
    %{
      param_name: row.param_name,
      n: row.n,
      v_min: decimal_to_float_or_nil(row.v_min),
      v_max: decimal_to_float_or_nil(row.v_max),
      v_avg: decimal_to_float_or_nil(row.v_avg)
    }
  end

  defp fmt_num(nil), do: "—"

  defp fmt_num(%Decimal{} = d),
    do: d |> Decimal.round(3) |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 3)

  defp fmt_num(n) when is_number(n), do: :erlang.float_to_binary(n * 1.0, decimals: 3)

  defp fmt(nil), do: "—"

  defp fmt(%Decimal{} = d),
    do: d |> Decimal.round(1) |> Decimal.to_float() |> :erlang.float_to_binary(decimals: 1)

  defp fmt(n) when is_number(n), do: :erlang.float_to_binary(n * 1.0, decimals: 1)

  defp fmt_day(nil), do: "—"
  defp fmt_day(%Date{} = dt), do: Date.to_iso8601(dt)
  defp fmt_day(dt), do: to_string(dt)

  defp storage_stats_from_volume_days([]) do
    %{
      storage_pct_min: nil,
      storage_pct_max: nil,
      storage_pct_mean: nil,
      storage_first_day: nil,
      storage_first_pct: nil,
      storage_last_day: nil,
      storage_last_pct: nil,
      storage_days_with_data: 0
    }
  end

  defp storage_stats_from_volume_days(days) do
    pcts = Enum.map(days, & &1.storage_pct_of_capacity) |> Enum.reject(&is_nil/1)

    mn = Enum.min(pcts, fn -> nil end)
    mx = Enum.max(pcts, fn -> nil end)
    mean = if pcts == [], do: nil, else: Enum.sum(pcts) / length(pcts)
    first = List.first(days)
    last = List.last(days)

    %{
      storage_pct_min: mn,
      storage_pct_max: mx,
      storage_pct_mean: mean,
      storage_first_day: first.date,
      storage_first_pct: first.storage_pct_of_capacity,
      storage_last_day: last.date,
      storage_last_pct: last.storage_pct_of_capacity,
      storage_days_with_data: length(days)
    }
  end

  defp decimal_to_float_or_nil(nil), do: nil
  defp decimal_to_float_or_nil(%Decimal{} = d), do: d |> Decimal.to_float()
  defp decimal_to_float_or_nil(n) when is_number(n), do: n * 1.0

  defp ratio_to_pct_float(nil), do: nil

  defp ratio_to_pct_float(%Decimal{} = ratio) do
    ratio |> Decimal.mult(100) |> Decimal.round(2) |> Decimal.to_float()
  end

  defp window_bounds(:week) do
    do_window_bounds(7, "últimos 7 dias")
  end

  defp window_bounds(:month) do
    do_window_bounds(30, "últimos 30 dias")
  end

  defp window_bounds(:months_3) do
    do_calendar_months_window_bounds(3, "últimos 3 meses")
  end

  defp window_bounds(:months_6) do
    do_calendar_months_window_bounds(6, "últimos 6 meses")
  end

  defp do_window_bounds(days, short_label) do
    end_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    start_at = NaiveDateTime.add(end_at, -days * 86_400, :second)

    full_label =
      "#{short_label} (UTC), de #{NaiveDateTime.to_iso8601(start_at)} a #{NaiveDateTime.to_iso8601(end_at)}"

    {start_at, end_at, full_label}
  end

  defp do_calendar_months_window_bounds(n_months, short_label) when n_months in [3, 6] do
    end_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    start_at = Timex.shift(end_at, months: -n_months)

    full_label =
      "#{short_label} (UTC), de #{NaiveDateTime.to_iso8601(start_at)} a #{NaiveDateTime.to_iso8601(end_at)}"

    {start_at, end_at, full_label}
  end

  defp compare_mode_from_opts(opts) do
    hom? = Keyword.get(opts, :compare_homologous, false)
    prev? = Keyword.get(opts, :compare_previous_period, false)

    cond do
      hom? -> :homologous
      prev? -> :previous
      true -> :none
    end
  end

  defp previous_window_bounds(start_at, end_at) do
    duration_secs = NaiveDateTime.diff(end_at, start_at, :second)
    prev_end = NaiveDateTime.add(start_at, -1, :second)
    prev_start = NaiveDateTime.add(prev_end, -duration_secs, :second)

    label =
      "mesma duração que o período analisado (UTC), imediatamente antes da janela principal, " <>
        "de #{NaiveDateTime.to_iso8601(prev_start)} a #{NaiveDateTime.to_iso8601(prev_end)}"

    {prev_start, prev_end, label}
  end

  defp homologous_window_bounds(start_at, end_at) do
    h_start = Timex.shift(start_at, years: -1)
    h_end = Timex.shift(end_at, years: -1)

    label =
      "mesmo número de dias e alinhamento calendarial que o período analisado, deslocado −1 ano (UTC), " <>
        "de #{NaiveDateTime.to_iso8601(h_start)} a #{NaiveDateTime.to_iso8601(h_end)}"

    {h_start, h_end, label}
  end

  defp all_param_stats_rows(site_ids, start_at, end_at) do
    from(dp in DataPoint,
      where:
        dp.site_id in ^site_ids and
          dp.colected_at >= ^start_at and
          dp.colected_at <= ^end_at,
      group_by: [dp.site_id, dp.param_name],
      select: %{
        site_id: dp.site_id,
        param_name: dp.param_name,
        n: count(dp.id),
        v_min: min(dp.value),
        v_max: max(dp.value),
        v_avg: avg(dp.value)
      }
    )
    |> Repo.all()
  end

  defp daily_volume_capacity_pct_rows(site_ids, start_at, end_at) do
    from(dp in DataPoint,
      join: d in Dam,
      on: d.site_id == dp.site_id,
      where:
        dp.param_name == ^@volume_param and
          dp.site_id in ^site_ids and
          dp.colected_at >= ^start_at and
          dp.colected_at <= ^end_at,
      group_by: [dp.site_id, fragment("DATE(?)", dp.colected_at)],
      select: %{
        site_id: dp.site_id,
        date: fragment("DATE(?)", dp.colected_at),
        ratio: sum(dp.value) / sum(d.total_capacity)
      }
    )
    |> Repo.all()
  end

  defp build_basin_aggregate_rows(start_at, end_at) do
    counts =
      from(d in Dam, group_by: d.basin, select: {d.basin, count(d.id)})
      |> Repo.all()
      |> Map.new()

    param_rows = all_param_stats_by_basin(start_at, end_at)
    daily_rows = daily_volume_capacity_pct_by_basin(start_at, end_at)
    params_by_basin = Enum.group_by(param_rows, & &1.basin)
    daily_by_basin = Enum.group_by(daily_rows, & &1.basin)

    counts
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(fn basin ->
      params =
        params_by_basin
        |> Map.get(basin, [])
        |> Enum.map(&basin_param_row_to_summary/1)
        |> Enum.sort_by(& &1.param_name)

      days =
        daily_by_basin
        |> Map.get(basin, [])
        |> Enum.map(fn row ->
          %{date: row.date, storage_pct_of_capacity: ratio_to_pct_float(row.ratio)}
        end)
        |> Enum.sort_by(& &1.date, {:asc, Date})

      st = storage_stats_from_volume_days(days)
      has_params = params != []
      has_storage = st.storage_days_with_data > 0

      %{
        basin: basin,
        dam_count: Map.fetch!(counts, basin),
        param_summaries: params,
        storage_pct_min: st.storage_pct_min,
        storage_pct_max: st.storage_pct_max,
        storage_pct_mean: st.storage_pct_mean,
        storage_first_day: st.storage_first_day,
        storage_first_pct: st.storage_first_pct,
        storage_last_day: st.storage_last_day,
        storage_last_pct: st.storage_last_pct,
        storage_days_with_data: st.storage_days_with_data,
        has_hydro_data: has_params or has_storage
      }
    end)
  end

  defp basin_param_row_to_summary(row) do
    %{
      param_name: row.param_name,
      n: row.n,
      v_min: decimal_to_float_or_nil(row.v_min),
      v_max: decimal_to_float_or_nil(row.v_max),
      v_avg: decimal_to_float_or_nil(row.v_avg)
    }
  end

  defp all_param_stats_by_basin(start_at, end_at) do
    from(dp in DataPoint,
      join: d in Dam,
      on: d.site_id == dp.site_id,
      where: dp.colected_at >= ^start_at and dp.colected_at <= ^end_at,
      group_by: [d.basin, dp.param_name],
      select: %{
        basin: d.basin,
        param_name: dp.param_name,
        n: count(dp.id),
        v_min: min(dp.value),
        v_max: max(dp.value),
        v_avg: avg(dp.value)
      }
    )
    |> Repo.all()
  end

  defp daily_volume_capacity_pct_by_basin(start_at, end_at) do
    from(dp in DataPoint,
      join: d in Dam,
      on: d.site_id == dp.site_id,
      where:
        dp.param_name == ^@volume_param and
          dp.colected_at >= ^start_at and
          dp.colected_at <= ^end_at,
      group_by: [d.basin, fragment("DATE(?)", dp.colected_at)],
      select: %{
        basin: d.basin,
        date: fragment("DATE(?)", dp.colected_at),
        ratio: sum(dp.value) / sum(d.total_capacity)
      }
    )
    |> Repo.all()
  end
end
