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

    map.layers
    |> Enum.reduce(base_image, fn %TileLayer{} = layer, %Vix.Vips.Image{} = acc ->
      render_layer!(acc, map, layer)
    end)
  end

  def render_layer!(%Vix.Vips.Image{} = map_image, %__MODULE__{} = map, %TileLayer{} = layer) do
    layer.data
    |> Enum.with_index()
    |> Enum.filter(fn {tile, _coord_index} -> tile > 0 end)
    # |> Enum.take(50) # Rendering more than 50 tiles on a single layer crashes the phoenix server on the second rendering of a controller
    |> Enum.reduce(map_image, fn {tile, coord_index}, %Vix.Vips.Image{} = accu_image ->
      {render_x, render_y} = Tiled.Coordinate.point_from_index(map, layer.width, coord_index)
      {:ok, rendered_tile_image} = tile_image(map, tile)

      Image.compose!(accu_image, rendered_tile_image, x: render_x, y: render_y)
    end)
  end

  def tile_image(%__MODULE__{} = map, tile_idx) when is_integer(tile_idx) do
    tileset_reference = map.tilesets |> Enum.reverse() |> Enum.find(&(tile_idx >= &1.firstgid))

    Tiled.Tileset.tile_image(tileset_reference.tileset, tile_idx - tileset_reference.firstgid)
  end

  def write_image!(%__MODULE__{} = map, suffix \\ "") do
    result_image = render!(map)

    path_basename = Path.basename(map.path, ".tmj")

    Image.write!(result_image, Path.dirname(map.path) <> "/" <> path_basename <> suffix <> ".png",
      minimize_file_size: true
    )

    result_image
  end

  defp image_width(%__MODULE__{} = map), do: map.tilewidth * map.width
  defp image_height(%__MODULE__{} = map), do: map.tileheight * map.height
end
