defmodule Tiled.MapTest do
  use ExUnit.Case, async: true

  describe "map_index_to_tileset_index/2" do
    test "Single Tileset starting at 1" do
      ref_0 = %{firstgid: 1, source: "a"}
      assert {^ref_0, 0, 0} = Tiled.Map.map_index_to_tileset_index([ref_0], 1)
    end

    test "Two tilesets" do
      refs = [ref_0, ref_1] = [%{firstgid: 1, source: "a"}, %{firstgid: 10, source: "b"}]

      assert {^ref_0, 0, 0} = Tiled.Map.map_index_to_tileset_index(refs, 1)
      assert {^ref_1, 1, 0} = Tiled.Map.map_index_to_tileset_index(refs, 10)
    end
  end

  describe "tile_location" do
    setup do
      {:ok, map} =
        Tiled.Map.changeset(%Tiled.Map{}, %{
          height: 4,
          width: 4,
          tileheight: 16,
          tilewidth: 16,
          infinite: false,
          orientation: "orthogonal",
          renderorder: "right-down",
          type: "map"
        })
        |> Ecto.Changeset.apply_action(:create)

      %{map: map}
    end

    for {given, expected} <- [
          {%{x: 0, y: 0}, %{x: 0, y: 0}},
          {%{x: 15, y: 15}, %{x: 0, y: 0}},
          {%{x: 16, y: 32}, %{x: 1, y: 2}},
          {%{x: 15.9, y: 15.9}, %{x: 0, y: 0}},
          {%{x: 16.1, y: 31.9}, %{x: 1, y: 1}}
        ] do
      test "#{inspect(given)} -> #{inspect(expected)}", %{map: map} do
        assert Tiled.Map.tile_location(map, unquote(Macro.escape(given))) ==
                 unquote(Macro.escape(expected))
      end
    end
  end

  describe "properties" do
    test "empty" do
      changeset = Tiled.Map.changeset(%Tiled.Map{}, %{properties: []})
      result = Ecto.Changeset.apply_changes(changeset)

      assert %Tiled.Map{
               properties: %{}
             } = result

      assert "given_default" ==
               Tiled.Map.get_property_value(result, "does_not_exist", "given_default")
    end

    test "single string" do
      changeset =
        Tiled.Map.changeset(%Tiled.Map{}, %{
          properties: [
            %{
              "name" => "id",
              "type" => "string",
              "value" => "string_id"
            }
          ]
        })

      result = Ecto.Changeset.apply_changes(changeset)

      assert %Tiled.Map{
               properties: %{
                 "id" => %Tiled.Map.Property{name: "id", type: :string, value: "string_id"}
               }
             } = result

      assert "string_id" == Tiled.Map.get_property_value(result, "id")
    end
  end

  test "input 001: Only dimensions for finite map" do
    map = Tiled.Map.load!("test/tiled/fixtures/001_only_dimensions.tmj")

    assert %Tiled.Map{
             width: 40,
             height: 40,
             tilewidth: 16,
             tileheight: 16,
             type: :map,
             infinite: false,
             layers: [],
             tilesets: []
           } = map
  end

  test "input 002: Single referenced tileset with four different tiles" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/002_single_layer_2x2.tmj")

    assert %Tiled.Map{
             width: 2,
             height: 2,
             tilewidth: 16,
             tileheight: 16,
             type: :map,
             infinite: false,
             tilesets: [
               %Tiled.Map.TilesetReference{
                 firstgid: 1,
                 source: "kenney_tilemap.tsj"
               }
             ],
             layers: [
               %Tiled.Map.TileLayer{
                 id: 1,
                 name: "Tile Layer 1",
                 data: [83, 102, 116, 87]
               }
             ]
           } = map

    # Compare to reference rendering
    {res, _updated_map} = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/002_single_layer_2x2_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end

  test "input 003: Nothing but objects" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/003_objects.tmj")

    expected_objects =
      [point_1, rect_2, poly_3, poly_4] = [
        %Tiled.Map.ObjectPoint{
          id: 1,
          point: true,
          name: "The Spawn",
          type: "Spawn",
          x: 8.0,
          y: 8.0
        },
        %Tiled.Map.ObjectRectangle{
          id: 2,
          name: "The Rectangle",
          x: 32.0,
          y: 0.0,
          height: 32.0,
          width: 32.0
        },
        %Tiled.Map.ObjectPolygon{
          id: 5,
          name: "The Polygon",
          x: 16.0,
          y: 16.0,
          height: 0.0,
          width: 0.0,
          polygon: [
            %Tiled.Map.PathPoint{x: +0.0, y: +0.0},
            %Tiled.Map.PathPoint{x: +0.0, y: 48.0},
            %Tiled.Map.PathPoint{x: 48.0, y: 48.0},
            %Tiled.Map.PathPoint{x: 48.0, y: 16.0},
            %Tiled.Map.PathPoint{x: 16.0, y: 16.0},
            %Tiled.Map.PathPoint{x: 16.0, y: +0.0}
          ]
        },
        %Tiled.Map.ObjectPolyline{
          id: 6,
          name: "The Polyline",
          x: 32.0,
          y: 48.0,
          height: 0.0,
          width: 0.0,
          polyline: [
            %Tiled.Map.PathPoint{x: +0.0, y: +0.0},
            %Tiled.Map.PathPoint{x: 16.0, y: 0.0},
            %Tiled.Map.PathPoint{x: 16.0, y: -16.0},
            %Tiled.Map.PathPoint{x: 32.0, y: +0.0}
          ]
        }
      ]

    assert %Tiled.Map{
             width: 4,
             height: 4,
             tilewidth: 16,
             tileheight: 16,
             type: :map,
             infinite: false,
             tilesets: [],
             layers: [
               %Tiled.Map.TileLayer{
                 id: 1,
                 name: "Tile Layer 1",
                 type: :tilelayer,
                 x: 0,
                 y: 0,
                 data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                 height: 4,
                 width: 4
               },
               %Tiled.Map.ObjectGroup{
                 id: 2,
                 name: "Object Layer 1",
                 type: :objectgroup,
                 x: 0,
                 y: 0,
                 objects: ^expected_objects
               }
             ]
           } = map

    # Ensure it does not crash when rendering
    {%Vix.Vips.Image{}, ^map} = Tiled.Map.render!(map)

    assert expected_objects == Tiled.Map.objects(map)
    assert point_1 == Tiled.Map.object_by_id(map, point_1.id)
    assert point_1 == Tiled.Map.object_by_id(map, Integer.to_string(point_1.id))
    assert rect_2 == Tiled.Map.object_by_id(map, rect_2.id)
    assert rect_2 == Tiled.Map.object_by_id(map, Integer.to_string(rect_2.id))
    assert poly_3 == Tiled.Map.object_by_id(map, poly_3.id)
    assert poly_3 == Tiled.Map.object_by_id(map, Integer.to_string(poly_3.id))
    assert poly_4 == Tiled.Map.object_by_id(map, poly_4.id)
    assert poly_4 == Tiled.Map.object_by_id(map, Integer.to_string(poly_4.id))
  end

  test "input 004: Two tilesets, each on an own layer" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/004_multiple_layer_3x3.tmj")

    assert %Tiled.Map{
             width: 3,
             height: 3,
             tilewidth: 16,
             tileheight: 16,
             type: :map,
             infinite: false,
             tilesets: [
               %Tiled.Map.TilesetReference{
                 source: "kenney_roguelike_spritesheet.tsj",
                 firstgid: 1
               },
               %Tiled.Map.TilesetReference{
                 source: "kenney_tilemap.tsj",
                 firstgid: 1768
               }
             ],
             layers: [
               %Tiled.Map.TileLayer{
                 data: [3, 4, 5, 60, 61, 62, 117, 118, 119],
                 id: 1,
                 name: "Background",
                 height: 3,
                 type: :tilelayer,
                 width: 3,
                 x: 0,
                 y: 0
               },
               %Tiled.Map.TileLayer{
                 data: [0, 0, 0, 0, 1885, 0, 0, 0, 0],
                 id: 2,
                 name: "Foreground",
                 type: :tilelayer,
                 x: 0,
                 y: 0,
                 width: 3,
                 height: 3
               }
             ]
           } = map

    # Compare to reference rendering
    {res, _updated_map} = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/004_multiple_layer_3x3_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end

  @tag :crash
  test "input 005: This sometimes crashes the image library?!" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/005_render_crash_10x10.tmj")

    # Compare to reference rendering
    {res, _updated_map} = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/005_render_crash_10x10_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end

  test "input 006: all identical 2x2" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/006_all_identical_2x2.tmj")

    # Compare to reference rendering
    {res, updated_map} = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/006_all_identical_2x2_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)

    assert %Tiled.Map{
             tilesets: [
               %Tiled.Map.TilesetReference{
                 tileset: %Tiled.Tileset{cached_tiles: %{{0, 0} => %Vix.Vips.Image{}}}
               }
             ]
           } = updated_map
  end

  @tag :crash
  test "input 007: all identical 30x30, this always crashes the image library?!" do
    map = Tiled.Map.load_with_tilesets!("test/tiled/fixtures/007_all_identical_30x30.tmj")

    # Compare to reference rendering
    {res, updated_map} = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/007_all_identical_30x30_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)

    assert %Tiled.Map{
             tilesets: [
               %Tiled.Map.TilesetReference{
                 tileset: %Tiled.Tileset{cached_tiles: %{{17, 0} => %Vix.Vips.Image{}}}
               }
             ]
           } = updated_map
  end

  test "input 008: Map properties" do
    map = Tiled.Map.load!("test/tiled/fixtures/008_map_properties.tmj")

    assert %Tiled.Map{
             properties: %{
               "id" => %Tiled.Map.Property{
                 name: "id",
                 type: :string,
                 value: "string_id"
               },
               "float_value" => %Tiled.Map.Property{
                 name: "float_value",
                 type: :float,
                 value: 3.14
               },
               "int_value" => %Tiled.Map.Property{
                 name: "int_value",
                 type: :int,
                 value: 5
               },
               "boolean_value" => %Tiled.Map.Property{
                 name: "boolean_value",
                 type: :bool,
                 value: true
               },
               "object_value" => %Tiled.Map.Property{
                 name: "object_value",
                 type: :object,
                 value: 1
               },
               "missing_object" => %Tiled.Map.Property{
                 name: "missing_object",
                 type: :object,
                 value: 0
               }
             }
           } = map
  end

  describe "input 009: layers in and outside of a group layer" do
    setup do
      %{map: Tiled.Map.load_with_tilesets!("test/tiled/fixtures/009_grouped_layers.tmj")}
    end

    test "render", %{map: map} do
      {res, _updated_map} = Tiled.Map.write_image!(map, "_run")
      ref = Image.open!("test/tiled/fixtures/009_grouped_layers_ref.png")
      assert {:ok, 0} = Image.hamming_distance(res, ref)
    end

    test "objects", %{map: map} do
      assert [
               %Tiled.Map.ObjectRectangle{name: "Nested Rect"},
               %Tiled.Map.ObjectRectangle{name: "Top Level Rect"}
             ] = Tiled.Map.objects(map)
    end
  end
end
