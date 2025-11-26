defmodule NbSerializer.Credo.ChecksTest do
  use ExUnit.Case, async: false

  alias NbSerializer.Credo.Check.Warning.InvalidNestedSerializerType
  alias NbSerializer.Credo.Check.Warning.OptionalVsNullable
  alias NbSerializer.Credo.Check.Warning.InconsistentNumericTypes
  alias NbSerializer.Credo.Check.Warning.DatetimeAsString
  alias NbSerializer.Credo.Check.Warning.MissingDatetimeFormat
  alias NbSerializer.Credo.Check.Readability.MissingModuledoc
  alias NbSerializer.Credo.Check.Design.LargeSchema
  alias NbSerializer.Credo.Check.Design.SimpleFieldCompute

  # Start Credo services before running tests
  setup_all do
    Application.ensure_all_started(:credo)
    :ok
  end

  describe "InvalidNestedSerializerType" do
    test "warns when using serializer module directly as field type" do
      source = """
      defmodule MyApp.WidgetPresetSerializer do
        use NbSerializer.Serializer

        schema do
          field :config, WidgetConfigSerializer
        end
      end
      """

      issues = run_check(InvalidNestedSerializerType, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":config"
      assert hd(issues).message =~ "WidgetConfigSerializer"
      assert hd(issues).message =~ "has_one"
    end

    test "does not warn for valid field types" do
      source = """
      defmodule MyApp.UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
          field :name, :string
          has_one :profile, ProfileSerializer
        end
      end
      """

      issues = run_check(InvalidNestedSerializerType, source)
      assert issues == []
    end

    test "does not warn for non-serializer modules" do
      source = """
      defmodule MyApp.UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :role, UserRole
        end
      end
      """

      issues = run_check(InvalidNestedSerializerType, source)
      assert issues == []
    end
  end

  describe "OptionalVsNullable" do
    test "warns when using optional: true" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :visitor_id, :string, optional: true
        end
      end
      """

      issues = run_check(OptionalVsNullable, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":visitor_id"
      assert hd(issues).message =~ "nullable: true"
    end

    test "does not warn when using nullable: true" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :visitor_id, :string, nullable: true
        end
      end
      """

      issues = run_check(OptionalVsNullable, source)
      assert issues == []
    end
  end

  describe "InconsistentNumericTypes" do
    test "warns when using :integer" do
      source = """
      defmodule MyApp.StatsSerializer do
        use NbSerializer.Serializer

        schema do
          field :total_views, :integer
        end
      end
      """

      issues = run_check(InconsistentNumericTypes, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":total_views"
      assert hd(issues).message =~ ":integer"
      assert hd(issues).message =~ ":number"
    end

    test "warns when using :float" do
      source = """
      defmodule MyApp.StatsSerializer do
        use NbSerializer.Serializer

        schema do
          field :average_rating, :float
        end
      end
      """

      issues = run_check(InconsistentNumericTypes, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":average_rating"
      assert hd(issues).message =~ ":float"
    end

    test "does not warn when using :number" do
      source = """
      defmodule MyApp.StatsSerializer do
        use NbSerializer.Serializer

        schema do
          field :total_views, :number
          field :average_rating, :number
        end
      end
      """

      issues = run_check(InconsistentNumericTypes, source)
      assert issues == []
    end
  end

  describe "DatetimeAsString" do
    test "warns when _at field is declared as :string" do
      source = """
      defmodule MyApp.MemberSerializer do
        use NbSerializer.Serializer

        schema do
          field :joined_at, :string
        end
      end
      """

      issues = run_check(DatetimeAsString, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":joined_at"
      assert hd(issues).message =~ ":datetime"
    end

    test "warns when _date field is declared as :string" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :event_date, :string
        end
      end
      """

      issues = run_check(DatetimeAsString, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":event_date"
    end

    test "does not warn when datetime field uses :datetime" do
      source = """
      defmodule MyApp.MemberSerializer do
        use NbSerializer.Serializer

        schema do
          field :joined_at, :datetime, format: :iso8601
        end
      end
      """

      issues = run_check(DatetimeAsString, source)
      assert issues == []
    end

    test "does not warn for non-datetime string fields" do
      source = """
      defmodule MyApp.UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :name, :string
          field :email, :string
        end
      end
      """

      issues = run_check(DatetimeAsString, source)
      assert issues == []
    end
  end

  describe "MissingDatetimeFormat" do
    test "warns when :datetime has no format option" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :created_at, :datetime
        end
      end
      """

      issues = run_check(MissingDatetimeFormat, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":created_at"
      assert hd(issues).message =~ "format"
    end

    test "warns when :datetime has options but no format" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :created_at, :datetime, nullable: true
        end
      end
      """

      issues = run_check(MissingDatetimeFormat, source)
      assert length(issues) == 1
    end

    test "does not warn when :datetime has format option" do
      source = """
      defmodule MyApp.EventSerializer do
        use NbSerializer.Serializer

        schema do
          field :created_at, :datetime, format: :iso8601
        end
      end
      """

      issues = run_check(MissingDatetimeFormat, source)
      assert issues == []
    end
  end

  describe "MissingModuledoc" do
    test "warns when serializer has no @moduledoc" do
      source = """
      defmodule MyApp.UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
        end
      end
      """

      issues = run_check(MissingModuledoc, source)
      assert length(issues) == 1
      assert hd(issues).message =~ "UserSerializer"
      assert hd(issues).message =~ "@moduledoc"
    end

    test "does not warn when serializer has @moduledoc" do
      source = """
      defmodule MyApp.UserSerializer do
        @moduledoc \"\"\"
        Serializes user data.
        \"\"\"
        use NbSerializer.Serializer

        schema do
          field :id, :number
        end
      end
      """

      issues = run_check(MissingModuledoc, source)
      assert issues == []
    end

    test "does not warn for non-serializer modules" do
      source = """
      defmodule MyApp.SomeModule do
        def hello, do: :world
      end
      """

      issues = run_check(MissingModuledoc, source)
      assert issues == []
    end
  end

  describe "LargeSchema" do
    test "warns when schema has more than max_fields" do
      fields = for i <- 1..45, do: "field :field_#{i}, :string"
      fields_str = Enum.join(fields, "\n      ")

      source = """
      defmodule MyApp.LargeSerializer do
        use NbSerializer.Serializer

        schema do
          #{fields_str}
        end
      end
      """

      issues = run_check(LargeSchema, source, max_fields: 40)
      assert length(issues) == 1
      assert hd(issues).message =~ "45 fields"
      assert hd(issues).message =~ "splitting"
    end

    test "does not warn when schema is within limit" do
      source = """
      defmodule MyApp.SmallSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
          field :name, :string
        end
      end
      """

      issues = run_check(LargeSchema, source, max_fields: 40)
      assert issues == []
    end

    test "counts has_one and has_many as fields" do
      fields = for i <- 1..35, do: "field :field_#{i}, :string"
      has_ones = for i <- 1..10, do: "has_one :relation_#{i}, Serializer#{i}"
      all_fields = Enum.join(fields ++ has_ones, "\n      ")

      source = """
      defmodule MyApp.MixedSerializer do
        use NbSerializer.Serializer

        schema do
          #{all_fields}
        end
      end
      """

      issues = run_check(LargeSchema, source, max_fields: 40)
      assert length(issues) == 1
      assert hd(issues).message =~ "45 fields"
    end
  end

  describe "SimpleFieldCompute" do
    test "warns when compute function simply copies a field" do
      source = """
      defmodule MyApp.PaginationSerializer do
        use NbSerializer.Serializer

        schema do
          field :total, :number, compute: :compute_total
        end

        def compute_total(pagination, _opts), do: pagination.total_entries
      end
      """

      issues = run_check(SimpleFieldCompute, source)
      assert length(issues) == 1
      assert hd(issues).message =~ ":total"
      assert hd(issues).message =~ "compute_total"
      assert hd(issues).message =~ "from:"
    end

    test "does not warn when compute function does actual computation" do
      source = """
      defmodule MyApp.VideoSerializer do
        use NbSerializer.Serializer

        schema do
          field :is_ready, :boolean, compute: :compute_is_ready
        end

        def compute_is_ready(video, _opts) do
          video.status == "complete" and video.url != nil
        end
      end
      """

      issues = run_check(SimpleFieldCompute, source)
      assert issues == []
    end

    test "does not warn when field uses from: option" do
      source = """
      defmodule MyApp.SpaceSerializer do
        use NbSerializer.Serializer

        schema do
          field :created_at, :datetime, format: :iso8601, from: :inserted_at
        end
      end
      """

      issues = run_check(SimpleFieldCompute, source)
      assert issues == []
    end
  end

  # Helper to run a Credo check on source code
  defp run_check(check_module, source_code, params \\ []) do
    source_file = source_to_source_file(source_code)
    check_module.run(source_file, params)
  end

  defp source_to_source_file(source_code) do
    Credo.SourceFile.parse(source_code, "test.ex")
  end
end
