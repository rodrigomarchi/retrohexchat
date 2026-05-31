defmodule RetroHexChat.Commands.Handlers.Admin.Debug do
  @moduledoc "Admin subcommands for debug information."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["connections"], _context) do
    count =
      case Registry.select(RetroHexChat.Channels.ChannelRegistry, [{{:_, :_, :_}, [], [true]}]) do
        list -> length(list)
      end

    text = gettext("*** Debug: %{count} active channel processes", count: count)
    {:ok, :system, %{content: text}}
  end

  def execute(["processes"], _context) do
    channels =
      case Registry.select(RetroHexChat.Channels.ChannelRegistry, [
             {{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}
           ]) do
        list -> list
      end

    text =
      if channels == [] do
        gettext("*** No active channel processes.")
      else
        header =
          gettext("*** Active Channel Processes (%{channels_count}) ***",
            channels_count: length(channels)
          )

        lines =
          Enum.map(channels, fn {name, pid} ->
            gettext("  %{name} (%{pid})", name: name, pid: inspect(pid))
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["memory"], _context) do
    mem = :erlang.memory()

    format = fn bytes ->
      mb = bytes / 1_048_576
      :erlang.float_to_binary(mb, decimals: 1) <> gettext(" MB")
    end

    text =
      gettext("*** BEAM Memory ***\n") <>
        gettext("  Total: %{total}\n", total: format.(mem[:total])) <>
        gettext("  Processes: %{processes}\n", processes: format.(mem[:processes])) <>
        gettext("  ETS: %{ets}\n", ets: format.(mem[:ets])) <>
        gettext("  Atoms: %{atom}\n", atom: format.(mem[:atom])) <>
        gettext("  Binary: %{binary}\n", binary: format.(mem[:binary])) <>
        gettext("  Code: %{code}", code: format.(mem[:code]))

    {:ok, :system, %{content: text}}
  end

  def execute([], _context) do
    {:error, gettext("Usage: /admin debug <connections|processes|memory>")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown debug subcommand: #{subcmd}. Try: connections, processes, memory"}
  end
end
