defmodule Tiled.Coordinate do
  def point_from_index(
        %Tiled.Tileset{
          tilewidth: tilewidth,
          tileheight: tileheight,
          columns: columns,
          spacing: spacing,
          margin: margin
        },
        index
      )
      when is_integer(index) and spacing == 0 do
    {coord_x, coord_y} = {rem(index, columns), div(index, columns)}

    {coord_x * tilewidth + margin, coord_y * tileheight + margin}
  end

  def point_from_index(
        %Tiled.Tileset{
          tilewidth: tilewidth,
          tileheight: tileheight,
          columns: columns,
          spacing: spacing,
          margin: margin
        },
        index
      )
      when is_integer(index)
      when spacing > 0 do
    {coord_x, coord_y} = {rem(index, columns), div(index, columns)}

    {coord_x * tilewidth + coord_x * spacing + margin,
     coord_y * tileheight + coord_y * spacing + margin}
  end

  def point_from_index(
        %Tiled.Map{tilewidth: tilewidth, tileheight: tileheight},
        columns,
        index
      )
      when is_integer(index) and is_integer(columns) do
    {rem(index, columns) * tilewidth, div(index, columns) * tileheight}
  end
end
