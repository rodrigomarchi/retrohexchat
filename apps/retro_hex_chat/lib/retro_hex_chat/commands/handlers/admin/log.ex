defmodule RetroHexChat.Commands.Handlers.Admin.Log do
  @moduledoc "Admin subcommand for viewing the audit log."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Admin.Table
  alias RetroHexChat.Commands.Handler

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(opts, _context) do
    last = parse_int_opt(opts, "--last", 20)
    user = find_opt(opts, "--user")
    # The audit log window asks for the page after a row it already has. The
    # flag is how a window reaches page two without a second code path for
    # reading the log.
    before = parse_int_opt(opts, "--before", nil)

    query_opts = [last: last]
    query_opts = if user, do: [{:actor, strip_at(user)} | query_opts], else: query_opts
    query_opts = if before, do: [{:cursor, before} | query_opts], else: query_opts

    page = AuditLogs.list(query_opts)

    text =
      if page.items == [] do
        dgettext("admin", "*** No audit log entries found.")
      else
        header =
          dgettext("admin", "*** Audit Log (%{entries_count} entries) ***",
            entries_count: length(page.items)
          )

        lines = Enum.map(page.items, &format_log_entry/1)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text, table: log_table(page)}}
  end

  defp log_table(page) do
    Table.from_page(
      [
        Table.column(:inserted_at, dgettext("admin", "When")),
        Table.column(:actor, dgettext("admin", "Actor")),
        Table.column(:action, dgettext("admin", "Action")),
        Table.column(:target, dgettext("admin", "Target"))
      ],
      page,
      fn entry ->
        %{
          id: entry.id,
          inserted_at: entry.inserted_at,
          actor: entry.actor,
          action: entry.action,
          target_type: entry.target_type,
          target_id: entry.target_id,
          details: entry.details
        }
      end
    )
  end

  defp format_log_entry(e) do
    target =
      if e.target_type,
        do:
          dgettext("admin", " → %{target_type}:%{target_id}",
            target_type: e.target_type,
            target_id: e.target_id
          ),
        else: ""

    details = format_details(e.details)
    time = Calendar.strftime(e.inserted_at, "%Y-%m-%d %H:%M:%S")

    dgettext("admin", "  [%{time}] %{actor} %{action}%{target}%{details}",
      time: time,
      actor: e.actor,
      action: e.action,
      target: target,
      details: details
    )
  end

  defp format_details(nil), do: ""
  defp format_details(details) when details == %{}, do: ""

  defp format_details(details) do
    details
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> "#{key}: #{format_detail_value(value)}" end)
    |> case do
      [] -> ""
      parts -> " (" <> Enum.join(parts, ", ") <> ")"
    end
  end

  defp format_detail_value(value) when is_binary(value), do: value
  defp format_detail_value(value), do: inspect(value)

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
