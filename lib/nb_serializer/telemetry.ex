defmodule NbSerializer.Telemetry do
  @moduledoc """
  Telemetry events for NbSerializer serialization monitoring.

  ## Events

  NbSerializer emits the following telemetry events:

  ### `[:nb_serializer, :serialize, :start]`

  Emitted when serialization starts.

  #### Measurements
    * `:system_time` - System time when serialization started
    * `:monotonic_time` - Monotonic time when serialization started

  #### Metadata
    * `:serializer` - The serializer module being used
    * `:data_type` - The type of data being serialized (struct name or :map)
    * `:is_list` - Whether the data is a list
    * `:opts` - Options passed to the serializer

  ### `[:nb_serializer, :serialize, :stop]`

  Emitted when serialization completes successfully.

  #### Measurements
    * `:duration` - Duration of serialization in native time units
    * `:fields_count` - Number of fields in the serialized result

  #### Metadata
    * `:serializer` - The serializer module being used
    * `:data_type` - The type of data being serialized
    * `:is_list` - Whether the data is a list
    * `:opts` - Options passed to the serializer
    * `:fields_count` - Number of fields serialized (for single items)

  ### `[:nb_serializer, :serialize, :exception]`

  Emitted when serialization fails with an exception.

  #### Measurements
    * `:duration` - Duration before the exception occurred

  #### Metadata
    * `:serializer` - The serializer module being used
    * `:data_type` - The type of data being serialized
    * `:is_list` - Whether the data is a list
    * `:opts` - Options passed to the serializer
    * `:kind` - The kind of exception (:error, :exit, :throw)
    * `:error` - The exception or error value
    * `:stacktrace` - The stacktrace

  ## Example Usage

  Attach a handler to log serialization events:

      :telemetry.attach(
        "nb_serializer-logger",
        [:nb_serializer, :serialize, :stop],
        fn event, measurements, metadata, _config ->
          duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
          IO.puts("Serialized with \#{metadata.serializer} in \#{duration_ms}ms")
        end,
        nil
      )

  ## Metrics Recommendations

  For production monitoring, consider tracking:

  1. **Serialization Duration** - Track p50, p95, p99 latencies
  2. **Error Rate** - Monitor the ratio of exceptions to successful serializations
  3. **Throughput** - Count of serializations per second
  4. **Field Count Distribution** - Understand the size of payloads being serialized
  """

  @doc """
  Executes a serialization operation with telemetry instrumentation.

  Wraps the given function with telemetry start/stop/exception events.
  """
  @spec execute_serialize(module(), any(), keyword(), function()) ::
          {:ok, any()} | {:error, any()}
  def execute_serialize(serializer, data, opts, fun) do
    metadata = build_metadata(serializer, data, opts)

    :telemetry.span(
      [:nb_serializer, :serialize],
      metadata,
      fn ->
        case fun.() do
          {:ok, result} = success ->
            updated_metadata = add_result_metadata(metadata, result)
            {success, updated_metadata}

          {:error, _} = error ->
            {error, metadata}
        end
      end
    )
  end

  defp build_metadata(serializer, data, opts) do
    %{
      serializer: serializer,
      data_type: get_data_type(data),
      is_list: is_list(data),
      opts: opts
    }
  end

  defp get_data_type(data) when is_list(data) do
    case List.first(data) do
      nil -> :empty_list
      %{__struct__: struct} -> struct
      _ -> :list
    end
  end

  defp get_data_type(%{__struct__: struct}), do: struct
  defp get_data_type(_), do: :map

  defp add_result_metadata(metadata, result) when is_map(result) do
    Map.put(metadata, :fields_count, map_size(result))
  end

  defp add_result_metadata(metadata, result) when is_list(result) do
    Map.put(metadata, :list_size, length(result))
  end

  defp add_result_metadata(metadata, _result), do: metadata

  @doc """
  Attaches a default logger handler for NbSerializer telemetry events.

  This is useful for development and debugging.

  ## Options

    * `:level` - Log level to use (default: :debug)
    * `:prefix` - Prefix for log messages (default: "[NbSerializer]")
  """
  @spec attach_default_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :debug)
    prefix = Keyword.get(opts, :prefix, "[NbSerializer]")

    handlers = [
      {[:nb_serializer, :serialize, :start], &log_start/4},
      {[:nb_serializer, :serialize, :stop], &log_stop/4},
      {[:nb_serializer, :serialize, :exception], &log_exception/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      :telemetry.attach(
        "nb_serializer-logger-#{inspect(event)}",
        event,
        handler,
        %{level: level, prefix: prefix}
      )
    end)

    :ok
  end

  defp log_start(_event, _measurements, metadata, config) do
    require Logger

    Logger.log(
      config.level,
      "#{config.prefix} Starting serialization with #{inspect(metadata.serializer)}"
    )
  end

  defp log_stop(_event, measurements, metadata, config) do
    require Logger

    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    message =
      if metadata[:fields_count] do
        "#{config.prefix} Completed serialization with #{inspect(metadata.serializer)} " <>
          "in #{duration_ms}ms (#{metadata.fields_count} fields)"
      else
        "#{config.prefix} Completed serialization with #{inspect(metadata.serializer)} in #{duration_ms}ms"
      end

    Logger.log(config.level, message)
  end

  defp log_exception(_event, measurements, metadata, config) do
    require Logger

    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.log(
      :error,
      "#{config.prefix} Serialization failed with #{inspect(metadata.serializer)} " <>
        "after #{duration_ms}ms: #{inspect(metadata.error)}"
    )
  end
end
