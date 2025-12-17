defmodule EctoSupport.EmbeddedMap do
  use Ecto.ParameterizedType

  def type(params), do: {:array, params.value}

  def embed_as(_, _), do: :dump

  def init(opts) do
    %{
      value: opts[:value],
      value_key: opts[:value_key] || :__type__,
      key_name: opts[:key_name] || :id
    }
  end

  def cast(v, params) when is_list(v) do
    {:ok, from_json_list(v, params)}
  end

  def cast(v, params) do
    {:error, [message: "Unexpeced non-list when casting embedded map", value: v, params: params]}
  end

  def load(db_value, _loader, params) when is_list(db_value) do
    {:ok, from_json_list(db_value, params)}
  end

  def load(db_value, _loader, params) do
    {:error,
     [message: "Unexpeced non-list when loading embedded map", value: db_value, params: params]}
  end

  defp from_json_list(value, params) when is_list(value) do
    value_struct = params.value

    value
    |> Enum.map(fn data ->
      value_struct = value_struct || extract_struct_type(params, data)

      if value_struct == nil do
        raise "Could not find struct from #{inspect(data)}}"
      end

      value_struct.changeset(struct(value_struct), data)
      |> Ecto.Changeset.apply_changes()
    end)
    |> Map.new(&{get_in(&1, [Access.key!(params.key_name)]), &1})
  end

  defp extract_struct_type(%{value_key: value_key}, data) when is_atom(value_key) do
    extract_struct_type(Atom.to_string(value_key), data)
  end

  defp extract_struct_type(%{value_key: value_key}, data) when is_binary(value_key) do
    Map.get(data, value_key)
  end

  defp extract_struct_type(value_key, data) when is_binary(value_key) do
    Map.get(data, value_key) |> String.to_existing_atom()
  end

  def dump(data, _dumper, _params) when data == %{} do
    {:ok, []}
  end

  def dump(data, dumper, params) when is_map(data) do
    {:ok, Map.values(data) |> Enum.map(&dump_struct(&1, dumper, params))}
  end

  # Checks whether any of the fields on the given struct are an embedded
  # map themselves. If this is the case the field is dumped with the type
  # information attached to the schema.
  #
  # See https://elixirforum.com/t/ecto-embeds-many-as-single-map-with-unique-keys/65195/6
  # for the story that led to this implementation
  defp dump_struct(data, dumper, params)
       when is_struct(data, params.value) or is_struct(data, data.__type__) do
    hosting_struct = params.value || data.__type__
    keys = hosting_struct.__schema__(:fields)

    Enum.reduce(keys, data, fn key, data ->
      case hosting_struct.__schema__(:type, key) do
        {:parameterized, {EctoSupport.EmbeddedMap, _params}} = t ->
          {:ok, transformed} = dumper.(t, get_in(data, [Access.key!(key)]))
          put_in(data, [Access.key!(key)], transformed)

        _ ->
          data
      end
    end)
  end
end
