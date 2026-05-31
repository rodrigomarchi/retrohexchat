defmodule RetroHexChat.Commands.Handlers.Admin.Turn do
  @moduledoc "Admin subcommands for TURN server status."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Turn.Config

  @not_configured gettext_noop("*** TURN server is not configured (listener_count = 0)")

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["stats"], _context) do
    if P2P.turn_configured?() do
      format_stats()
    else
      {:ok, :system, %{content: not_configured()}}
    end
  end

  def execute(["allocations"], _context) do
    if P2P.turn_configured?() do
      format_allocations()
    else
      {:ok, :system, %{content: not_configured()}}
    end
  end

  def execute([], _context) do
    {:error, gettext("Usage: /admin turn <stats|allocations>")}
  end

  def execute([subcmd | _], _context) do
    {:error,
     gettext("Unknown turn subcommand: %{subcmd}. Try: stats, allocations", subcmd: subcmd)}
  end

  defp not_configured, do: Gettext.gettext(RetroHexChat.Gettext, @not_configured)

  defp format_stats do
    config = Config.from_application_env()
    {port_min, port_max} = config.relay_port_range
    total_ports = port_max - port_min + 1

    alloc_states = query_alloc_metadata()
    active = length(alloc_states)

    used_ports =
      alloc_states |> Enum.map(& &1.alloc_port) |> MapSet.new() |> MapSet.size()

    relay_ip = :inet.ntoa(config.relay_ip) |> to_string()

    text =
      gettext("*** TURN Server Stats ***\n") <>
        gettext("  Status: running\n") <>
        gettext("  Relay IP: %{relay_ip}\n", relay_ip: relay_ip) <>
        gettext("  Listen port: %{listen_port}\n", listen_port: config.listen_port) <>
        gettext("  Listeners: %{listener_count}\n", listener_count: config.listener_count) <>
        gettext("  Active allocations: %{active}\n", active: active) <>
        gettext("  Relay ports: %{used_ports}/%{total_ports} in use\n",
          used_ports: used_ports,
          total_ports: total_ports
        ) <>
        gettext("  Port range: %{port_min}-%{port_max}", port_min: port_min, port_max: port_max)

    {:ok, :system, %{content: text}}
  end

  defp format_allocations do
    entries = query_alloc_entries()

    text =
      if entries == [] do
        gettext("*** No active TURN allocations.")
      else
        header =
          gettext("*** Active TURN Allocations (%{entries_count}) ***",
            entries_count: length(entries)
          )

        lines = Enum.map(entries, &format_entry/1)
        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  defp format_entry({five_tuple, alloc_state}) do
    {client_ip, client_port, _server_ip, _server_port, _proto} = five_tuple
    client = "#{:inet.ntoa(client_ip)}:#{client_port}"

    gettext("  %{client} -> relay port %{alloc_port}",
      client: client,
      alloc_port: alloc_state.alloc_port
    )
  end

  defp query_alloc_metadata do
    Registry.select(
      RetroHexChat.P2P.Turn.AllocationRegistry,
      [{{:_, :_, :"$3"}, [], [:"$3"]}]
    )
  end

  defp query_alloc_entries do
    Registry.select(
      RetroHexChat.P2P.Turn.AllocationRegistry,
      [{{:"$1", :_, :"$3"}, [], [{{:"$1", :"$3"}}]}]
    )
  end
end
