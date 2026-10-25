defmodule RetroHexChat.Jobs.ResultMetadata do
  @moduledoc """
  Turns a worker's return value into the telemetry metadata attached to its span.

  The `result` key is what the Oban dashboards and Grafana panels group by, so a
  worker that invents its own spelling drops out of them. Anything that reaches
  metadata is a short label, never an inspected term: reasons become cardinality
  in the metrics backend.
  """

  @doc """
  Metadata for a failed run.
  """
  @spec error(term()) :: map()
  def error(reason), do: %{result: "error", reason: error_reason(reason)}

  @doc """
  Names an error term in one short, stable string.
  """
  @spec error_reason(term()) :: String.t()
  def error_reason(%Ecto.Changeset{}), do: "changeset_error"
  def error_reason({:http_status, status}) when is_integer(status), do: "http_#{status}"
  def error_reason({reason, _detail}) when is_atom(reason), do: Atom.to_string(reason)
  def error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  def error_reason(reason) when is_binary(reason), do: reason
  def error_reason(%module{}), do: module |> Module.split() |> List.last()
  def error_reason(_reason), do: "unknown"

  @doc """
  The metadata function for a maintenance run (`Observability.span/4`): on
  `{:ok, summary}`, the summary's `keys` (a nil count read as 0; a key the
  summary lacks raises) with
  `result: "ok"`; on `{:error, reason}`, `error/1`.
  """
  @spec summary([atom()]) :: ({:ok, map()} | {:error, term()} -> map())
  def summary(keys) do
    fn
      {:ok, summary} ->
        keys |> Map.new(&{&1, Map.fetch!(summary, &1) || 0}) |> Map.put(:result, "ok")

      {:error, reason} ->
        error(reason)
    end
  end

  @doc """
  Metadata for a worker whose whole job is to expire one record, covering every
  branch of Oban's return contract.
  """
  @spec expiry(term()) :: map()
  def expiry({:ok, :expired}), do: %{result: "expired", expired_count: 1}
  def expiry({:ok, result}), do: %{result: Atom.to_string(result)}
  def expiry({:snooze, seconds}), do: %{result: "snooze", seconds: seconds}
  def expiry({:cancel, reason}), do: %{result: "cancel", reason: reason}
  def expiry({:error, reason}), do: error(reason)
end
