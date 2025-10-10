defmodule NbSerializer.DSLTypelizerDebugTest do
  use ExUnit.Case

  defmodule TestSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:name, :string)
    end
  end

  test "fields are accessible via __nb_serializer_fields__/0" do
    # Fields should be accessible via the compiled function, not __info__(:attributes)
    fields = TestSerializer.__nb_serializer_fields__()

    assert fields == [
             {:id, [type: :number]},
             {:name, [type: :string]}
           ]

    # Verify serialization works
    result = TestSerializer.serialize(%{id: 1, name: "test"})
    assert result == %{id: 1, name: "test"}
  end
end
