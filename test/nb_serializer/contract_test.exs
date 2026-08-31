defmodule NbSerializer.ContractTest do
  use ExUnit.Case, async: true

  defmodule ChildSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :integer)
    end
  end

  defmodule UserSerializer do
    use NbSerializer.Serializer

    schema do
      field(:created_at, :datetime)
      field(:display_name, :string, from: :name, transform: :normalize_name)
      field(:secret, :string, unless: :public?, on_error: :skip)
      field(:metadata, type: ~s|{ total: number }|, on_error: :null)
      field(:children, list: ChildSerializer)
      has_one(:profile, serializer: ChildSerializer, on_missing: :null)
    end

    def normalize_name(value), do: value
    def public?(_data, _opts), do: false
  end

  test "exposes a deterministic normalized serializer contract" do
    contract = NbSerializer.Contract.build(UserSerializer)

    assert contract.version == 1
    assert contract.kind == :serializer
    assert contract.name == "User"

    assert Enum.map(contract.fields, & &1.name) == [
             :children,
             :created_at,
             :display_name,
             :metadata,
             :secret
           ]

    secret = Enum.find(contract.fields, &(&1.name == :secret))
    assert secret.optional
    assert secret.unless == :public?
    assert secret.on_error == :skip

    metadata = Enum.find(contract.fields, &(&1.name == :metadata))
    assert metadata.nullable
    assert metadata.on_error == :null

    children = Enum.find(contract.fields, &(&1.name == :children))
    assert children.list == ChildSerializer

    [profile] = contract.relationships
    assert profile.name == :profile
    assert profile.serializer == ChildSerializer
    assert profile.nullable
  end

  test "the contract callback and build helper return the same snapshot" do
    assert UserSerializer.__nb_serializer_contract__() ==
             NbSerializer.Contract.build(UserSerializer)
  end
end
