defmodule Tiled.CoordinateTest do
  use ExUnit.Case, async: true

  describe "2x2, no spacing, no margin" do
    @tileset %Tiled.Tileset{columns: 2, tilewidth: 16, tileheight: 16, spacing: 0, margin: 0}

    test "Upper Left" do
      assert {0, 0} = Tiled.Coordinate.point_from_index(@tileset, 0)
    end

    test "Upper Right" do
      assert {16, 0} = Tiled.Coordinate.point_from_index(@tileset, 1)
    end

    test "Lower Left" do
      assert {0, 16} = Tiled.Coordinate.point_from_index(@tileset, 2)
    end

    test "Lower Right" do
      assert {16, 16} = Tiled.Coordinate.point_from_index(@tileset, 3)
    end
  end

  describe "3x3, 0 spacing, 1 margin" do
    @tileset %Tiled.Tileset{columns: 3, tilewidth: 32, tileheight: 32, spacing: 0, margin: 1}

    test "Upper Left" do
      assert {1, 1} = Tiled.Coordinate.point_from_index(@tileset, 0)
    end

    test "Upper Middle" do
      assert {33, 1} = Tiled.Coordinate.point_from_index(@tileset, 1)
    end

    test "Upper Right" do
      assert {65, 1} = Tiled.Coordinate.point_from_index(@tileset, 2)
    end

    test "Middle Left" do
      assert {1, 33} = Tiled.Coordinate.point_from_index(@tileset, 3)
    end

    test "Middle Middle" do
      assert {33, 33} = Tiled.Coordinate.point_from_index(@tileset, 4)
    end

    test "Middle Right" do
      assert {65, 33} = Tiled.Coordinate.point_from_index(@tileset, 5)
    end

    test "Lower Left" do
      assert {1, 65} = Tiled.Coordinate.point_from_index(@tileset, 6)
    end

    test "Lower Middle" do
      assert {33, 65} = Tiled.Coordinate.point_from_index(@tileset, 7)
    end

    test "Lower Right" do
      assert {65, 65} = Tiled.Coordinate.point_from_index(@tileset, 8)
    end
  end

  describe "3x3, 1 spacing, 0 margin" do
    @tileset %Tiled.Tileset{columns: 3, tilewidth: 32, tileheight: 32, spacing: 1, margin: 0}

    test "Upper Left" do
      assert {0, 0} = Tiled.Coordinate.point_from_index(@tileset, 0)
    end

    test "Upper Middle" do
      assert {33, 0} = Tiled.Coordinate.point_from_index(@tileset, 1)
    end

    test "Upper Right" do
      assert {66, 0} = Tiled.Coordinate.point_from_index(@tileset, 2)
    end

    test "Middle Left" do
      assert {0, 33} = Tiled.Coordinate.point_from_index(@tileset, 3)
    end

    test "Middle Middle" do
      assert {33, 33} = Tiled.Coordinate.point_from_index(@tileset, 4)
    end

    test "Middle Right" do
      assert {66, 33} = Tiled.Coordinate.point_from_index(@tileset, 5)
    end

    test "Lower Left" do
      assert {0, 66} = Tiled.Coordinate.point_from_index(@tileset, 6)
    end

    test "Lower Middle" do
      assert {33, 66} = Tiled.Coordinate.point_from_index(@tileset, 7)
    end

    test "Lower Right" do
      assert {66, 66} = Tiled.Coordinate.point_from_index(@tileset, 8)
    end
  end

  describe "3x3, 1 spacing, 1 margin" do
    @tileset %Tiled.Tileset{columns: 3, tilewidth: 32, tileheight: 32, spacing: 1, margin: 1}

    test "Upper Left" do
      assert {1, 1} = Tiled.Coordinate.point_from_index(@tileset, 0)
    end

    test "Upper Middle" do
      assert {34, 1} = Tiled.Coordinate.point_from_index(@tileset, 1)
    end

    test "Upper Right" do
      assert {67, 1} = Tiled.Coordinate.point_from_index(@tileset, 2)
    end

    test "Middle Left" do
      assert {1, 34} = Tiled.Coordinate.point_from_index(@tileset, 3)
    end

    test "Middle Middle" do
      assert {34, 34} = Tiled.Coordinate.point_from_index(@tileset, 4)
    end

    test "Middle Right" do
      assert {67, 34} = Tiled.Coordinate.point_from_index(@tileset, 5)
    end

    test "Lower Left" do
      assert {1, 67} = Tiled.Coordinate.point_from_index(@tileset, 6)
    end

    test "Lower Middle" do
      assert {34, 67} = Tiled.Coordinate.point_from_index(@tileset, 7)
    end

    test "Lower Right" do
      assert {67, 67} = Tiled.Coordinate.point_from_index(@tileset, 8)
    end
  end
end
