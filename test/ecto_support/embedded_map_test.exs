defmodule EctoSupport.EmbeddedMapTest do
  use ExUnit.Case, async: true

  describe "Property" do
    defmodule Child do
      use Ecto.Schema
      @primary_key false

      embedded_schema do
        field(:name, :string)
        field(:type, Ecto.Enum, values: [:string, :float, :int, :bool, :object])
        field(:value, :string)
      end

      @fields [:name, :type, :value]

      def changeset(struct, attrs) do
        struct
        |> Ecto.Changeset.cast(attrs, @fields)
        |> Ecto.Changeset.validate_required(@fields)
      end
    end

    defmodule Parent do
      use Ecto.Schema
      @primary_key false

      embedded_schema do
        field(:properties, EctoSupport.EmbeddedMap,
          value: Child,
          default: %{},
          key_name: :name
        )
      end

      @fields [:properties]

      def changeset(struct, attrs) do
        struct
        |> Ecto.Changeset.cast(attrs, @fields)
        |> Ecto.Changeset.validate_required(@fields)
      end
    end

    test "load" do
      given_map = [%{"name" => "n", "type" => "string", "value" => "v"}]

      {:ok, loaded} =
        EctoSupport.EmbeddedMap.load(given_map, &Ecto.Type.load/2, %{
          value: Child,
          key_name: :value
        })

      assert %{"v" => %Child{name: "n", type: :string, value: "v"}} == loaded
    end

    test "cast" do
      given_map = [%{"name" => "n", "type" => "string", "value" => "v"}]
      {:ok, casted} = EctoSupport.EmbeddedMap.cast(given_map, %{value: Child, key_name: :value})

      assert %{"v" => %Child{name: "n", type: :string, value: "v"}} == casted
    end

    test "dump" do
      given_struct = %{"v" => %Child{name: "n", type: :string, value: "v"}}

      {:ok, dumped} =
        EctoSupport.EmbeddedMap.dump(given_struct, &Ecto.Type.dump/2, %{
          value: Child,
          key_name: :value
        })

      assert [%Child{name: "n", type: :string, value: "v"}] == dumped
    end

    test "dump (empty)" do
      given_struct = %{}

      {:ok, dumped} =
        EctoSupport.EmbeddedMap.dump(given_struct, &Ecto.Type.dump/2, %{
          value: Child,
          key_name: :value
        })

      assert [] == dumped
    end

    test "changeset" do
      given_map = %{"properties" => [%{"name" => "n", "type" => "string", "value" => "v"}]}

      changeset = Parent.changeset(%Parent{}, given_map)

      assert changeset.valid?
      assert %Parent{properties: %{"n" => %Child{name: "n", type: :string, value: "v"}}}
    end

    test "changeset (empty)" do
      given_map = %{"properties" => []}

      changeset = Parent.changeset(%Parent{}, given_map)

      assert changeset.valid?
      assert %Parent{properties: %{}}
    end
  end

  describe "Nested" do
    defmodule NestedRoot do
      defmodule Parent do
        defmodule Child do
          use Ecto.Schema
          @primary_key false

          embedded_schema do
            field(:id, :string)
            field(:value, Flint.Types.Union, oneof: [:boolean, :integer, :float, :string])
          end

          @fields [:id, :value]

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

        use Ecto.Schema
        @primary_key false

        embedded_schema do
          field(:parent_id, :string)

          field(:parent_children, EctoSupport.EmbeddedMap,
            value: Child,
            default: %{}
          )
        end

        @fields [:parent_id, :parent_children]

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

      use Ecto.Schema
      @primary_key false

      embedded_schema do
        field(:root_children, EctoSupport.EmbeddedMap,
          value: Parent,
          key_name: :parent_id,
          default: %{}
        )
      end

      @fields [:root_children]

      def changeset(struct, attrs) do
        struct
        |> Ecto.Changeset.cast(attrs, @fields)
        |> Ecto.Changeset.validate_required(@fields)
      end
    end

    test "Child: changeset" do
      given_map = %{"id" => "one", "value" => 1}

      changeset = NestedRoot.Parent.Child.changeset(%NestedRoot.Parent.Child{}, given_map)

      assert changeset.valid?

      assert %NestedRoot.Parent.Child{id: "one", value: 1} ==
               Ecto.Changeset.apply_changes(changeset)
    end

    test "changeset" do
      given_map = %{
        "root_children" => [
          %{
            "parent_id" => "p1",
            "parent_children" => [
              %{"id" => "one", "value" => 1},
              %{"id" => "two", "value" => 2}
            ]
          },
          %{
            "parent_id" => "p2",
            "parent_children" => [
              %{"id" => "three", "value" => 3},
              %{"id" => "four", "value" => 4}
            ]
          }
        ]
      }

      changeset = NestedRoot.changeset(%NestedRoot{}, given_map)

      assert changeset.valid?

      assert %NestedRoot{
               root_children: %{
                 "p1" => %NestedRoot.Parent{
                   parent_id: "p1",
                   parent_children: %{
                     "one" => %NestedRoot.Parent.Child{id: "one", value: 1},
                     "two" => %NestedRoot.Parent.Child{id: "two", value: 2}
                   }
                 },
                 "p2" => %NestedRoot.Parent{
                   parent_id: "p2",
                   parent_children: %{
                     "three" => %NestedRoot.Parent.Child{id: "three", value: 3},
                     "four" => %NestedRoot.Parent.Child{id: "four", value: 4}
                   }
                 }
               }
             } == Ecto.Changeset.apply_changes(changeset)
    end

    test "dump" do
      assert {:ok,
              [
                %NestedRoot.Parent{
                  parent_id: "p1",
                  parent_children: [
                    %NestedRoot.Parent.Child{id: "one", value: 1},
                    %NestedRoot.Parent.Child{id: "two", value: 2}
                  ]
                },
                %NestedRoot.Parent{
                  parent_id: "p2",
                  parent_children: [
                    %NestedRoot.Parent.Child{id: "four", value: 4},
                    %NestedRoot.Parent.Child{id: "three", value: 3}
                  ]
                }
              ]} ==
               Ecto.Type.dump(NestedRoot.__schema__(:type, :root_children), %{
                 "p1" => %NestedRoot.Parent{
                   parent_id: "p1",
                   parent_children: %{
                     "one" => %NestedRoot.Parent.Child{id: "one", value: 1},
                     "two" => %NestedRoot.Parent.Child{id: "two", value: 2}
                   }
                 },
                 "p2" => %NestedRoot.Parent{
                   parent_id: "p2",
                   parent_children: %{
                     "three" => %NestedRoot.Parent.Child{id: "three", value: 3},
                     "four" => %NestedRoot.Parent.Child{id: "four", value: 4}
                   }
                 }
               })
    end
  end

  describe "Polymorphic" do
    defmodule PolyRoot do
      defmodule ChildString do
        use Ecto.Schema
        @primary_key false

        embedded_schema do
          field(:__type__, Ecto.Enum, values: [__MODULE__], default: __MODULE__)
          field(:id, :string)
          field(:value, :string)
        end

        @fields [:__type__, :id, :value]

        def changeset(struct, attrs) do
          struct
          |> Ecto.Changeset.cast(attrs, @fields)
          |> Ecto.Changeset.validate_required(@fields)
        end
      end

      defmodule ChildInteger do
        use Ecto.Schema
        @primary_key false

        embedded_schema do
          field(:__type__, Ecto.Enum, values: [__MODULE__], default: __MODULE__)
          field(:id, :string)
          field(:value, :integer)
        end

        @fields [:__type__, :id, :value]

        def changeset(struct, attrs) do
          struct
          |> Ecto.Changeset.cast(attrs, @fields)
          |> Ecto.Changeset.validate_required(@fields)
        end
      end

      use Ecto.Schema
      @primary_key false

      embedded_schema do
        field(:root_children, EctoSupport.EmbeddedMap, default: %{})
      end

      @fields [:root_children]

      def changeset(struct, attrs) do
        struct
        |> Ecto.Changeset.cast(attrs, @fields)
        |> Ecto.Changeset.validate_required(@fields)
      end
    end

    test "changeset: ChildString only" do
      given_map = %{
        "root_children" => [
          %{"id" => "c1", "__type__" => Atom.to_string(PolyRoot.ChildString), "value" => "string"}
        ]
      }

      changeset = PolyRoot.changeset(%PolyRoot{}, given_map)

      assert changeset.valid?

      assert %PolyRoot{
               root_children: %{
                 "c1" => %PolyRoot.ChildString{
                   __type__: PolyRoot.ChildString,
                   id: "c1",
                   value: "string"
                 }
               }
             } == Ecto.Changeset.apply_changes(changeset)
    end

    test "changeset: ChildInteger only" do
      given_map = %{
        "root_children" => [
          %{"id" => "c1", "__type__" => Atom.to_string(PolyRoot.ChildInteger), "value" => 42}
        ]
      }

      changeset = PolyRoot.changeset(%PolyRoot{}, given_map)

      assert changeset.valid?

      assert %PolyRoot{
               root_children: %{
                 "c1" => %PolyRoot.ChildInteger{
                   __type__: PolyRoot.ChildInteger,
                   id: "c1",
                   value: 42
                 }
               }
             } == Ecto.Changeset.apply_changes(changeset)
    end

    test "changeset: Both children" do
      given_map = %{
        "root_children" => [
          %{"id" => "c1", "__type__" => Atom.to_string(PolyRoot.ChildInteger), "value" => 42},
          %{
            "id" => "c2",
            "__type__" => Atom.to_string(PolyRoot.ChildString),
            "value" => "fortytwo"
          }
        ]
      }

      changeset = PolyRoot.changeset(%PolyRoot{}, given_map)

      assert changeset.valid?

      assert %PolyRoot{
               root_children: %{
                 "c1" => %PolyRoot.ChildInteger{
                   __type__: PolyRoot.ChildInteger,
                   id: "c1",
                   value: 42
                 },
                 "c2" => %PolyRoot.ChildString{
                   __type__: PolyRoot.ChildString,
                   id: "c2",
                   value: "fortytwo"
                 }
               }
             } == Ecto.Changeset.apply_changes(changeset)
    end

    test "dump" do
      assert {:ok,
              [
                %PolyRoot.ChildInteger{
                  __type__: PolyRoot.ChildInteger,
                  id: "c1",
                  value: 42
                },
                %PolyRoot.ChildString{
                  __type__: PolyRoot.ChildString,
                  id: "c2",
                  value: "fortytwo"
                }
              ]} ==
               Ecto.Type.dump(
                 PolyRoot.__schema__(:type, :root_children),
                 %{
                   "c1" => %PolyRoot.ChildInteger{
                     __type__: PolyRoot.ChildInteger,
                     id: "c1",
                     value: 42
                   },
                   "c2" => %PolyRoot.ChildString{
                     __type__: PolyRoot.ChildString,
                     id: "c2",
                     value: "fortytwo"
                   }
                 }
               )
    end
  end
end
