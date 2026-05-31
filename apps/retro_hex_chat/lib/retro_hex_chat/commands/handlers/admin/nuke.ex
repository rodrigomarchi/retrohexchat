defmodule RetroHexChat.Commands.Handlers.Admin.Nuke do
  @moduledoc "Admin subcommand for system-wide data wipe (factory reset)."
  use Gettext, backend: RetroHexChat.Gettext

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
    {:error, gettext("Usage: /admin nuke [--confirm]")}
  end

  defp format_preview(counts) do
    total = Enum.reduce(counts, 0, fn {_table, count}, acc -> acc + count end)

    lines =
      counts
      |> Enum.filter(fn {_table, count} -> count > 0 end)
      |> Enum.map(fn {table, count} -> "  #{table}: #{count}" end)

    header = gettext("*** NUKE PREVIEW — %{total} records will be destroyed ***", total: total)
    warning = gettext("*** Run /admin nuke --confirm to execute. THIS CANNOT BE UNDONE.")

    preserved =
      gettext("*** Preserved: admin_roles, audit_logs, server_bans, server_settings")

    if lines == [] do
      gettext("*** NUKE PREVIEW — Nothing to delete. System is already clean.")
    else
      Enum.join([header, preserved, "" | lines] ++ ["", warning], "\n")
    end
  end

  defp format_result(summary) do
    total = Enum.reduce(summary, 0, fn {_table, count}, acc -> acc + count end)

    lines =
      summary
      |> Enum.filter(fn {_table, count} -> count > 0 end)
      |> Enum.map(fn {table, count} ->
        gettext("  %{table}: %{count} deleted", table: table, count: count)
      end)

    header = gettext("*** SYSTEM NUKED — %{total} records destroyed ***", total: total)

    if lines == [] do
      gettext("*** SYSTEM NUKED — No records to delete.")
    else
      Enum.join([header | lines], "\n")
    end
  end
end
