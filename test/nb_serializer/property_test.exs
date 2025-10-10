defmodule NbSerializer.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "serialization is idempotent" do
    check all(
            data <- map_of(atom(:alphanumeric), term()),
            max_runs: 100
          ) do
      defmodule TestIdempotentSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        field(:value)
      end

      {:ok, result1} = NbSerializer.serialize(TestIdempotentSerializer, data)
      {:ok, result2} = NbSerializer.serialize(TestIdempotentSerializer, result1)

      assert result1 == result2
    end
  end

  property "handles nil values consistently" do
    check all(
            data <- map_of(atom(:alphanumeric), one_of([nil, term()])),
            max_runs: 100
          ) do
      defmodule TestNilHandlingSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        field(:value)
        field(:status)
      end

      {:ok, result} = NbSerializer.serialize(TestNilHandlingSerializer, data)

      # Verify that nil values are handled consistently
      for {key, value} <- data do
        if key in [:id, :name, :value, :status] do
          case value do
            nil -> assert Map.get(result, key) == nil
            _ -> assert Map.has_key?(result, key)
          end
        end
      end
    end
  end

  property "default values are applied when fields are nil" do
    defmodule TestDefaultValueSerializer do
      use NbSerializer.Serializer

      field(:test_field, default: "default_value")
    end

    data = %{}
    {:ok, result} = NbSerializer.serialize(TestDefaultValueSerializer, data)

    assert Map.get(result, :test_field) == "default_value"
  end

  property "transforms are applied consistently" do
    check all(
            input <- string(:alphanumeric, min_length: 1),
            max_runs: 100
          ) do
      defmodule TestTransformAppliedSerializer do
        use NbSerializer.Serializer

        field(:test_field, transform: :upcase_transform)

        def upcase_transform(value) when is_binary(value) do
          String.upcase(value)
        end

        def upcase_transform(value), do: value
      end

      data = %{test_field: input}
      {:ok, result} = NbSerializer.serialize(TestTransformAppliedSerializer, data)

      assert Map.get(result, :test_field) == String.upcase(input)
    end
  end

  property "serializes lists of items correctly" do
    check all(
            items <- list_of(map_of(atom(:alphanumeric), term()), max_length: 10),
            max_runs: 100
          ) do
      defmodule TestListSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
      end

      {:ok, result} = NbSerializer.serialize(TestListSerializer, items)

      assert is_list(result)
      assert length(result) == length(items)
    end
  end

  property "conditional fields are included/excluded correctly" do
    check all(
            include? <- boolean(),
            value <- term(),
            max_runs: 100
          ) do
      defmodule TestConditionalFieldSerializer do
        use NbSerializer.Serializer

        field(:conditional_field, if: :should_include?)

        def should_include?(_data, opts) do
          Keyword.get(opts, :include_field, false)
        end
      end

      data = %{conditional_field: value}

      {:ok, result} =
        NbSerializer.serialize(TestConditionalFieldSerializer, data, include_field: include?)

      if include? do
        assert Map.has_key?(result, :conditional_field)
      else
        refute Map.has_key?(result, :conditional_field)
      end
    end
  end

  property "error handling with ok/error tuples" do
    check all(
            data <- map_of(atom(:alphanumeric), term()),
            max_runs: 100
          ) do
      defmodule TestErrorSerializer do
        use NbSerializer.Serializer

        field(:safe_field)
        field(:error_field, compute: :compute_error)

        def compute_error(_data, _opts) do
          raise "Intentional error"
        end
      end

      # Serialization should return an error tuple
      result = NbSerializer.serialize(TestErrorSerializer, data)
      assert {:error, _} = result
    end
  end

  property "root key wrapping works correctly" do
    check all(
            root_key <- string(:alphanumeric, min_length: 1, max_length: 10),
            data <- map_of(atom(:alphanumeric), term()),
            max_runs: 100
          ) do
      defmodule TestRootSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
      end

      {:ok, result} = NbSerializer.serialize(TestRootSerializer, data, root: root_key)

      assert Map.has_key?(result, root_key)
      assert is_map(Map.get(result, root_key))
    end
  end

  property "metadata is included when specified" do
    check all(
            meta <- map_of(string(:alphanumeric), term()),
            data <- map_of(atom(:alphanumeric), term()),
            max_runs: 100
          ) do
      defmodule TestMetaSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
      end

      {:ok, result} = NbSerializer.serialize(TestMetaSerializer, data, meta: meta)

      assert Map.has_key?(result, :meta)
      assert Map.get(result, :meta) == meta
    end
  end
end
