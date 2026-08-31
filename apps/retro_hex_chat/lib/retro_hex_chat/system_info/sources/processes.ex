defmodule RetroHexChat.SystemInfo.Sources.Processes do
  @moduledoc """
  Every process on the node, projected for a monitor.

  The four numbers that matter are memory, reductions, mailbox depth and what
  the process is executing. A process is in trouble when its mailbox grows
  faster than it drains, and sorting on `message_queue_len` is how that is
  found — so the default order is by memory, and mailbox is one click away.

  Naming is deliberately two-tier. The scan reads `:registered_name` and
  `:initial_call`, which are fixed-size; the page then reads `$initial_call`
  from the dictionary, which is what distinguishes a hundred `:proc_lib`
  entries from each other. Doing the second on every process would make opening
  the window cost a walk of every dictionary on the node.

  That split is why the filter also matches the current function. Searching
  `gen_server` is the obvious thing to type, and before enrichment an OTP
  process names itself `proc_lib.init_p/5` — so matching on the scan-time name
  alone would silently answer "nothing found" for the most natural query.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.SystemInfo.Source

  alias RetroHexChat.SystemInfo.Query
  alias RetroHexChat.Table

  # Every key here is a fixed-size read. :messages and :dictionary are not, and
  # must never join this list.
  @scan_keys [
    :registered_name,
    :initial_call,
    :memory,
    :reductions,
    :message_queue_len,
    :current_function
  ]

  @impl true
  @spec columns() :: [Table.column()]
  def columns do
    [
      Table.column(:name, dgettext("admin", "Name or initial call"), sortable: true),
      Table.column(:pid, dgettext("admin", "PID")),
      Table.column(:memory, dgettext("admin", "Memory"), format: :bytes, sortable: true),
      Table.column(:reductions, dgettext("admin", "Reductions"),
        format: :number,
        sortable: true
      ),
      Table.column(:message_queue_len, dgettext("admin", "Mailbox"),
        format: :number,
        sortable: true
      ),
      Table.column(:current_function, dgettext("admin", "Current function"))
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :memory

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    for pid <- Process.list(),
        row = scan(pid),
        Query.matches?(search, [row.name, row.pid, row.current_function]) do
      row
    end
  end

  @impl true
  @spec enrich([map()]) :: [map()]
  def enrich(rows), do: Enum.flat_map(rows, &resolve_name/1)

  # A process that exits between listing and inspection reports nil, and is
  # dropped rather than rendered as a row of blanks.
  defp scan(pid) do
    case Process.info(pid, @scan_keys) do
      nil ->
        nil

      info ->
        %{
          id: inspect(pid),
          raw_pid: pid,
          pid: inspect(pid),
          name: initial_name(info),
          memory: info[:memory],
          reductions: info[:reductions],
          message_queue_len: info[:message_queue_len],
          current_function: format_mfa(info[:current_function])
        }
    end
  end

  defp initial_name(info) do
    case info[:registered_name] do
      [] -> format_mfa(info[:initial_call])
      nil -> format_mfa(info[:initial_call])
      name -> inspect(name)
    end
  end

  # `proc_lib` rewrites :initial_call to its own entry point and stashes the
  # real one in the dictionary, so an OTP process only names itself here.
  #
  # A process that exits between the scan and this read is dropped, the same
  # way the scan drops one that exits before it. Keeping it would publish the
  # one name this module exists to remove: `proc_lib.init_p/5` is what every
  # OTP process is called before enrichment, so a row that missed enrichment
  # is not a row with a worse name — it is a row saying something false about
  # a process that is no longer there.
  defp resolve_name(%{raw_pid: pid} = row) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dictionary} ->
        case Keyword.get(dictionary, :"$initial_call") do
          nil -> [row]
          mfa -> [%{row | name: format_mfa(mfa)}]
        end

      nil ->
        []
    end
  end

  defp format_mfa({module, function, arity}) do
    Exception.format_mfa(module, function, arity)
  end

  defp format_mfa(_other), do: ""
end
