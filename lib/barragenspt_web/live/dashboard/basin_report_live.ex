defmodule BarragensptWeb.Dashboard.BasinReportLive do
  use BarragensptWeb, :live_view

  on_mount {BarragensptWeb.UserAuth, :require_authenticated}

  alias Barragenspt.Ai.Cerebras
  alias Barragenspt.Hydrometrics.{BasinReport, Dams}

  @impl true
  def mount(_params, _session, socket) do
    basins = Dams.list_data_points_filter_basins()

    selected_basin =
      if basins == [] do
        ""
      else
        BasinReport.all_basins_option_value()
      end

    {:ok,
     socket
     |> assign(:page_title, "Relatório IA por bacia")
     |> assign(:basins, basins)
     |> assign(:selected_basin, selected_basin)
     |> assign(:period, :week)
     |> assign(:compare_mode, :none)
     |> assign(:loading, false)
     |> assign(:report_text, nil)
     |> assign(:error_message, nil)
     |> assign(:report_gen, 0)
     |> assign(:cerebras_configured, Cerebras.configured?())}
  end

  @impl true
  def handle_event("generate", params, socket) do
    basin = params |> Map.get("basin", "") |> to_string() |> String.trim()
    period = parse_period_param(Map.get(params, "period", "week"), :week)

    mode =
      case Map.get(params, "compare") do
        "homologous" -> :homologous
        "previous" -> :previous
        _ -> :none
      end

    gen = socket.assigns.report_gen + 1

    parent = self()

    _ =
      Task.start(fn ->
        result = run_generation(basin, period, mode)
        send(parent, {:basin_report_done, gen, result})
      end)

    {:noreply,
     socket
     |> assign(:selected_basin, basin)
     |> assign(:period, period)
     |> assign(:compare_mode, mode)
     |> assign(:report_gen, gen)
     |> assign(:loading, true)
     |> assign(:error_message, nil)
     |> assign(:report_text, nil)}
  end

  @impl true
  def handle_info({:basin_report_done, gen, result}, socket) do
    if gen != socket.assigns.report_gen do
      {:noreply, socket}
    else
      case result do
        {:ok, text} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:report_text, text)
           |> assign(:error_message, nil)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:error_message, format_error(reason))}
      end
    end
  end

  defp parse_period_param(nil, fallback), do: fallback

  defp parse_period_param(value, _fallback) do
    case value |> to_string() |> String.trim() do
      "30" -> :month
      "3m" -> :months_3
      "6m" -> :months_6
      "month" -> :month
      "week" -> :week
      _ -> :week
    end
  end

  defp run_generation(basin, period, compare_mode)
       when compare_mode in [:none, :homologous, :previous] do
    opts =
      case compare_mode do
        :homologous -> [compare_homologous: true]
        :previous -> [compare_previous_period: true]
        :none -> []
      end

    with {:ok, summary} <- BasinReport.summarize(basin, period, opts),
         facts = BasinReport.facts_blob(summary),
         scope = Map.get(summary, :scope, :single_basin),
         user = user_prompt(facts, summary, compare_mode, scope),
         content = system_prompt(compare_mode, scope),
         {:ok, text} <-
           Cerebras.chat_completion([
             %{role: "system", content: content},
             %{role: "user", content: user}
           ]) do
      File.write!("dump_ai_reports/facts.txt", facts)
      File.write!("dump_ai_reports/scope.txt", to_string(scope))
      File.write!("dump_ai_reports/user.txt", user)
      File.write!("dump_ai_reports/content.txt", content)
      {:ok, text}
    else
      {:error, :cerebras_api_key_missing} -> {:error, :cerebras_api_key_missing}
      other -> other
    end
  end

  defp system_prompt(compare_mode, :single_basin) do
    case compare_mode do
      :none ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        Baseia-te apenas nos dados fornecidos no pedido. Os factos incluem vários tipos de parâmetro \
        (min/méd/máx e número de amostras na janela); respeita as unidades implícitas de cada nome de parâmetro. \
        A secção «Armazenamento (% da capacidade)» refere-se apenas a volume_last_hour face à capacidade total indicada. \
        Se faltar informação ou os dados forem esparsos, diz-o explicitamente. Não inventes valores nem datas. \
        Evita adjetivos excessivos. Formata a resposta em Markdown (títulos ##, listas, negrito quando útil). \
        Estrutura: contexto (bacia e período), situação por barragem quando os dados permitirem, e uma conclusão breve sobre o conjunto da bacia.
        """
        |> String.trim()

      :homologous ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        Baseia-te apenas nos dados fornecidos no pedido. Os factos incluem vários tipos de parâmetro \
        (min/méd/máx e número de amostras na janela); respeita as unidades implícitas de cada nome de parâmetro. \
        A secção «Armazenamento (% da capacidade)» refere-se apenas a volume_last_hour face à capacidade total indicada. \

        O utilizador pediu comparação com o período homólogo: nos factos há um bloco «Período homólogo (ano anterior)» \
        com as mesmas métricas agregadas para o intervalo equivalente no ano anterior (UTC). Deves incluir uma secção \
        dedicada à comparação ano‑corrente vs homóloga: por barragem (e globalmente, se fizer sentido), destaca evoluções \
        de armazenamento médio/mín/máx e dos parâmetros principais quando ambos os períodos têm dados; quando o homólogo \
        não tiver dados ou for muito escasso, indica essa limitação sem inventar valores. \
        Não extrapoles para fora dos intervalos indicados. Não inventes datas. \

        Formata em Markdown (títulos ##, listas, negrito). Evita adjetivos excessivos.
        """
        |> String.trim()

      :previous ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        Baseia-te apenas nos dados fornecidos no pedido. Os factos incluem vários tipos de parâmetro \
        (min/méd/máx e número de amostras na janela); respeita as unidades implícitas de cada nome de parâmetro. \
        A secção «Armazenamento (% da capacidade)» refere-se apenas a volume_last_hour face à capacidade total indicada. \

        O utilizador pediu comparação com o período anterior imediato: nos factos há um bloco «Período anterior imediato» \
        com as mesmas métricas agregadas para o intervalo de igual duração que antecede directamente a janela principal (UTC). \
        Inclui uma secção dedicada a período recente vs período anterior: por barragem (e globalmente, se fizer sentido), \
        destaca evoluções de armazenamento médio/mín/máx e dos parâmetros principais quando ambos os períodos têm dados; \
        quando o período anterior não tiver dados ou for muito escasso, indica essa limitação sem inventar valores. \
        Não extrapoles para fora dos intervalos indicados. Não inventes datas. \

        Formata em Markdown (títulos ##, listas, negrito). Evita adjetivos excessivos.
        """
        |> String.trim()
    end
  end

  defp system_prompt(compare_mode, :all_basins) do
    case compare_mode do
      :none ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        O pedido é um **panorama de todas as bacias**: os factos vêm **agregados ao nível de cada bacia hidrográfica** \
        (não há listagem de barragens nem de rios). Não inventes nomes de rios, afluentes ou albufeiras; não faças inferências \
        abaixo do nível da bacia. \

        Os factos incluem parâmetros com min/méd/máx e número de amostras na janela; respeita as unidades implícitas. \
        O armazenamento (% capacidade) agrega volume_last_hour ao nível da bacia na janela, como explicado no texto de factos. \
        Se uma bacia não tiver dados na janela, respeita essa indicação. Não inventes valores nem datas. \

        Estrutura sugerida: introdução à janela temporal; síntese **por bacia** onde houver dados; conclusões transversais \
        (comparação entre bacias só com base nos números). Markdown (títulos ##, listas, negrito). Tom profissional, sem adjetivos excessivos.
        """
        |> String.trim()

      :homologous ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        Panorama **multi-bacia** com dados **agregados por bacia** (sem barragens nem rios nos factos). \

        Há um segundo bloco com o **período homólogo (ano anterior)**, também agregado por bacia. Inclui uma secção clara \
        de comparação ano corrente vs homólogo **ao nível das bacias**; quando um período não tiver dados para uma bacia, \
        indica-o. Não inventes nomes de cursos de água nem detalhes sub-bacia. \

        Formata em Markdown (títulos ##, listas, negrito). Não extrapoles para fora dos intervalos indicados.
        """
        |> String.trim()

      :previous ->
        """
        És um analista de recursos hídricos. Escreve em português europeu, tom profissional e claro.
        Panorama **multi-bacia** com dados **agregados por bacia** (sem barragens nem rios nos factos). \

        Há um bloco com o **período anterior imediato** (mesma duração antes da janela principal), agregado por bacia. \
        Inclui secção de comparação **entre os dois intervalos ao nível das bacias**. Sem dados inventados ou nomes de rios. \

        Formata em Markdown (títulos ##, listas, negrito). Não extrapoles para fora dos intervalos indicados.
        """
        |> String.trim()
    end
  end

  defp user_prompt(facts, summary, compare_mode, scope) do
    prefix =
      case scope do
        :all_basins ->
          "Seguem factos agregados (UTC) para **todas as bacias**, ao nível de cada bacia (sem detalhe por barragem ou rio). Redige o relatório pedido.\n\n"

        _ ->
          "Seguem factos agregados (UTC) sobre várias barragens na bacia. Redige o relatório pedido.\n\n"
      end

    base_suffix =
      "\n\nRelembrar: o período analisado principal é o indicado em «Janela (período analisado)». " <>
        "Não extrapoles para fora desse intervalo"

    compare_suffix =
      case {compare_mode, scope} do
        {:homologous, :all_basins} ->
          "\n\nComparação homóloga: inclui secção «Comparação com o período homólogo» com síntese **por bacia** e conclusões apenas com base nos dois blocos de factos."

        {:homologous, _} ->
          "\n\nComparação homóloga: inclui secção explícita «Comparação com o período homólogo» com síntese por barragem e conclusões apenas com base nos dois blocos de factos."

        {:previous, :all_basins} ->
          "\n\nComparação com período anterior: inclui secção «Período analisado vs período anterior imediato» com síntese **por bacia** e conclusões apenas com base nos dois blocos de factos."

        {:previous, _} ->
          "\n\nComparação com período anterior: inclui secção explícita «Período analisado vs período anterior imediato» com síntese por barragem e conclusões apenas com base nos dois blocos de factos."

        {:none, _} ->
          ""
      end

    footer =
      case scope do
        :all_basins ->
          "\nBacias com barragens registadas: #{summary.basin_count}. Total de barragens: #{summary.dam_count}."

        _ ->
          "\nBarragens consideradas: #{summary.dam_count}."
      end

    prefix <>
      facts <>
      base_suffix <>
      compare_suffix <>
      footer
  end

  defp format_error(:invalid_basin), do: "Seleccione uma bacia válida."
  defp format_error(:no_dams_in_basin), do: "Não existem barragens registadas para essa bacia."

  defp format_error(:no_hydro_data_in_window),
    do: "Sem dados hidrométricos na janela escolhida para esta bacia."

  defp format_error(:cerebras_api_key_missing),
    do: "O serviço de IA não está configurado (chave API em falta)."

  defp format_error({:cerebras_http_error, status, body}),
    do: "Erro do serviço de IA (HTTP #{status}): #{inspect(body)}"

  defp format_error({:cerebras_transport, reason}),
    do: "Falha de rede ao contactar o serviço de IA: #{inspect(reason)}"

  defp format_error({:cerebras_unexpected_body, _}),
    do: "Resposta inesperada do serviço de IA."

  defp format_error(other),
    do: "Não foi possível concluir o relatório: #{inspect(other)}"
end
