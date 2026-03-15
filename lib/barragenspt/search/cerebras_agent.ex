defmodule Barragenspt.Search.CerebrasAgent do
  @moduledoc """
  Cerebras API client for AI chat with tools.
  Handles chat completions with function calling, tool execution loop, and streaming.
  """

  require Logger

  @default_model "qwen-3-235b-a22b-instruct-2507"
  @max_tool_iterations 10

  @doc """
  Chat with the agent. Supports streaming via an optional callback.

  ## Options
  - `:stream` - if true, streams chunks to the callback
  - `:on_chunk` - callback `fn delta -> :ok` for each text chunk when streaming
  """
  def chat(messages, opts \\ []) do
    config = get_config()
    api_key = config[:api_key]

    if is_nil(api_key) or api_key == "" do
      {:error, "CEREBRAS_API_KEY not configured"}
    else
      tools = Barragenspt.Search.LLMTools.list_tools()
      chat_with_tools(messages, tools, config, opts, 0)
    end
  end

  defp get_config do
    defaults = [base_url: "https://api.cerebras.ai/v1", api_key: nil]
    Keyword.merge(defaults, Application.get_env(:barragenspt, :cerebras, []))
  end

  defp chat_with_tools(messages, tools, config, opts, iteration)
       when iteration >= @max_tool_iterations do
    # Prevent infinite loops
    Logger.warning("CerebrasAgent: max tool iterations (#{@max_tool_iterations}) reached")
    {:ok, "Limite de chamadas às ferramentas atingido. Por favor, reformule a pergunta."}
  end

  defp chat_with_tools(messages, tools, config, opts, iteration) do
    Logger.debug("CerebrasAgent: iteration #{iteration + 1}/#{@max_tool_iterations}")
    # Use non-streaming when tools may be called (simplifies tool_calls handling)
    stream? = false
    on_chunk = Keyword.get(opts, :on_chunk)

    body =
      %{
        model: @default_model,
        messages: build_messages(messages),
        tools: tools,
        tool_choice: "auto",
        stream: stream?,
        max_tokens: 2048
      }
      |> Jason.encode!()

    url = "#{config[:base_url]}/chat/completions"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]

    if stream? do
      stream_chat(url, headers, body, messages, tools, config, opts, iteration, on_chunk)
    else
      non_stream_chat(url, headers, body, messages, tools, config, opts, iteration)
    end
  end

  defp non_stream_chat(url, headers, body, messages, tools, config, opts, iteration) do
    case Req.post(url, body: body, headers: headers, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: resp}} ->
        handle_completion_response(resp, messages, tools, config, opts, iteration)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Cerebras API error: #{status} #{inspect(body)}")
        {:error, "Erro na API: #{status}"}

      {:error, reason} ->
        Logger.error("Cerebras request failed: #{inspect(reason)}")
        {:error, "Falha na ligação ao assistente."}
    end
  end

  defp stream_chat(url, headers, body, messages, tools, config, opts, iteration, on_chunk) do
    pid = self()

    stream_fn = fn
      {:data, chunk} when is_binary(chunk) ->
        # SSE format: "data: {...}\n\n"
        chunk
        |> String.split("\n")
        |> Enum.each(fn line ->
          if String.starts_with?(line, "data: ") do
            data = String.slice(line, 6..-1//1)

            if data != "[DONE]" do
              case Jason.decode(data) do
                {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}}
                when is_binary(content) ->
                  send(pid, {:chunk, content})

                {:ok, _} ->
                  :ok

                _ ->
                  :ok
              end
            end
          end
        end)

      {:done, _} ->
        send(pid, :stream_done)

      {:error, reason} ->
        send(pid, {:stream_error, reason})
    end

    Task.start(fn ->
      case Req.post(url,
             body: body,
             headers: headers,
             receive_timeout: 120_000,
             into: stream_fn
           ) do
        {:ok, _} -> :ok
        {:error, reason} -> send(pid, {:stream_error, reason})
      end
    end)

    collect_stream(pid, on_chunk, [])
  end

  defp collect_stream(pid, on_chunk, acc) do
    receive do
      {:chunk, delta} ->
        if on_chunk, do: on_chunk.(delta)
        collect_stream(pid, on_chunk, [delta | acc])

      :stream_done ->
        full_text = acc |> Enum.reverse() |> Enum.join("")
        {:ok, full_text}

      {:stream_error, reason} ->
        Logger.error("Cerebras stream error: #{inspect(reason)}")
        {:error, "Falha no streaming."}
    after
      120_000 -> {:error, "Tempo limite excedido."}
    end
  end

  defp handle_completion_response(resp, messages, tools, config, opts, iteration) do
    choice = get_in(resp, ["choices", Access.at(0)])
    finish_reason = choice && choice["finish_reason"]
    msg = choice && choice["message"]

    cond do
      # Structured tool_calls from API
      finish_reason == "tool_calls" && msg && msg["tool_calls"] && msg["tool_calls"] != [] ->
        names = Enum.map(msg["tool_calls"] || [], fn tc -> tc["function"]["name"] end)
        Logger.debug("CerebrasAgent: iteration #{iteration + 1} → tools: #{inspect(names)}")
        execute_and_continue(messages, msg, tools, config, opts, iteration)

      # Fallback: model output tool call as text in content (e.g. llama3.1-8b)
      msg && msg["content"] && content_is_tool_call?(msg["content"]) ->
        Logger.debug(
          "CerebrasAgent: iteration #{iteration + 1} → tool call in content (fallback)"
        )

        case parse_and_execute_tool_from_content(messages, msg["content"], tools) do
          {:ok, new_messages} ->
            chat_with_tools(new_messages, tools, config, opts, iteration + 1)

          :error ->
            # Could not parse - show error rather than raw JSON
            {:ok, "Não consegui processar a resposta. Por favor, reformule a pergunta."}
        end

      msg && msg["content"] && String.trim(msg["content"]) != "" ->
        Logger.debug("CerebrasAgent: iteration #{iteration + 1} → text response")
        {:ok, msg["content"]}

      true ->
        {:ok, "Não foi possível obter resposta."}
    end
  end

  defp execute_and_continue(messages, msg, tools, config, opts, iteration) do
    {updated_messages, has_error} = execute_tool_calls(messages, msg, tools)

    if has_error do
      {:ok, "Ocorreu um erro ao aceder aos dados. Por favor, tente novamente."}
    else
      chat_with_tools(updated_messages, tools, config, opts, iteration + 1)
    end
  end

  defp content_is_tool_call?(content) when is_binary(content) do
    content = String.trim(content)

    (String.contains?(content, "\"type\":\"function\"") or
       String.contains?(content, "\"type\": \"function\"")) and
      String.contains?(content, "\"name\"") and
      String.contains?(content, "\"arguments\"")
  end

  defp content_is_tool_call?(_), do: false

  defp parse_and_execute_tool_from_content(messages, content, _tools) do
    # Parse JSON from content - could be single object or array
    content = String.trim(content)
    # Extract JSON object - handle possible markdown code block
    json_str =
      case Regex.run(~r/\{[\s\S]*\}/, content) do
        [match] -> match
        _ -> content
      end

    case Jason.decode(json_str) do
      {:ok, %{"type" => "function", "name" => name, "arguments" => args}} when is_binary(args) ->
        args_map =
          case Jason.decode(args) do
            {:ok, m} when is_map(m) -> m
            _ -> %{}
          end

        case Barragenspt.Search.LLMTools.execute_tool(name, args_map) do
          {:ok, data} ->
            build_messages_with_tool_result(messages, content, data)

          {:error, _} ->
            :error
        end

      {:ok, %{"type" => "function", "name" => name, "arguments" => args}} when is_map(args) ->
        case Barragenspt.Search.LLMTools.execute_tool(name, args) do
          {:ok, data} ->
            build_messages_with_tool_result(messages, content, data)

          {:error, _} ->
            :error
        end

      _ ->
        :error
    end
  end

  defp build_messages_with_tool_result(messages, assistant_content, tool_data) do
    tool_result = Jason.encode!(tool_data)
    assistant_msg = %{"role" => "assistant", "content" => assistant_content}
    tool_msg = %{"role" => "tool", "tool_call_id" => "fallback_1", "content" => tool_result}
    new_messages = messages ++ [assistant_msg, tool_msg]
    {:ok, new_messages}
  end

  defp build_messages(messages) do
    system =
      "És um assistente especializado em barragens e armazenamento de água em Portugal. " <>
        "Respondes em português. Usa as ferramentas disponíveis para obter dados em tempo real. " <>
        "Não deves dar mais dados do que os estritamente necessários e tendo em conta o contexto da conversa. " <>
        "Quando retornares dados tabulares, formata em Markdown com tabelas."

    [%{"role" => "system", "content" => system} | Enum.map(messages, &map_message/1)]
  end

  defp map_message(%{role: role, content: content}) when is_binary(content) do
    %{"role" => to_string(role), "content" => content}
  end

  defp map_message(%{role: role, content: content}) do
    %{"role" => to_string(role), "content" => content}
  end

  defp map_message(%{"role" => "tool"} = m) do
    Map.take(m, ["role", "tool_call_id", "content"])
  end

  defp map_message(%{"role" => "assistant", "tool_calls" => _} = m) do
    # Assistant message with tool_calls; API expects role, tool_calls, and optionally content
    base = %{"role" => "assistant", "tool_calls" => m["tool_calls"]}

    case m["content"] do
      c when is_binary(c) -> Map.put(base, "content", c)
      _ -> Map.put(base, "content", nil)
    end
  end

  defp map_message(%{"role" => role, "content" => content}) do
    %{"role" => role, "content" => content}
  end

  defp execute_tool_calls(messages, assistant_msg, _tools) do
    base = messages ++ [assistant_msg]
    tool_calls = assistant_msg["tool_calls"] || []

    results =
      Enum.map(tool_calls, fn tc ->
        id = tc["id"]
        name = tc["function"]["name"]

        args =
          case safe_json_decode(tc["function"]["arguments"]) do
            {:ok, m} -> m
            _ -> %{}
          end

        result =
          case Barragenspt.Search.LLMTools.execute_tool(name, args) do
            {:ok, data} -> Jason.encode!(data)
            {:error, err} -> Jason.encode!(%{error: err})
          end

        %{"tool_call_id" => id, "content" => result}
      end)

    has_error = Enum.any?(results, fn r -> String.contains?(r["content"], "\"error\"") end)

    tool_msgs =
      Enum.map(results, fn r ->
        %{"role" => "tool", "tool_call_id" => r["tool_call_id"], "content" => r["content"]}
      end)

    {base ++ tool_msgs, has_error}
  end

  defp safe_json_decode(str) when is_binary(str) do
    Jason.decode(str)
  rescue
    _ -> {:error, %{}}
  end

  defp safe_json_decode(_), do: {:error, %{}}
end
