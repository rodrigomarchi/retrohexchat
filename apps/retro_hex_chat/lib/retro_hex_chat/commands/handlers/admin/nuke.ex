defmodule RetroHexChat.Commands.Handlers.Admin.Nuke do
  @moduledoc "Admin subcommand for system-wide data wipe (factory reset)."

  alias RetroHexChat.Admin
  alias RetroHexChat.Commands.Handler

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["--confirm"], context) do
    case Admin.nuke_system(context.nickname) do
      {:ok, summary} ->
        {:ok, :system, %{content: format_result(summary)}}

      {:error, msg} ->
        {:error, msg}
    end
  end

  def execute([], context) do
    {:ok, counts} = Admin.nuke_preview(context.nickname)
    {:ok, :system, %{content: format_preview(counts)}}
  end

  def execute(_, _context) do
    {:error, "Usage: /admin nuke [--confirm]"}
  end

  defp format_preview(counts) do
    total = Enum.reduce(counts, 0, fn {_table, count}, acc -> acc + count end)

    lines =
      counts
      |> Enum.filter(fn {_table, count} -> count > 0 end)
      |> Enum.map(fn {table, count} -> "  #{table}: #{count}" end)

    header = "*** NUKE PREVIEW — #{total} records will be destroyed ***"
    warning = "*** Run /admin nuke --confirm to execute. THIS CANNOT BE UNDONE."

    preserved =
      "*** Preserved: admin_roles, audit_logs, server_bans, server_settings"

    if lines == [] do
      "*** NUKE PREVIEW — Nothing to delete. System is already clean."
    else
      Enum.join([header, preserved, "" | lines] ++ ["", warning], "\n")
    end
  end

  defp format_result(summary) do
    total = Enum.reduce(summary, 0, fn {_table, count}, acc -> acc + count end)

    lines =
      summary
      |> Enum.filter(fn {_table, count} -> count > 0 end)
      |> Enum.map(fn {table, count} -> "  #{table}: #{count} deleted" end)

    header = "*** SYSTEM NUKED — #{total} records destroyed ***"

    if lines == [] do
      "*** SYSTEM NUKED — No records to delete."
    else
      Enum.join([header | lines], "\n")
    end
  end
end
