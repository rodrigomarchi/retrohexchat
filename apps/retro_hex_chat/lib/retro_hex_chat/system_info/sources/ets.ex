defmodule RetroHexChat.SystemInfo.Sources.Ets do
  @moduledoc """
  Every ETS table on the node, with what it costs.

  ETS is the usual home of an unbounded cache: a table nobody prunes grows
  until it is the node's memory profile. `:ets.info/1` reports size in words,
  which is meaningless next to the byte figures on every other screen, so it is
  converted here — the word size is a property of the emulator, not something a
  reader should have to multiply by.

  Default order is by memory, because the question this window answers is which
  table is the expensive one.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.SystemInfo.Source

  alias RetroHexChat.SystemInfo.Query
  alias RetroHexChat.Table

  @impl true
  @spec columns() :: [Table.column()]
  def columns do
    [
      Table.column(:name, dgettext("admin", "Name"), sortable: true),
      Table.column(:size, dgettext("admin", "Objects"), format: :number, sortable: true),
      Table.column(:memory, dgettext("admin", "Memory"), format: :bytes, sortable: true),
      Table.column(:owner, dgettext("admin", "Owner")),
      Table.column(:type, dgettext("admin", "Type")),
      Table.column(:protection, dgettext("admin", "Protection"))
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :memory

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    word_size = :erlang.system_info(:wordsize)

    for ref <- :ets.all(),
        row = scan(ref, word_size),
        Query.matches?(search, [row.name, row.owner]) do
      row
    end
  end

  # A table dropped between `all/0` and `info/1` reports :undefined.
  defp scan(ref, word_size) do
    case :ets.info(ref) do
      :undefined ->
        nil

      info ->
        %{
          id: inspect(ref),
          name: table_name(info[:name]),
          size: info[:size],
          memory: info[:memory] * word_size,
          owner: owner_name(info[:owner]),
          type: to_string(info[:type]),
          protection: to_string(info[:protection])
        }
    end
  end

  # Most tables in an Elixir node are named after the module that owns them,
  # and a module atom prints with the `Elixir.` prefix the compiler adds. That
  # prefix is an implementation detail of atom encoding — nobody calls the
  # table `Elixir.RetroHexChat.Repo` — so it is dropped here rather than left
  # to lengthen every row in the widest column.
  @spec table_name(term()) :: String.t()
  defp table_name(name) when is_atom(name) do
    case Atom.to_string(name) do
      "Elixir." <> module -> module
      plain -> plain
    end
  end

  defp table_name(name), do: to_string(name)

  # A registered owner names itself; an anonymous one is only findable by pid.
  defp owner_name(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) and not is_nil(name) -> inspect(name)
      _other -> inspect(pid)
    end
  end
end
