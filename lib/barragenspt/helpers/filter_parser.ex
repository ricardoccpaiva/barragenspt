defmodule Barragenspt.Helpers.FilterParser do
  @op_map %{
    "lt" => :<,
    "gt" => :>,
    "lte" => :<=,
    "gte" => :>=,
    "eq" => :==
  }

  def parse_int(nil, default), do: default

  def parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  def parse_int(value, _default) when is_integer(value), do: value
  def parse_int(_, default), do: default

  def parse(nil), do: []

  def parse(params) when is_map(params) do
    params
    |> Enum.flat_map(fn {op, value} ->
      case Map.get(@op_map, op) do
        nil ->
          []

        mapped_op ->
          [
            %Flop.Filter{
              field: :colected_at,
              op: mapped_op,
              value: value
            }
          ]
      end
    end)
  end
end
