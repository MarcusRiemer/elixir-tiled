# See https://doc.mapeditor.org/en/stable/reference/json-map-format/#tileset
defmodule Tiled.Tileset do
  require Logger

  use Ecto.Schema
  @primary_key false

  embedded_schema do
    field(:type, Ecto.Enum, values: [:tileset])
    field(:image, :string)
    field(:name, :string)
    field(:imageheight, :integer)
    field(:imagewidth, :integer)
    field(:tilewidth, :integer)
    field(:tileheight, :integer)
    field(:tilecount, :integer)
    field(:spacing, :integer)
    field(:margin, :integer)
    field(:columns, :integer)

    field(:path, :string, virtual: true)
    field(:image_data, :map, virtual: true)
    field(:cached_tiles, :map, virtual: true, default: %{})
  end

  @fields [
    :type,
    :image,
    :name,
    :imageheight,
    :imagewidth,
    :tilewidth,
    :tileheight,
    :tilecount,
    :spacing,
    :margin,
    :columns
  ]

  def changeset(struct, attrs) do
    struct
    |> Ecto.Changeset.cast(attrs, @fields)
    |> Ecto.Changeset.validate_required(@fields)
  end

  def load!(path) when is_binary(path) do
    Logger.debug("Loading tileset from #{path}")

    tileset_map =
      File.read!(path)
      |> JSON.decode!()

    __MODULE__.changeset(%__MODULE__{path: path}, tileset_map)
    |> Ecto.Changeset.apply_changes()
    |> load_image_data!()
  end

  def tile_image(%__MODULE__{} = tileset, idx) when is_integer(idx) do
    {x, y} = Tiled.Coordinate.point_from_index(tileset, idx)

    case Map.get(tileset.cached_tiles, {x, y}, :notfound) do
      %Vix.Vips.Image{} = image ->
        Logger.debug("Cache hit: #{tileset.name} at {#{x}, #{y}}")
        {:ok, image, tileset}

      :notfound ->
        case Image.crop(tileset.image_data, x, y, tileset.tilewidth, tileset.tileheight) do
          {:ok, image} ->
            Logger.debug("Cache write: #{tileset.name} at {#{x}, #{y}}")
            {:ok, image, put_in(tileset, [Access.key!(:cached_tiles), {x, y}], image)}

          {:error, msg, tileset} ->
            Logger.error(
              "Could not load tile ##{idx} (x: #{x}, y: #{y}) from #{tileset.path}: #{inspect(msg)}"
            )

            {:error, Image.new!(tileset.tilewidth, tileset.tileheight, color: [255, 0, 0, 255])}
        end
    end
  end

  defp load_image_data!(%__MODULE__{} = tileset) do
    image_path = Path.expand(tileset.image, Path.dirname(tileset.path))

    %{tileset | image_data: Image.open!(image_path)}
  end
end
