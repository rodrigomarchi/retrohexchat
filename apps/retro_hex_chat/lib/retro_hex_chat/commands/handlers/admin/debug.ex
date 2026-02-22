defmodule RetroHexChat.Commands.Handlers.Admin.Debug do
  @moduledoc "Admin subcommands for debug information."

  alias RetroHexChat.Commands.Handler

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["connections"], _context) do
    count =
      case Registry.select(RetroHexChat.Channels.ChannelRegistry, [{{:_, :_, :_}, [], [true]}]) do
        list -> length(list)
      end

    text = "*** Debug: #{count} active channel processes"
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
        "*** No active channel processes."
      else
        header = "*** Active Channel Processes (#{length(channels)}) ***"

        lines =
          Enum.map(channels, fn {name, pid} ->
            "  #{name} (#{inspect(pid)})"
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["memory"], _context) do
    mem = :erlang.memory()

    format = fn bytes ->
      mb = bytes / 1_048_576
      :erlang.float_to_binary(mb, decimals: 1) <> " MB"
    end

    text =
      "*** BEAM Memory ***\n" <>
        "  Total: #{format.(mem[:total])}\n" <>
        "  Processes: #{format.(mem[:processes])}\n" <>
        "  ETS: #{format.(mem[:ets])}\n" <>
        "  Atoms: #{format.(mem[:atom])}\n" <>
        "  Binary: #{format.(mem[:binary])}\n" <>
        "  Code: #{format.(mem[:code])}"

    {:ok, :system, %{content: text}}
  end

  def execute([], _context) do
    {:error, "Usage: /admin debug <connections|processes|memory>"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown debug subcommand: #{subcmd}. Try: connections, processes, memory"}
  end
end
