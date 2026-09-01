defmodule Mix.Tasks.NbSerializer.InstallTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.NbSerializer.Install
  import Igniter.Test, only: [apply_igniter!: 1, test_project: 1]

  describe "info/2" do
    test "declares the companion installer for requested TypeScript support" do
      info = Install.info(["--with-typescript"], nil)

      assert info.composes == ["nb_ts.install"]
    end

    test "declares optional deps for requested integrations" do
      options = Install.installer_options(["--with-ecto", "--with-phoenix", "--with-typescript"])

      assert Install.optional_dependency_specs(options, []) == [
               {:ecto, "~> 3.10"},
               {:plug, "~> 1.14"},
               {:nb_ts, github: "nordbeam/nb_ts"}
             ]
    end

    test "parses grouped igniter flags for shared nb task namespaces" do
      options = Install.installer_options(["--nb.with-ecto", "--nb.with-typescript"])

      assert Install.optional_dependency_specs(options, []) == [
               {:ecto, "~> 3.10"},
               {:nb_ts, github: "nordbeam/nb_ts"}
             ]
    end

    test "skips already installed optional dependencies" do
      options = Install.installer_options(["--with-ecto", "--with-phoenix", "--with-typescript"])

      assert Install.optional_dependency_specs(options, [:ecto, :plug, :nb_ts]) == []

      assert Install.optional_dependency_specs(options, [:ecto, :plug]) == [
               {:nb_ts, github: "nordbeam/nb_ts"}
             ]
    end
  end

  describe "forwarded_global_argv/1" do
    test "keeps only child-safe confirmation flags" do
      assert Install.forwarded_global_argv([
               "--yes",
               "--verbose",
               "--only",
               "dev",
               "--with-typescript"
             ]) == ["--yes"]
    end
  end

  describe "example serializer generation" do
    test "preserves an existing example serializer on interrupted installer reruns" do
      path = "lib/sample/serializers/example_serializer.ex"

      existing = """
      defmodule Sample.Serializers.ExampleSerializer do
        use NbSerializer.Serializer
        field(:custom, :string)
      end
      """

      files =
        test_project(app_name: :sample, files: %{path => existing})
        |> Install.create_example_serializer(false)
        |> apply_igniter!()
        |> then(& &1.assigns.test_files)

      assert files[path] == existing
    end
  end

  test "hex package includes UsageRules documentation and prebuilt skill" do
    package_files = NbSerializer.MixProject.project()[:package][:files]

    assert "usage-rules.md" in package_files
    assert "usage-rules" in package_files

    assert File.exists?(Path.expand("../../../../usage-rules.md", __DIR__))
    skill_path = Path.expand("../../../../usage-rules/skills/nb-serializer/SKILL.md", __DIR__)
    assert File.exists?(skill_path)
  end

  test "ships the progressive serializer contract reference" do
    root = Path.expand("../../../../", __DIR__)
    skill = File.read!(Path.join(root, "usage-rules/skills/nb-serializer/SKILL.md"))

    reference =
      File.read!(
        Path.join(root, "usage-rules/skills/nb-serializer/references/ecto-inertia-boundaries.md")
      )

    assert skill =~ "references/ecto-inertia-boundaries.md"
    assert reference =~ "NbSerializer.serialize/2"
    assert reference =~ "NbSerializer.serialize(serializer, data"
    assert reference =~ "on_missing: :null"
    assert reference =~ "{Serializer, value}"
    assert reference =~ "list_of(ref(MyApp.Blog.PostSerializer))"
    assert reference =~ "compute_name(data, opts)"
  end
end
