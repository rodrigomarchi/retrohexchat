defmodule RetroHexChat.SystemInfo.Sources.Ports do
  @moduledoc """
  Every port on the node — the emulator's handles on the world outside it.

  A port is a file descriptor, a driver, or an external program the VM is
  talking to. They are a bounded resource with a hard ceiling, and one that
  leaks quietly: a driver that is opened per request and never closed shows up
  here long before it shows up as an outage.

  The controlling process is the column that assigns blame, so it is projected
  rather than left as an opaque reference.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.SystemInfo.Source

  alias RetroHexChat.SystemInfo.Query
  alias RetroHexChat.Table

  @impl true
  @spec columns() :: [Table.column()]
  def columns do
    [
      Table.column(:name, dgettext("admin", "Name"), sortable: true),
      Table.column(:port, dgettext("admin", "Port")),
      Table.column(:connected, dgettext("admin", "Controlled by")),
      Table.column(:os_pid, dgettext("admin", "OS PID")),
      Table.column(:input, dgettext("admin", "Input"), format: :bytes, sortable: true),
      Table.column(:output, dgettext("admin", "Output"), format: :bytes, sortable: true)
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :output

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    for port <- Port.list(), row = scan(port), Query.matches?(search, [row.name, row.port]) do
      row
    end
  end

  # `Port.info/1` reads every field in one call; the per-key arity would cost a
  # round trip per column, and a port closing mid-read reports nil either way.
  defp scan(port) do
    case Port.info(port) do
      nil ->
        nil

      info ->
        %{
          id: inspect(port),
          port: inspect(port),
          name: to_string(info[:name]),
          connected: inspect(info[:connected]),
          os_pid: info[:os_pid],
          input: info[:input],
          output: info[:output]
        }
    end
  end
end
