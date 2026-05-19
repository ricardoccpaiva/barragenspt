defmodule Barragenspt.Hydrometrics.MonthlyStorageReportAi do
  @moduledoc """
  Builds an AI-ready summary from the monthly storage report output.
  """

  alias Barragenspt.Ai.Cerebras

  @dam3_per_hm3 1000

  @spec summarize(map()) :: {:ok, String.t()} | {:error, term()}
  def summarize(%{basins: basins, summary: summary} = report)
      when is_list(basins) and is_map(summary) do
    facts = facts_blob(report)

    Cerebras.chat_completion([
      %{role: "system", content: system_prompt()},
      %{role: "user", content: user_prompt(facts)}
    ])
  end

  def summarize(_), do: {:error, :invalid_report}

  @spec configured?() :: boolean()
  def configured?, do: Cerebras.configured?()

  defp system_prompt do
    """
    És um analista de recursos hídricos. Escreve em português europeu, com tom profissional, claro e conciso.
    Baseia-te apenas nos dados fornecidos. Não inventes valores, causas, datas nem contexto externo.
    Quando houver ausência de dados, diz explicitamente que não há dados suficientes.
    Usa Markdown simples com títulos `##`, listas curtas e negrito apenas quando acrescentar clareza.

    Objetivo:
    - resumir o estado mensal atual do armazenamento
    - destacar principais sinais positivos e negativos face ao mês anterior
    - identificar bacias e barragens em atenção
    - fechar com uma conclusão breve e operacional

    Não uses linguagem promocional. Não faças recomendações de segurança nem conclusões para além dos factos.
    """
    |> String.trim()
  end

  defp user_prompt(facts) do
    """
    Abaixo segue o output estruturado de um relatório mensal de armazenamento.
    Produz um sumário executivo legível para utilizadores do dashboard.

    #{facts}
    """
    |> String.trim()
  end

  defp facts_blob(report) do
    selected_scope =
      case Map.get(report, :selected_basin) do
        nil -> "Todas as bacias"
        basin -> basin
      end

    summary = report.summary
    basins = report.basins

    current =
      [
        "Âmbito: #{selected_scope}",
        "Mês de referência: #{format_month(report.report_month)}",
        "Bacias incluídas: #{report.basin_count}",
        "Barragens incluídas: #{report.dam_count}",
        "Armazenamento atual: #{format_pct(summary.current_pct)}",
        "Variação mensal: #{format_delta(summary.month_delta)}",
        "Diferença face à referência: #{format_delta(summary.reference_delta)}",
        "Volume estimado atual: #{format_volume(summary.current_volume)}",
        "Capacidade total considerada: #{format_volume(summary.total_capacity)}",
        "Bacias em atenção: #{summary.attention_count}"
      ]
      |> Enum.join("\n")

    basin_lines =
      basins
      |> Enum.map(fn basin ->
        "- #{basin.name}: atual #{format_pct(basin.current_pct)}, mês #{format_delta(basin.month_delta)}, referência #{format_delta(basin.reference_delta)}, volume #{format_volume(basin.current_volume)}, estado #{status_label(basin.status)}, barragens #{basin.dam_count}"
      end)
      |> Enum.join("\n")

    attention_basin_lines =
      basins
      |> Enum.filter(&(&1.status in [:alert, :low]))
      |> Enum.map(fn basin ->
        "- #{basin.name}: #{format_pct(basin.current_pct)} (#{status_label(basin.status)})"
      end)
      |> empty_fallback("- Nenhuma bacia em atenção.")

    dam_lines =
      basins
      |> Enum.flat_map(fn basin ->
        basin.dams
        |> Enum.filter(&(&1.status in [:alert, :low]))
        |> Enum.map(fn dam ->
          "- #{dam.name} (#{basin.name}): atual #{format_pct(dam.current_pct)}, mês #{format_delta(dam.month_delta)}, referência #{format_delta(dam.reference_delta)}, volume #{format_volume(dam.current_volume)}, #{format_river(dam.river)}"
        end)
      end)
      |> empty_fallback("- Nenhuma barragem em atenção.")

    strongest_positive =
      basins
      |> Enum.filter(&is_number(&1.month_delta))
      |> Enum.sort_by(& &1.month_delta, :desc)
      |> Enum.take(3)
      |> Enum.map(fn basin -> "- #{basin.name}: #{format_delta(basin.month_delta)}" end)
      |> empty_fallback("- Sem dados suficientes.")

    strongest_negative =
      basins
      |> Enum.filter(&is_number(&1.month_delta))
      |> Enum.sort_by(& &1.month_delta, :asc)
      |> Enum.take(3)
      |> Enum.map(fn basin -> "- #{basin.name}: #{format_delta(basin.month_delta)}" end)
      |> empty_fallback("- Sem dados suficientes.")

    [
      "## Resumo global",
      current,
      "## Síntese por bacia",
      basin_lines,
      "## Bacias em atenção",
      attention_basin_lines,
      "## Barragens em atenção",
      dam_lines,
      "## Maiores subidas mensais",
      strongest_positive,
      "## Maiores descidas mensais",
      strongest_negative
    ]
    |> Enum.join("\n\n")
  end

  defp empty_fallback([], fallback), do: fallback
  defp empty_fallback(items, _fallback), do: Enum.join(items, "\n")

  defp format_pct(nil), do: "n/d"
  defp format_pct(value), do: "#{format_number(value)}%"

  defp format_delta(nil), do: "n/d"
  defp format_delta(value) when value > 0, do: "+#{format_number(value)} p.p."
  defp format_delta(value), do: "#{format_number(value)} p.p."

  defp format_volume(nil), do: "n/d"
  defp format_volume(value), do: "#{format_number(value / @dam3_per_hm3)} hm³"

  defp format_river(nil), do: "Rio n/d"

  defp format_river(value) when is_binary(value) do
    river =
      value
      |> String.trim()
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map_join(" ", &capitalize_word/1)

    cond do
      river == "" -> "Rio n/d"
      String.match?(river, ~r/^Rio\b/u) -> river
      true -> "Rio #{river}"
    end
  end

  defp format_river(_), do: "Rio n/d"

  defp format_number(value) when is_number(value),
    do: :erlang.float_to_binary(value * 1.0, decimals: 1)

  defp format_month(%Date{} = value), do: Calendar.strftime(value, "%m/%Y")
  defp format_month(_), do: "n/d"

  defp status_label(:good), do: "acima de 70%"
  defp status_label(:normal), do: "entre 50% e 70%"
  defp status_label(:low), do: "abaixo de 50%"
  defp status_label(:alert), do: "em atenção"
  defp status_label(_), do: "sem dados"

  defp capitalize_word(<<first::binary-size(1), rest::binary>>) do
    String.upcase(first) <> rest
  end

  defp capitalize_word(""), do: ""
end
