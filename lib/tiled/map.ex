# See https://doc.mapeditor.org/en/stable/reference/json-map-format/#map
defmodule Tiled.Map do
  require Logger

  defmodule TilesetReference do
    use Ecto.Schema
    @primary_key false

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
    use Ecto.Schema
    @primary_key false

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

  defmodule Object do
    use Ecto.Schema
    @primary_key false

    embedded_schema do
      field(:id, :integer)
      field(:name, :string)
    end
  end

  defmodule ObjectGroup do
    use Ecto.Schema
    @primary_key false

    embedded_schema do
      field(:id, :integer)
      field(:type, Ecto.Enum, values: [:objectgroup])
      field(:name, :string)
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

  use Ecto.Schema
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

    field(:path, :string, virtual: true)

    embeds_many(:tilesets, TilesetReference)
    embeds_many(:layers, TileLayer)
  end

  @fields [:type, :orientation, :renderorder, :height, :width, :tileheight, :tilewidth, :infinite]

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> Ecto.Changeset.cast(attrs, @fields)
    |> Ecto.Changeset.validate_required(@fields)
    |> Ecto.Changeset.cast_embed(:tilesets, required: false)
    |> Ecto.Changeset.cast_embed(:layers, required: false)
  end

  def load!(path) when is_binary(path) do
    Logger.debug("Loading tiled map from #{path}")

    map_map =
      File.read!(path)
      |> JSON.decode!()

    changeset(%__MODULE__{path: path}, map_map)
    |> Ecto.Changeset.apply_changes()
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
    |> Enum.reduce({base_image, map}, fn %TileLayer{} = layer,
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

      {Image.compose!(accu_image, rendered_tile_image, x: render_x, y: render_y), accu_map}
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

  defp image_width(%__MODULE__{} = map), do: map.tilewidth * map.width
  defp image_height(%__MODULE__{} = map), do: map.tileheight * map.height

  def map_index_to_tileset_index(tilesets, map_index) do
    reversed = Enum.reverse(tilesets)

    tileset_reference_index_reverse =
      Enum.find_index(reversed, &(map_index >= &1.firstgid))

    tileset_reference = Enum.at(reversed, tileset_reference_index_reverse)

    tileset_reference_index = length(tilesets) - tileset_reference_index_reverse - 1

    {tileset_reference, tileset_reference_index, map_index - tileset_reference.firstgid}
  end
end
