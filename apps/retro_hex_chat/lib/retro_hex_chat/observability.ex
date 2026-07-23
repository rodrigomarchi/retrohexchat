defmodule RetroHexChat.Observability do
  @moduledoc """
  Shared domain observability helpers.

  `span/3` records an OpenTelemetry span and emits matching `:telemetry` events.
  The per-operation event keeps trace searches semantic, while the generic
  operation event gives Prometheus one stable metric surface for product flows.
  """

  require OpenTelemetry.Tracer, as: Tracer

  @generic_event [:retro_hex_chat, :observability, :operation]
  @app_prefix :retro_hex_chat

  @type event :: [atom()]
  @type metadata :: map()

  @spec span(event(), metadata(), (-> result)) :: result when result: term()
  def span(event, metadata \\ %{}, fun)
      when is_list(event) and is_map(metadata) and is_function(fun, 0) do
    span(event, metadata, fun, &result_metadata/1)
  end

  @spec span(event(), metadata(), (-> result), (result -> metadata())) :: result
        when result: term()
  def span(event, metadata, fun, classify_result)
      when is_list(event) and is_map(metadata) and is_function(fun, 0) and
             is_function(classify_result, 1) do
    metadata = base_metadata(event, metadata)
    start_measurements = %{system_time: System.system_time()}
    started_at = System.monotonic_time()

    emit_start(event, start_measurements, metadata)

    Tracer.with_span span_name(event), %{attributes: otel_attributes(metadata)} do
      try do
        result = fun.()
        duration = System.monotonic_time() - started_at
        metadata = Map.merge(metadata, normalize_metadata(classify_result.(result)))

        set_span_result(metadata)
        emit_stop(event, %{duration: duration}, metadata)

        result
      rescue
        exception ->
          duration = System.monotonic_time() - started_at
          metadata = Map.merge(metadata, exception_metadata(:error, exception))

          set_span_result(metadata)
          emit_exception(event, %{duration: duration}, metadata)

          reraise exception, __STACKTRACE__
      catch
        kind, reason ->
          duration = System.monotonic_time() - started_at
          metadata = Map.merge(metadata, caught_metadata(kind, reason))

          set_span_result(metadata)
          emit_exception(event, %{duration: duration}, metadata)

          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  @spec set_current_span_attributes(metadata()) :: :ok
  def set_current_span_attributes(attributes) when is_map(attributes) do
    attributes
    |> otel_attributes()
    |> Tracer.set_attributes()

    :ok
  end

  @spec record_event(event(), map(), metadata()) :: :ok
  def record_event(event, measurements \\ %{count: 1}, metadata \\ %{})
      when is_list(event) and is_map(measurements) and is_map(metadata) do
    :telemetry.execute(event, measurements, metadata)
  end

  defp emit_start(event, measurements, metadata) do
    :telemetry.execute(event ++ [:start], measurements, metadata)
    :telemetry.execute(@generic_event ++ [:start], measurements, metadata)
  end

  defp emit_stop(event, measurements, metadata) do
    :telemetry.execute(event ++ [:stop], measurements, metadata)
    :telemetry.execute(@generic_event ++ [:stop], measurements, metadata)
  end

  defp emit_exception(event, measurements, metadata) do
    :telemetry.execute(event ++ [:exception], measurements, metadata)
    :telemetry.execute(@generic_event ++ [:exception], measurements, metadata)
  end

  defp base_metadata(event, metadata) do
    context = event_context(event)
    operation = event_operation(event)

    metadata
    |> normalize_metadata()
    |> Map.put_new(:context, context)
    |> Map.put_new(:operation, operation)
  end

  defp event_context([@app_prefix, context | _]), do: normalize_value(context)
  defp event_context([context | _]), do: normalize_value(context)
  defp event_context(_event), do: "unknown"

  defp event_operation([@app_prefix, _context | operation]), do: operation_name(operation)
  defp event_operation([_context | operation]), do: operation_name(operation)
  defp event_operation(_event), do: "unknown"

  defp operation_name([]), do: "unknown"

  defp operation_name(parts) do
    parts
    |> Enum.map(&normalize_value/1)
    |> Enum.reject(&(&1 in ["", "unknown"]))
    |> Enum.join("_")
  end

  defp span_name(event) do
    event
    |> Enum.map(&normalize_value/1)
    |> Enum.join(".")
  end

  defp normalize_metadata(metadata) do
    Map.new(metadata, fn {key, value} -> {key, normalize_value(value)} end)
  end

  defp result_metadata({:error, reason}), do: %{result: "error", reason: normalize_reason(reason)}
  defp result_metadata({:ok, _value}), do: %{result: "ok"}
  defp result_metadata({:ok, _value, _extra}), do: %{result: "ok"}
  defp result_metadata({:reply, reply, _state}), do: result_metadata(reply)
  defp result_metadata({:noreply, _state}), do: %{result: "ok"}
  defp result_metadata({:halt, _socket}), do: %{result: "ok"}
  defp result_metadata({:cont, _socket}), do: %{result: "ok"}
  defp result_metadata({:stop, _reason, reply, _state}), do: result_metadata(reply)
  defp result_metadata(:ok), do: %{result: "ok"}
  defp result_metadata(_result), do: %{result: "ok"}

  defp exception_metadata(kind, exception) do
    %{
      result: "error",
      kind: normalize_value(kind),
      reason: exception_type(exception)
    }
  end

  defp caught_metadata(kind, reason) do
    %{
      result: "error",
      kind: normalize_value(kind),
      reason: normalize_reason(reason)
    }
  end

  defp set_span_result(%{result: "error"} = metadata) do
    Tracer.set_status(:error, Map.get(metadata, :reason, "error"))
    set_current_span_attributes(metadata)
  end

  defp set_span_result(metadata) do
    set_current_span_attributes(metadata)
  end

  defp otel_attributes(metadata) do
    metadata
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case otel_value(value) do
        nil -> acc
        value -> Map.put(acc, otel_key(key), value)
      end
    end)
  end

  defp otel_key(key) when is_atom(key), do: key |> Atom.to_string() |> String.replace("_", ".")
  defp otel_key(key) when is_binary(key), do: key
  defp otel_key(key), do: inspect(key)

  defp otel_value(value) when is_binary(value), do: value
  defp otel_value(value) when is_boolean(value), do: value
  defp otel_value(value) when is_integer(value), do: value
  defp otel_value(value) when is_float(value), do: value
  defp otel_value(_value), do: nil

  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_integer(value), do: value
  defp normalize_value(value) when is_float(value), do: value
  defp normalize_value(nil), do: "none"
  defp normalize_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp normalize_value(_value), do: "unknown"

  defp normalize_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp normalize_reason({:rate_limited, _}), do: "rate_limited"
  defp normalize_reason({:already_started, _}), do: "already_started"
  defp normalize_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp normalize_reason(reason) when is_binary(reason), do: "domain_error"
  defp normalize_reason(%module{}), do: module |> Module.split() |> List.last()
  defp normalize_reason(_reason), do: "unknown"

  defp exception_type(%module{}), do: module |> Module.split() |> Enum.join(".")
end
