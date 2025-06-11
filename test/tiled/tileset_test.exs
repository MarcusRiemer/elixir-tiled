defmodule Tiled.TilesetTest do
  use ExUnit.Case, async: true

  test "input: kenney_tilemap" do
    tileset = Tiled.Tileset.load!("test/tiled/fixtures/kenney_tilemap.tsj")

    assert %Tiled.Tileset{
             type: :tileset,
             image: "kenney_tilemap.png",
             name: "kenney_tilemap",
             imagewidth: 192,
             imageheight: 176,
             tilewidth: 16,
             tileheight: 16,
             tilecount: 132,
             spacing: 0,
             margin: 0,
             columns: 12
           } = tileset
  end
end
