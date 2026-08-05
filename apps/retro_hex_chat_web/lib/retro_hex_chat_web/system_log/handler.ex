defmodule RetroHexChatWeb.SystemLog.Handler do
  @moduledoc """
  An Erlang `:logger` handler that republishes log entries over PubSub.

  Installed only while a Live Log window is open, and removed when the last one
  closes. Logging is on the hot path of everything the server does, so an
  always-installed handler would make every request pay for a window nobody has
  open.

  The handler runs inside the process that logged, so it does as little as
  possible: format, truncate, broadcast, return. Anything heavier here is paid
  for by the request that happened to emit a line.

  Entries are truncated before broadcast rather than at render. A single
  runaway log line — an inspected struct the size of a database row — would
  otherwise cross the wire in full to every open window.
  """

  alias Phoenix.PubSub

  @handler_id __MODULE__
  @pubsub RetroHexChat.PubSub
  @topic "system:log"
  @max_length 2_000

  @type entry :: %{level: atom(), message: String.t(), at: DateTime.t()}

  @doc "The topic a window subscribes to for live entries."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc """
  Installs the handler if it is not already installed.

  Idempotent, because several windows may be open at once and each asks on
  mount without knowing about the others.
  """
  @spec install(Logger.level()) :: :ok
  def install(level \\ :info) do
    case :logger.add_handler(@handler_id, __MODULE__, %{level: level}) do
      :ok -> :ok
      {:error, {:already_exist, _id}} -> :ok
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Removes the handler.

  Safe to call when it is not installed — a window closing after the handler
  was already removed is the normal case, not an error.
  """
  @spec remove() :: :ok
  def remove do
    _ignored = :logger.remove_handler(@handler_id)
    :ok
  end

  @doc "Whether the handler is currently installed."
  @spec installed?() :: boolean()
  def installed?, do: @handler_id in :logger.get_handler_ids()

  @doc """
  The level the node filters at before any handler is consulted.

  A handler cannot see what the primary logger already dropped, so a window
  asking for `:debug` on a node configured at `:warning` will sit silent no
  matter how long it waits. Reporting this is what lets it say so instead of
  looking broken.
  """
  @spec primary_level() :: Logger.level()
  def primary_level do
    case :logger.get_primary_config() do
      %{level: level} -> normalize(level)
      _other -> :debug
    end
  end

  @doc "Whether entries at `level` can reach a handler on this node at all."
  @spec reachable?(Logger.level()) :: boolean()
  def reachable?(level) do
    Logger.compare_levels(level, primary_level()) != :lt
  end

  # OTP's primary config carries two levels that are thresholds rather than
  # severities: `:all` lets everything through, `:none` nothing. Mapping them
  # onto the extremes of the real scale is what lets the comparison in
  # `reachable?/1` be a plain level comparison.
  defp normalize(:all), do: :debug
  defp normalize(:none), do: :emergency
  defp normalize(level), do: level

  @doc false
  @spec log(:logger.log_event(), :logger.handler_config()) :: :ok
  def log(%{level: level, msg: message, meta: meta}, _config) do
    PubSub.broadcast(@pubsub, @topic, {:system_log, entry(level, message, meta)})
    :ok
  rescue
    # A handler that raises is removed by OTP, silently taking the feature with
    # it — and a message this code cannot format is not worth that.
    _error -> :ok
  end

  defp entry(level, message, meta) do
    %{level: level, message: format(message), at: timestamp(meta)}
  end

  defp format({:string, chardata}), do: truncate(chardata)

  defp format({:report, report}) when is_map(report) or is_list(report) do
    truncate(inspect(report, limit: 20, printable_limit: @max_length))
  end

  defp format({format, args}) do
    truncate(:io_lib.format(format, args))
  rescue
    _error -> "<unformattable log entry>"
  end

  defp format(other), do: truncate(inspect(other))

  defp truncate(chardata) do
    chardata
    |> IO.chardata_to_string()
    |> String.slice(0, @max_length)
  end

  # Logger timestamps are microseconds since the epoch; a window shows clock
  # time, so the conversion belongs here rather than in every reader.
  defp timestamp(%{time: microseconds}) when is_integer(microseconds) do
    DateTime.from_unix!(microseconds, :microsecond)
  end

  defp timestamp(_meta), do: DateTime.utc_now()
end
