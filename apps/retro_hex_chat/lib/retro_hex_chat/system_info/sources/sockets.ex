defmodule RetroHexChat.SystemInfo.Sources.Sockets do
  @moduledoc """
  Open network sockets, with their endpoints and byte counters.

  This is the connection census: how many peers the node is actually holding
  open, where they are, and how much has crossed each one. On a chat server it
  is the closest thing to a live user count that does not depend on the
  application agreeing to be counted.

  Sockets reach the runtime through two different mechanisms — the classic
  `inet` driver, which presents as a port, and the newer `socket` backend,
  which does not. Both are enumerated, because which one is in use is a
  configuration detail no reader of this window should have to know.

  Endpoint and counter reads go through the documented `:inet` API rather than
  the `:prim_inet` internals, so an OTP upgrade cannot quietly change what this
  window reports. That API reports no socket type, so the protocol column is
  derived from the driver behind the port — which names it exactly, and is the
  more useful fact anyway: TCP or UDP says more here than stream or datagram.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.SystemInfo.Source

  alias RetroHexChat.Admin.Table
  alias RetroHexChat.SystemInfo.Query

  @protocols %{"tcp_inet" => "TCP", "udp_inet" => "UDP", "sctp_inet" => "SCTP"}

  @impl true
  @spec columns() :: [Table.column()]
  def columns do
    [
      Table.column(:local, dgettext("admin", "Local address"), sortable: true),
      Table.column(:foreign, dgettext("admin", "Foreign address"), sortable: true),
      Table.column(:state, dgettext("admin", "State")),
      Table.column(:protocol, dgettext("admin", "Protocol"), sortable: true),
      Table.column(:owner, dgettext("admin", "Owner")),
      Table.column(:recv, dgettext("admin", "Received"), format: :bytes, sortable: true),
      Table.column(:sent, dgettext("admin", "Sent"), format: :bytes, sortable: true)
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :recv

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    for {socket, protocol} <- inet_ports() ++ backend_sockets(),
        row = scan(socket, protocol),
        Query.matches?(search, [row.local, row.foreign, row.owner]) do
      row
    end
  end

  # The driver name is the protocol, and is also what identifies a port as a
  # socket in the first place — so it is carried out of the filter rather than
  # looked up a second time.
  defp inet_ports do
    Enum.flat_map(Port.list(), fn port ->
      with {:name, name} <- Port.info(port, :name),
           {:ok, protocol} <- Map.fetch(@protocols, to_string(name)) do
        [{port, protocol}]
      else
        _other -> []
      end
    end)
  end

  # The socket backend keeps its own registry and is absent on nodes still
  # using the inet driver, so it is called only when the runtime offers it.
  defp backend_sockets do
    if function_exported?(:gen_tcp_socket, :which_sockets, 0) do
      Enum.map(apply(:gen_tcp_socket, :which_sockets, []), &{&1, "TCP"})
    else
      []
    end
  end

  defp scan(socket, protocol) do
    case :inet.info(socket) do
      info when is_map(info) -> row(socket, protocol, info)
      _other -> nil
    end
  rescue
    # A socket closing between enumeration and inspection raises rather than
    # returning an error tuple on some transports.
    _error -> nil
  end

  defp row(socket, protocol, info) do
    counters = Map.get(info, :counters, %{})

    %{
      id: inspect(socket),
      local: address(:inet.sockname(socket)),
      foreign: address(:inet.peername(socket)),
      state: states(Map.get(info, :states)),
      protocol: protocol,
      owner: owner(Map.get(info, :owner)),
      recv: Map.get(counters, :recv_oct, 0),
      sent: Map.get(counters, :send_oct, 0)
    }
  end

  defp address({:ok, {:local, path}}), do: to_string(path)

  defp address({:ok, {ip, port}}) do
    "#{:inet.ntoa(ip)}:#{port}"
  end

  defp address(_other), do: "*:*"

  defp states(states) when is_list(states), do: states |> Enum.map_join(", ", &to_string/1)
  defp states(state) when is_atom(state) and not is_nil(state), do: to_string(state)
  defp states(_other), do: ""

  defp owner(pid) when is_pid(pid), do: inspect(pid)
  defp owner(_other), do: ""
end
