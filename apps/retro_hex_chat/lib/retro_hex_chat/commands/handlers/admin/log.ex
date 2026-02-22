defmodule RetroHexChat.Commands.Handlers.Admin.Log do
  @moduledoc "Admin subcommand for viewing the audit log."

  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Commands.Handler

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(opts, _context) do
    last = parse_int_opt(opts, "--last", 20)
    user = find_opt(opts, "--user")

    query_opts = [last: last]
    query_opts = if user, do: [{:actor, strip_at(user)} | query_opts], else: query_opts

    entries = AuditLogs.list(query_opts)

    text =
      if entries == [] do
        "*** No audit log entries found."
      else
        header = "*** Audit Log (#{length(entries)} entries) ***"

        lines = Enum.map(entries, &format_log_entry/1)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  defp format_log_entry(e) do
    target = if e.target_type, do: " → #{e.target_type}:#{e.target_id}", else: ""
    time = Calendar.strftime(e.inserted_at, "%Y-%m-%d %H:%M:%S")
    "  [#{time}] #{e.actor} #{e.action}#{target}"
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick

  defp find_opt(opts, flag) do
    case Enum.find_index(opts, &(&1 == flag)) do
      nil -> nil
      idx -> Enum.at(opts, idx + 1)
    end
  end

  defp parse_int_opt(opts, flag, default) do
    case find_opt(opts, flag) do
      nil -> default
      str -> String.to_integer(str)
    end
  rescue
    _ -> default
  end
end
