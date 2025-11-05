if Code.ensure_loaded?(Igniter.Mix.Task) do
  defmodule Mix.Tasks.NbSerializer.Install do
    @shortdoc "Installs and configures NbSerializer in your Phoenix application"

    @moduledoc """
    Installs and configures NbSerializer with optional integrations.

    ## Usage

        mix nb_serializer.install [options]

    ## Options

      * `--with-ecto` - Add Ecto integration for seamless schema serialization
      * `--with-phoenix` - Add Phoenix integration for automatic JSON rendering
      * `--with-typescript` - Add TypeScript support (adds nb_ts dependency)
      * `--camelize-props` - Enable automatic camelCase conversion for props (recommended for JS/TS frontends)
      * `--yes` - Skip all confirmation prompts

    ## Examples

        # Basic installation
        mix nb_serializer.install

        # Full installation with all integrations
        mix nb_serializer.install --with-ecto --with-phoenix --with-typescript --camelize-props

        # Quick install without prompts
        mix nb_serializer.install --with-ecto --with-phoenix --yes

    ## What it does

    This installer will:

      1. Add `nb_serializer` dependency to mix.exs
      2. Optionally add `nb_ts` dependency if --with-typescript is specified
      3. Add configuration to config/config.exs
      4. Create an example serializer demonstrating best practices
      5. Print helpful next steps for getting started

    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        group: :nb_serializer,
        example: "mix nb_serializer.install --with-ecto --with-phoenix",
        schema: [
          with_ecto: :boolean,
          with_phoenix: :boolean,
          with_typescript: :boolean,
          camelize_props: :boolean,
          yes: :boolean
        ],
        aliases: [
          y: :yes
        ],
        defaults: [
          with_ecto: false,
          with_phoenix: false,
          with_typescript: false,
          camelize_props: false,
          yes: false
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      with_ecto = igniter.args.options[:with_ecto] || false
      with_phoenix = igniter.args.options[:with_phoenix] || false
      with_typescript = igniter.args.options[:with_typescript] || false
      camelize_props = igniter.args.options[:camelize_props] || false
      skip_prompts = igniter.args.options[:yes] || false

      igniter
      |> print_welcome_message(skip_prompts)
      |> add_nb_serializer_dependency()
      |> maybe_add_optional_dependencies(with_ecto, with_phoenix, with_typescript)
      |> add_configuration(camelize_props, with_ecto, with_phoenix)
      |> create_example_serializer(with_ecto)
      |> print_next_steps(with_ecto, with_phoenix, with_typescript, camelize_props)
    end

    defp print_welcome_message(igniter, skip_prompts) do
      unless skip_prompts do
        Mix.shell().info("""

        ╔═══════════════════════════════════════════════════════════════╗
        ║                                                               ║
        ║              Welcome to NbSerializer Installer                ║
        ║                                                               ║
        ║   Fast & Declarative JSON Serialization for Elixir           ║
        ║                                                               ║
        ╚═══════════════════════════════════════════════════════════════╝

        This installer will set up NbSerializer in your project with:
          - Core serialization library
          - Example serializer with best practices
          - Configuration files
          - Optional integrations (Ecto, Phoenix, TypeScript)

        """)
      end

      igniter
    end

    defp add_nb_serializer_dependency(igniter) do
      Igniter.Project.Deps.add_dep(igniter, {:nb_serializer, "~> 0.2"})
    end

    defp maybe_add_optional_dependencies(igniter, with_ecto, with_phoenix, with_typescript) do
      igniter
      |> maybe_add_ecto(with_ecto)
      |> maybe_add_phoenix(with_phoenix)
      |> maybe_add_typescript(with_typescript)
    end

    defp maybe_add_ecto(igniter, true) do
      Igniter.Project.Deps.add_dep(igniter, {:ecto, "~> 3.10"})
    end

    defp maybe_add_ecto(igniter, _), do: igniter

    defp maybe_add_phoenix(igniter, true) do
      igniter
      |> Igniter.Project.Deps.add_dep({:phoenix, "~> 1.7"})
      |> Igniter.Project.Deps.add_dep({:plug, "~> 1.14"})
    end

    defp maybe_add_phoenix(igniter, _), do: igniter

    defp maybe_add_typescript(igniter, true) do
      Igniter.Project.Deps.add_dep(igniter, {:nb_ts, "~> 0.1"})
    end

    defp maybe_add_typescript(igniter, _), do: igniter

    defp add_configuration(igniter, camelize_props, _with_ecto, _with_phoenix) do
      # Use Igniter's built-in config management to set camelize_props
      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :nb_serializer,
        [:camelize_props],
        camelize_props
      )
    end

    defp create_example_serializer(igniter, with_ecto) do
      app_name = Igniter.Project.Application.app_name(igniter)

      # Build the module name: MyApp.Serializers.ExampleSerializer
      module_name =
        Module.concat([
          String.to_atom(Macro.camelize(to_string(app_name))),
          Serializers,
          ExampleSerializer
        ])

      serializer_content = build_example_serializer_content(module_name, with_ecto)

      # Use Igniter's create_module to properly place the file with error handling
      case Igniter.Project.Module.create_module(igniter, module_name, serializer_content) do
        {:error, igniter} ->
          Igniter.add_warning(
            igniter,
            "Could not create example serializer at #{inspect(module_name)}. You may need to manually create your first serializer."
          )

        result ->
          result
      end
    end

    defp build_example_serializer_content(module_name, with_ecto) do
      # Extract the base app module name for references in documentation
      base_module = module_name |> Module.split() |> List.first()

      ecto_association =
        if with_ecto do
          """

              # Association example (requires Ecto)
              # Serializes nested data using another serializer
              # has_one :author, serializer: #{base_module}.Serializers.AuthorSerializer
              # has_many :comments, serializer: #{base_module}.Serializers.CommentSerializer
          """
        else
          ""
        end

      ecto_note =
        if with_ecto do
          """

          ## Ecto Integration

          When working with Ecto schemas, NbSerializer automatically handles:
          - Unloaded associations (returns nil instead of %Ecto.Association.NotLoaded{})
          - Embedded schemas
          - Virtual fields
          - Changesets (serializes the data, not the changeset struct)

          Example with Ecto:

              # Assuming you have a Post schema with author association
              post = Repo.get(Post, 1) |> Repo.preload(:author)
              {:ok, json} = NbSerializer.serialize(PostSerializer, post)

          """
        else
          ""
        end

      """
      @moduledoc \"\"\"
      Example serializer demonstrating NbSerializer best practices.

      This serializer shows:
      - Basic field definitions
      - Computed fields
      - Conditional fields
      - Field transformations#{if with_ecto, do: "\n  - Associations (Ecto)", else: ""}

      ## Usage

          # Serialize a single record
          data = %{
            id: 1,
            title: "Getting Started with NbSerializer",
            body: "This is a comprehensive guide to using NbSerializer in your Elixir application...",
            status: "published",
            author_id: 42,
            published_at: ~U[2024-01-15 10:30:00Z]
          }

          {:ok, result} = NbSerializer.serialize(#{module_name}, data)

          # Serialize a list of records
          {:ok, results} = NbSerializer.serialize(#{module_name}, [data])

          # With options
          {:ok, result} = NbSerializer.serialize(
            #{module_name},
            data,
            view: :admin,
            current_scope: current_user
          )
      #{ecto_note}
      For more information, see: https://hexdocs.pm/nb_serializer
      \"\"\"

      use NbSerializer.Serializer

      schema do
        # Basic fields - directly map from source data
        field :id, :number
        field :title, :string

        # Computed field - derives value from source data
        # The compute function receives the data and opts
        field :excerpt, :string, compute: :generate_excerpt

        # Conditional field - only included when condition is met
        # Useful for admin-only fields, permission-based data, etc.
        field :author_id, :number, if: :show_author_id?

        # Field with transformation
        # Format DateTime to ISO8601 string
        field :published_at, :datetime, transform: &format_datetime/1

        # Computed field with pattern matching
        field :status_label, :string, compute: :format_status
      #{ecto_association}
      end

      # Computed field function
      # Generates an excerpt from the body text
      def generate_excerpt(%{body: body}, _opts) when is_binary(body) do
        body
        |> String.slice(0, 150)
        |> Kernel.<>("...")
      end

      def generate_excerpt(_data, _opts), do: ""

      # Conditional function
      # Shows author_id only to admin users
      def show_author_id?(_data, opts) do
        case Keyword.get(opts, :view) do
          :admin -> true
          _ -> false
        end
      end

      # Transform function
      # Formats DateTime to ISO8601 string
      defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
      defp format_datetime(nil), do: nil
      defp format_datetime(value), do: value

      # Computed field with pattern matching
      # Returns user-friendly status labels
      def format_status(%{status: "draft"}, _opts), do: "Draft"
      def format_status(%{status: "published"}, _opts), do: "Published"
      def format_status(%{status: "archived"}, _opts), do: "Archived"
      def format_status(_data, _opts), do: "Unknown"
      """
    end

    defp print_next_steps(
           igniter,
           with_ecto,
           with_phoenix,
           with_typescript,
           camelize_props
         ) do
      Igniter.add_notice(igniter, """

      ╔═══════════════════════════════════════════════════════════════╗
      ║                                                               ║
      ║           NbSerializer Installation Complete!                 ║
      ║                                                               ║
      ╚═══════════════════════════════════════════════════════════════╝

      Installation Summary:
      #{format_installation_summary(with_ecto, with_phoenix, with_typescript, camelize_props)}

      Next Steps:

      1. Install dependencies:
         $ mix deps.get

      2. Review the example serializer created at:
         lib/#{Igniter.Project.Application.app_name(igniter)}/serializers/example_serializer.ex

      3. Create your first serializer:

         defmodule MyApp.Serializers.UserSerializer do
           use NbSerializer.Serializer

           schema do
             field :id, :number
             field :name, :string
             field :email, :string
           end
         end

      4. Use it in your application:

         user = %{id: 1, name: "Alice", email: "alice@example.com"}
         {:ok, json_map} = NbSerializer.serialize(MyApp.Serializers.UserSerializer, user)
         json_string = NbSerializer.to_json!(MyApp.Serializers.UserSerializer, user)
      #{format_integration_steps(with_ecto, with_phoenix, with_typescript)}

      Documentation & Resources:

        • Hex Docs: https://hexdocs.pm/nb_serializer
        • GitHub: https://github.com/nordbeam/nb_serializer
        • Examples: Check the example_serializer.ex for common patterns

      Happy serializing! 🚀
      """)
    end

    defp format_installation_summary(with_ecto, with_phoenix, with_typescript, camelize_props) do
      items = [
        "✓ NbSerializer core library",
        if(with_ecto, do: "✓ Ecto integration enabled", else: nil),
        if(with_phoenix, do: "✓ Phoenix integration enabled", else: nil),
        if(with_typescript, do: "✓ TypeScript support (nb_ts) added", else: nil),
        if(camelize_props, do: "✓ Automatic camelCase conversion enabled", else: nil)
      ]

      items
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&("    " <> &1))
      |> Enum.join("\n")
    end

    defp format_integration_steps(with_ecto, with_phoenix, with_typescript) do
      ecto_steps =
        if with_ecto do
          """

          5. Using with Ecto schemas:

             # Make sure to preload associations before serializing
             post = Repo.get!(Post, id) |> Repo.preload([:author, :comments])
             {:ok, json} = NbSerializer.serialize(PostSerializer, post)
          """
        else
          ""
        end

      phoenix_steps =
        if with_phoenix do
          """

          #{if with_ecto, do: "6", else: "5"}. Using with Phoenix controllers:

             defmodule MyAppWeb.UserController do
               use MyAppWeb, :controller

               def show(conn, %{"id" => id}) do
                 user = MyApp.get_user!(id)

                 json(conn, NbSerializer.serialize!(UserSerializer, user))
               end
             end

             # Or use the Phoenix integration for automatic rendering:
             render(conn, :show, user: user, serializer: UserSerializer)
          """
        else
          ""
        end

      typescript_steps =
        if with_typescript do
          next_num =
            cond do
              with_ecto && with_phoenix -> "7"
              with_ecto || with_phoenix -> "6"
              true -> "5"
            end

          """

          #{next_num}. Generate TypeScript types:

             $ mix nb_ts.gen.types

             This will generate TypeScript interfaces from your serializers.
             See: https://hexdocs.pm/nb_ts for more information.
          """
        else
          ""
        end

      ecto_steps <> phoenix_steps <> typescript_steps
    end
  end
end
