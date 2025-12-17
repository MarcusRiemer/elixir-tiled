# See https://doc.mapeditor.org/en/stable/reference/json-map-format
defmodule Tiled.Map do
  require Logger

  defmodule Property do
    use Ecto.Schema
    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:name, :string)
      field(:type, Ecto.Enum, values: [:string, :float, :int, :bool, :object])
      field(:value, Flint.Types.Union, oneof: [:boolean, :integer, :float, :string])
    end

    @fields [:name, :type, :value]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
    end

    def new(attrs) do
      changeset(%__MODULE__{}, attrs)
      |> Ecto.Changeset.apply_changes()
    end
  end

  defmodule TilesetReference do
    use Ecto.Schema
    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:firstgid, :integer)
      field(:source, :string)

      embeds_one(:tileset, Tiled.Tileset)
    end

    @fields [:firstgid, :source]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
    end

    def load_tileset!(%__MODULE__{} = ref, relative_to) do
      tileset_path = Path.expand(ref.source, relative_to)

      %{ref | tileset: Tiled.Tileset.load!(tileset_path)}
    end
  end

  defmodule TileLayer do
    @derive {Inspect, except: [:data]}

    use Ecto.Schema
    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:type, Ecto.Enum, values: [:tilelayer])
      field(:name, :string)
      field(:height, :integer)
      field(:width, :integer)
      field(:x, :integer)
      field(:y, :integer)

      field(:data, {:array, :integer}, default: [])
    end

    @fields [:id, :type, :name, :height, :width, :x, :y, :data]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
    end
  end

  defmodule GroupLayer do
    use Ecto.Schema
    import PolymorphicEmbed
    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:type, Ecto.Enum, values: [:group])
      field(:name, :string)

      polymorphic_embeds_many(:layers,
        types: [
          tilelayer: Tiled.Map.TileLayer,
          objectgroup: Tiled.Map.ObjectGroup,
          group: Tiled.Map.GroupLayer
        ],
        type_field_name: :type,
        on_type_not_found: :raise,
        on_replace: :delete
      )
    end

    @fields [:id, :type, :name]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
      |> PolymorphicEmbed.cast_polymorphic_embed(:layers, required: true)
    end
  end

  defmodule PathPoint do
    use Ecto.Schema

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:x, :float)
      field(:y, :float)
    end

    @fields [:x, :y]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
    end
  end

  defmodule ObjectPoint do
    use Ecto.Schema

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:point, Ecto.Enum, values: [true])
      field(:name, :string)
      field(:type, :string)
      field(:x, :float)
      field(:y, :float)
    end

    @fields [:id, :point, :type, :name, :x, :y]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields -- [:type, :name])
    end
  end

  defmodule ObjectPolygon do
    use Ecto.Schema

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:name, :string)
      field(:type, :string)
      field(:x, :float)
      field(:y, :float)
      field(:width, :float)
      field(:height, :float)

      embeds_many(:polygon, PathPoint)
    end

    @fields [:id, :name, :type, :x, :y, :width, :height]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.cast_embed(:polygon)
      |> Ecto.Changeset.validate_required(@fields -- [:name, :type])
    end
  end

  defmodule ObjectPolyline do
    use Ecto.Schema

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:name, :string)
      field(:type, :string)
      field(:x, :float)
      field(:y, :float)
      field(:width, :float)
      field(:height, :float)

      embeds_many(:polyline, PathPoint)
    end

    @fields [:id, :name, :type, :x, :y, :width, :height]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.cast_embed(:polyline)
      |> Ecto.Changeset.validate_required(@fields -- [:name, :type])
    end
  end

  defmodule ObjectRectangle do
    use Ecto.Schema

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:name, :string)
      field(:type, :string)
      field(:x, :float)
      field(:y, :float)
      field(:height, :float)
      field(:width, :float)
    end

    @fields [:id, :name, :type, :x, :y, :height, :width]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields -- [:name, :type])
    end
  end

  defmodule ObjectGroup do
    use Ecto.Schema
    import PolymorphicEmbed

    @primary_key false
    @derive Jason.Encoder

    embedded_schema do
      field(:id, :integer)
      field(:type, Ecto.Enum, values: [:objectgroup])
      field(:name, :string)
      field(:x, :integer)
      field(:y, :integer)

      polymorphic_embeds_many(:objects,
        types: [
          point: [
            module: ObjectPoint,
            identify_by_fields: [:point]
          ],
          polygon: [
            module: ObjectPolygon,
            identify_by_fields: [:polygon]
          ],
          polyline: [
            module: ObjectPolyline,
            identify_by_fields: [:polyline]
          ],
          rectangle: [
            module: ObjectRectangle,
            identify_by_fields: [:x, :y, :width, :height]
          ]
        ],
        on_type_not_found: :raise,
        on_replace: :delete
      )
    end

    @fields [:id, :type, :name, :x, :y]

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, @fields)
      |> Ecto.Changeset.validate_required(@fields)
      |> PolymorphicEmbed.cast_polymorphic_embed(:objects)
    end
  end

  use Ecto.Schema
  import PolymorphicEmbed

  @derive Jason.Encoder
  @primary_key false

  embedded_schema do
    field(:type, Ecto.Enum, values: [:map])
    field(:orientation, Ecto.Enum, values: [:orthogonal])
    field(:renderorder, Ecto.Enum, values: [:"right-down"])
    field(:height, :integer)
    field(:width, :integer)
    field(:tilewidth, :integer)
    field(:tileheight, :integer)
    field(:infinite, :boolean)
    field(:backgroundcolor, :string)

    field(:path, :string, virtual: true)

    field(:properties, EctoSupport.EmbeddedMap,
      value: Property,
      key_name: :name,
      default: %{}
    )

    embeds_many(:tilesets, TilesetReference)

    polymorphic_embeds_many(:layers,
      types: [
        tilelayer: TileLayer,
        objectgroup: ObjectGroup,
        group: GroupLayer
      ],
      type_field_name: :type,
      on_type_not_found: :raise,
      on_replace: :delete
    )
  end

  @fields [
    :type,
    :orientation,
    :renderorder,
    :height,
    :width,
    :tileheight,
    :tilewidth,
    :infinite,
    :properties,
    :backgroundcolor
  ]

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> Ecto.Changeset.cast(attrs, @fields)
    |> Ecto.Changeset.validate_required(@fields -- [:backgroundcolor])
    |> Ecto.Changeset.cast_embed(:tilesets, required: false)
    |> PolymorphicEmbed.cast_polymorphic_embed(:layers, required: false)
  end

  def new(attrs) do
    c = changeset(%__MODULE__{}, attrs)

    if c.valid? do
      Ecto.Changeset.apply_changes(c)
    else
      message =
        PolymorphicEmbed.traverse_errors(c, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)

      raise ArgumentError,
            "#{inspect(struct!(__MODULE__, Map.merge(attrs, message)), pretty: true)}"
    end
  end

  def load!(path) when is_binary(path) do
    Logger.debug("Loading tiled map from #{path}")

    changeset(%__MODULE__{path: path}, load_json!(path))
    |> Ecto.Changeset.apply_changes()
  end

  def load_json!(path) do
    File.read!(path)
    |> JSON.decode!()
  end

  def load_with_tilesets!(path) when is_binary(path) do
    load!(path)
    |> load_tilesets!()
  end

  defp load_tilesets!(%__MODULE__{} = map) do
    %{
      map
      | tilesets:
          Enum.map(map.tilesets, &TilesetReference.load_tileset!(&1, Path.dirname(map.path)))
    }
  end

  def render!(%__MODULE__{} = map) do
    base_image = Image.new!(image_width(map), image_height(map), color: [0, 0, 0, 0])

    Logger.debug(
      ~s|Rendering "#{map.path}" at #{Image.width(base_image)}x#{Image.height(base_image)}"|
    )

    map.layers
    |> Enum.reduce({base_image, map}, fn %{} = layer,
                                         {%Vix.Vips.Image{} = acc, %__MODULE__{} = map} ->
      render_layer!(acc, map, layer)
    end)
  end

  def render_layer!(%Vix.Vips.Image{} = map_image, %__MODULE__{} = map, %TileLayer{} = layer) do
    layer.data
    |> Enum.with_index()
    |> Enum.filter(fn {tile, _coord_index} -> tile > 0 end)
    # |> Enum.take(50) # Rendering more than 50 tiles on a single layer crashes the phoenix server on the second rendering of a controller
    |> Enum.reduce({map_image, map}, fn {tile, coord_index},
                                        {%Vix.Vips.Image{} = accu_image, accu_map} ->
      {render_x, render_y} = Tiled.Coordinate.point_from_index(accu_map, layer.width, coord_index)
      {:ok, rendered_tile_image, accu_map} = tile_image(accu_map, tile)

      {max_x, max_y} = {Image.width(accu_image), Image.height(accu_image)}

      {target_x, target_y} =
        {render_x + Image.width(rendered_tile_image),
         render_y + Image.height(rendered_tile_image)}

      # It's > instead of >= because indexing starts at 0.
      # On a 1x1 map with tilesize 16 the valid pixel indices are 0..15,
      # but calculating 0 + 16 (the target pixel position + the 1 based
      # width of the image)
      if target_x > max_x || target_y > max_y do
        raise RuntimeError,
              "Out of Bounds, image is #{max_x}x#{max_y}, attempted to render from #{render_x}, #{render_y} to #{target_x},#{target_y}"
      end

      Logger.debug(
        "Placed tile #{tile} with map index ##{coord_index} at pixel coordinate {#{render_x}, #{render_y}, #{target_x}, #{target_y}}"
      )

      # TODO: This is horribly inefficient
      {:ok, composed_image} =
        Image.compose!(accu_image, rendered_tile_image, x: render_x, y: render_y)
        # See https://github.com/akash-akya/vix/issues/203 why this call is seemingly required
        |> Vix.Vips.Image.copy_memory()

      {composed_image, accu_map}
    end)
  end

  def render_layer!(%Vix.Vips.Image{} = map_image, %__MODULE__{} = map, %ObjectGroup{} = _group) do
    {map_image, map}
  end

  def render_layer!(%Vix.Vips.Image{} = map_image, %__MODULE__{} = map, %GroupLayer{} = group) do
    Enum.reduce(group.layers, {map_image, map}, fn layer, {map_image, map} ->
      render_layer!(map_image, map, layer)
    end)
  end

  def tile_image(%__MODULE__{} = map, tile_idx) when is_integer(tile_idx) do
    {tileset_reference, tileset_reference_index, tileset_tile_index} =
      map_index_to_tileset_index(map.tilesets, tile_idx)

    {:ok, rendered_tile_image, updated_tileset} =
      Tiled.Tileset.tile_image(tileset_reference.tileset, tileset_tile_index)

    updated_tileset_reference =
      put_in(tileset_reference, [Access.key!(:tileset)], updated_tileset)

    {:ok, rendered_tile_image,
     put_in(
       map,
       [Access.key(:tilesets), Access.at(tileset_reference_index)],
       updated_tileset_reference
     )}
  end

  def write_image!(%__MODULE__{} = map, suffix \\ "") do
    {result_image, updated_map} = render!(map)

    path_basename = Path.basename(map.path, ".tmj")

    Image.write!(result_image, Path.dirname(map.path) <> "/" <> path_basename <> suffix <> ".png",
      minimize_file_size: true
    )

    {result_image, updated_map}
  end

  def image_width(%__MODULE__{} = map), do: map.tilewidth * map.width
  def image_height(%__MODULE__{} = map), do: map.tileheight * map.height

  def map_index_to_tileset_index(tilesets, map_index) do
    reversed = Enum.reverse(tilesets)

    tileset_reference_index_reverse =
      Enum.find_index(reversed, &(map_index >= &1.firstgid))

    tileset_reference = Enum.at(reversed, tileset_reference_index_reverse)

    tileset_reference_index = length(tilesets) - tileset_reference_index_reverse - 1

    {tileset_reference, tileset_reference_index, map_index - tileset_reference.firstgid}
  end

  def get_property_value(%__MODULE__{} = map, key, default \\ nil) when is_binary(key) do
    case Map.get(map.properties, key) do
      %Tiled.Map.Property{value: value} -> value
      _ -> default
    end
  end

  def tile_location(%__MODULE__{} = map, %{x: x, y: y}) when is_integer(x) and is_integer(y),
    do: tile_location(map, x, y)

  def tile_location(%__MODULE__{} = map, %{x: x, y: y}) when is_float(x) and is_float(y),
    do: tile_location(map, floor(x), floor(y))

  def tile_location(%__MODULE__{} = map, x, y) when is_integer(x) and is_integer(y) do
    %{x: div(x, map.tilewidth), y: div(y, map.tileheight)}
  end

  def objects(%__MODULE__{} = map) do
    Enum.reduce(map.layers, [], fn layer, acc -> _objects(layer, acc) end)
  end

  # TODO: This will turn slow with loads of objects. Reverse? Flatten?
  defp _objects(%TileLayer{}, acc) when is_list(acc), do: acc

  defp _objects(%ObjectGroup{} = object_group, acc) when is_list(acc),
    do: acc ++ object_group.objects

  defp _objects(%GroupLayer{} = group_layer, acc) when is_list(acc),
    do: Enum.reduce(group_layer.layers, acc, fn layer, acc -> _objects(layer, acc) end)

  def objects_by_type(%__MODULE__{} = map, type) when is_binary(type) do
    objects(map)
    |> Enum.filter(&(&1.type == type))
  end

  # TODO: Generalise Lookup
  def object_by_id(%__MODULE__{} = map, id) when is_binary(id),
    do: object_by_id(map, String.to_integer(id))

  def object_by_id(%__MODULE__{} = map, id) when is_integer(id), do: _object_by_id(map, id)

  defp _object_by_id(%__MODULE__{} = map, id) when is_integer(id) do
    Enum.find_value(map.layers, &_object_by_id(&1, id))
  end

  defp _object_by_id(%ObjectGroup{} = layer, id) when is_integer(id) do
    Enum.find(layer.objects, &(&1.id == id))
  end

  defp _object_by_id(%GroupLayer{} = layer, id) when is_integer(id) do
    Enum.find_value(layer.layers, &_object_by_id(&1, id))
  end

  defp _object_by_id(_layer, id) when is_integer(id) do
    nil
  end
end
