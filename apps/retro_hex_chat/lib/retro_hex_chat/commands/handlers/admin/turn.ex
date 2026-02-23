defmodule RetroHexChat.Commands.Handlers.Admin.Turn do
  @moduledoc "Admin subcommands for TURN server status."

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Turn.Config

  @not_configured "*** TURN server is not configured (listener_count = 0)"

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["stats"], _context) do
    if P2P.turn_configured?() do
      format_stats()
    else
      {:ok, :system, %{content: @not_configured}}
    end
  end

  def execute(["allocations"], _context) do
    if P2P.turn_configured?() do
      format_allocations()
    else
      {:ok, :system, %{content: @not_configured}}
    end
  end

  def execute([], _context) do
    {:error, "Usage: /admin turn <stats|allocations>"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown turn subcommand: #{subcmd}. Try: stats, allocations"}
  end

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
      "*** TURN Server Stats ***\n" <>
        "  Status: running\n" <>
        "  Relay IP: #{relay_ip}\n" <>
        "  Listen port: #{config.listen_port}\n" <>
        "  Listeners: #{config.listener_count}\n" <>
        "  Active allocations: #{active}\n" <>
        "  Relay ports: #{used_ports}/#{total_ports} in use\n" <>
        "  Port range: #{port_min}-#{port_max}"

    {:ok, :system, %{content: text}}
  end

  defp format_allocations do
    entries = query_alloc_entries()

    text =
      if entries == [] do
        "*** No active TURN allocations."
      else
        header = "*** Active TURN Allocations (#{length(entries)}) ***"
        lines = Enum.map(entries, &format_entry/1)
        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  defp format_entry({five_tuple, alloc_state}) do
    {client_ip, client_port, _server_ip, _server_port, _proto} = five_tuple
    client = "#{:inet.ntoa(client_ip)}:#{client_port}"
    "  #{client} -> relay port #{alloc_state.alloc_port}"
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
