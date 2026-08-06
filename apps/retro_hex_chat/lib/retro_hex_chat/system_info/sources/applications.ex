defmodule RetroHexChat.SystemInfo.Sources.Applications do
  @moduledoc """
  Every OTP application loaded into the node, and whether it is running.

  Loaded and started are different states, and the gap between them is the
  interesting one: an application present but not started is a dependency that
  failed to boot or was never meant to run here. Both are worth seeing, so the
  listing covers everything loaded and reports the distinction as a column.

  Membership of the started set is read once per listing rather than asked per
  application, which keeps the scan a single pass over two lists.
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
      Table.column(:description, dgettext("admin", "Description")),
      Table.column(:version, dgettext("admin", "Version"), sortable: true),
      Table.column(:started, dgettext("admin", "Started"), sortable: true)
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :name

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    started = MapSet.new(Application.started_applications(), fn {app, _desc, _vsn} -> app end)

    for {app, description, version} <- Application.loaded_applications(),
        row = row(app, description, version, started),
        Query.matches?(search, [row.name, row.description]) do
      row
    end
  end

  defp row(app, description, version, started) do
    %{
      id: to_string(app),
      name: to_string(app),
      description: to_string(description),
      version: to_string(version),
      started: MapSet.member?(started, app)
    }
  end
end
