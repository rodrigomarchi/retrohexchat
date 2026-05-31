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

    text = dgettext("admin", "*** Debug: %{count} active channel processes", count: count)
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
        dgettext("admin", "*** No active channel processes.")
      else
        header =
          dgettext("admin", "*** Active Channel Processes (%{channels_count}) ***",
            channels_count: length(channels)
          )

        lines =
          Enum.map(channels, fn {name, pid} ->
            dgettext("admin", "  %{name} (%{pid})", name: name, pid: inspect(pid))
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["memory"], _context) do
    mem = :erlang.memory()

    format = fn bytes ->
      mb = bytes / 1_048_576
      :erlang.float_to_binary(mb, decimals: 1) <> dgettext("admin", " MB")
    end

    text =
      dgettext("admin", "*** BEAM Memory ***\n") <>
        dgettext("admin", "  Total: %{total}\n", total: format.(mem[:total])) <>
        dgettext("admin", "  Processes: %{processes}\n", processes: format.(mem[:processes])) <>
        dgettext("admin", "  ETS: %{ets}\n", ets: format.(mem[:ets])) <>
        dgettext("admin", "  Atoms: %{atom}\n", atom: format.(mem[:atom])) <>
        dgettext("admin", "  Binary: %{binary}\n", binary: format.(mem[:binary])) <>
        dgettext("admin", "  Code: %{code}", code: format.(mem[:code]))

    {:ok, :system, %{content: text}}
  end

  def execute([], _context) do
    {:error, dgettext("admin", "Usage: /admin debug <connections|processes|memory>")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown debug subcommand: #{subcmd}. Try: connections, processes, memory"}
  end
end
