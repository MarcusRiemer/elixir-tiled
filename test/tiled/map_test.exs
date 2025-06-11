defmodule Tiled.MapTest do
  use ExUnit.Case, async: true

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

  test "input 002: Single referenced tileset with single tile" do
    map = Tiled.Map.load!("test/tiled/fixtures/002_single_layer_2x2.tmj")

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
    res = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/002_single_layer_2x2_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end

  test "input 004: Two tilesets, each on an own layer" do
    map = Tiled.Map.load!("test/tiled/fixtures/004_multiple_layer_3x3.tmj")

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
    res = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/004_multiple_layer_3x3_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end

  test "input 005: This crashes the image library?!" do
    map = Tiled.Map.load!("test/tiled/fixtures/005_render_crash_10x10.tmj")

    # Compare to reference rendering
    res = Tiled.Map.write_image!(map, "_run")
    ref = Image.open!("test/tiled/fixtures/005_render_crash_10x10_ref.png")
    assert {:ok, 0} = Image.hamming_distance(res, ref)
  end
end
