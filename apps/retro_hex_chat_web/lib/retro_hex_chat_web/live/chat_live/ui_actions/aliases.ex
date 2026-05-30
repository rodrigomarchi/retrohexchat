defmodule RetroHexChatWeb.ChatLive.UiActions.Aliases do
  @moduledoc """
  Alias UI actions: add, remove, list display, open dialog.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, error_event: 2, maybe_persist_aliases: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AliasList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_alias_dialog, _payload) do
    assign(socket, show_alias_dialog: true)
  end

  def handle_ui_action(socket, :alias_added, %{name: name, expansion: expansion}) do
    session = socket.assigns.session

    case AliasList.add_entry(session.aliases, name, expansion) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        warning = alias_warning_suffix(name, expansion)

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> system_event("* Alias /#{name} created#{warning}")

      {:error, :duplicate_name} ->
        error_event(socket, "Alias /#{name} already exists")

      {:error, :invalid_name} ->
        error_event(
          socket,
          "Invalid alias name. Use only letters, numbers, hyphens, underscores."
        )

      {:error, :invalid_expansion} ->
        error_event(socket, "Expansion is required")

      {:error, :expansion_too_long} ->
        error_event(socket, "Expansion too long (max 500 characters)")

      {:error, :command_chaining} ->
        error_event(
          socket,
          "Expansion must not contain command chaining (|, &&, ;, newlines)"
        )

      {:error, :list_full} ->
        error_event(socket, "Alias list is full (max 50)")
    end
  end

  def handle_ui_action(socket, :alias_removed, %{name: name}) do
    session = socket.assigns.session

    case AliasList.remove_entry(session.aliases, name) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> system_event("* Alias /#{name} removed")

      {:error, :not_found} ->
        error_event(socket, "Alias /#{name} not found")
    end
  end

  def handle_ui_action(socket, :alias_list_display, _payload) do
    session = socket.assigns.session
    entries = AliasList.entries(session.aliases)

    if entries == [] do
      system_event(socket, "Your alias list is empty")
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        system_event(acc, "  /#{entry.name} → #{entry.expansion}")
      end)
    end
  end

  defp alias_warning_suffix(name, expansion) do
    [
      if(AliasList.shadows_builtin?(name), do: "shadows built-in /#{name}"),
      if(AliasList.recursive_expansion?(name, expansion),
        do: "expands to itself and will hit the recursion limit"
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> ""
      warnings -> " (warning: " <> Enum.join(warnings, "; ") <> ")"
    end
  end
end
