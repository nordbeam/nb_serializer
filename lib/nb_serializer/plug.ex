defmodule NbSerializer.Plug do
  @moduledoc """
  Plug middleware for automatic serialization of controller assigns.

  This plug automatically serializes specified assigns using NbSerializer serializers
  and sends the JSON response.

  ## Usage

      # In your router or controller
      plug NbSerializer.Plug,
        serializers: %{
          user: UserSerializer,
          users: UserSerializer,
          post: PostSerializer,
          posts: PostSerializer
        }

  ## Options

    * `:serializers` - Map of assign names to serializer modules (required)
    * `:only` - List of assigns to serialize (optional, serializes all by default)
    * `:except` - List of assigns to exclude from serialization (optional)
    * `:meta` - Metadata to include in response (map or function)
    * `:cache` - Enable response caching (default: false)
    * `:cache_ttl` - Cache TTL in seconds (default: 300)
  """

  import Plug.Conn
  @behaviour Plug

  # Type definitions
  @type opts :: %{
          serializers: map(),
          only: list(atom()) | nil,
          except: list(atom()),
          meta: map() | function() | nil,
          cache: boolean(),
          cache_ttl: integer()
        }

  @impl true
  @spec init(keyword()) :: opts()
  def init(opts) do
    serializers = Keyword.fetch!(opts, :serializers)

    %{
      serializers: serializers,
      only: Keyword.get(opts, :only),
      except: Keyword.get(opts, :except, []),
      meta: Keyword.get(opts, :meta),
      cache: Keyword.get(opts, :cache, false),
      cache_ttl: Keyword.get(opts, :cache_ttl, 300)
    }
  end

  @impl true
  @spec call(Plug.Conn.t(), opts()) :: Plug.Conn.t()
  def call(%{halted: true} = conn, _opts), do: conn

  def call(conn, opts) do
    assigns_to_serialize = get_assigns_to_serialize(conn, opts)

    if Enum.empty?(assigns_to_serialize) do
      conn
    else
      serialized = serialize_assigns(conn, assigns_to_serialize, opts)
      send_response(conn, serialized, opts)
    end
  end

  defp get_assigns_to_serialize(conn, opts) do
    available_assigns = Map.keys(conn.assigns)
    serializer_keys = Map.keys(opts.serializers)

    # Find assigns that have serializers
    matching_assigns = Enum.filter(available_assigns, &(&1 in serializer_keys))

    # Apply only/except filters
    matching_assigns
    |> filter_only(opts.only)
    |> filter_except(opts.except)
  end

  defp filter_only(assigns, nil), do: assigns
  defp filter_only(assigns, only), do: Enum.filter(assigns, &(&1 in only))

  defp filter_except(assigns, except), do: Enum.reject(assigns, &(&1 in except))

  defp serialize_assigns(conn, assigns_to_serialize, opts) do
    serialized_data =
      Enum.reduce(assigns_to_serialize, %{}, fn assign_name, acc ->
        data = conn.assigns[assign_name]
        serializer = opts.serializers[assign_name]

        serialized =
          case NbSerializer.serialize(serializer, data, root: to_string(assign_name)) do
            {:ok, result} -> result
            {:error, _} -> %{}
          end

        # Extract the root key and merge
        {root_key, serialized_value} = extract_root(serialized)
        Map.put(acc, root_key, serialized_value)
      end)

    # Add metadata if configured
    add_metadata(serialized_data, conn, opts)
  end

  defp extract_root(serialized) when is_map(serialized) do
    case Map.to_list(serialized) do
      [{key, value}] -> {key, value}
      _ -> {"data", serialized}
    end
  end

  defp add_metadata(data, _conn, %{meta: nil}), do: data

  defp add_metadata(data, conn, %{meta: meta_fn}) when is_function(meta_fn, 1) do
    Map.put(data, "meta", meta_fn.(conn))
  end

  defp add_metadata(data, _conn, %{meta: meta}) when is_map(meta) do
    Map.put(data, "meta", meta)
  end

  defp send_response(conn, data, opts) do
    json = NbSerializer.encoder().encode!(data)

    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> maybe_add_cache_headers(data, opts)
    |> send_resp(200, json)
  end

  defp maybe_add_cache_headers(conn, _data, %{cache: false}), do: conn

  defp maybe_add_cache_headers(conn, data, %{cache: true, cache_ttl: ttl}) do
    etag = generate_etag(data)

    conn
    |> put_resp_header("cache-control", "max-age=#{ttl}, public")
    |> put_resp_header("etag", etag)
  end

  defp generate_etag(data) do
    hash =
      data
      |> :erlang.term_to_binary()
      |> then(&:crypto.hash(:md5, &1))
      |> Base.encode16(case: :lower)

    ~s("#{hash}")
  end
end
