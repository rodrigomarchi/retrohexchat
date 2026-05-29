defmodule RetroHexChatWeb.ChatLive.AliasEvents do
  @moduledoc """
  Handle events for the Alias dialog (Scripting > Aliases).

  Covers: open_alias_dialog, close_alias_dialog, alias_select,
  alias_dialog_add, alias_dialog_edit, alias_dialog_save,
  alias_dialog_delete, alias_dialog_cancel_edit.

  Attached as an `attach_hook(:alias_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_aliases: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AliasList

  # ── Handled events ─────────────────────────────────────────

  def handle_event("open_alias_dialog", _params, socket) do
    {:halt, assign(socket, show_alias_dialog: true)}
  end

  def handle_event("close_alias_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_alias_dialog: false,
       alias_dialog_selected: nil,
       alias_dialog_editing: false,
       alias_dialog_draft_name: "",
       alias_dialog_draft_expansion: "",
       alias_dialog_warning: nil,
       alias_dialog_error: nil
     )}
  end

  def handle_event("alias_select", %{"name" => name}, socket) do
    {:halt, assign(socket, alias_dialog_selected: name, alias_dialog_editing: false)}
  end

  def handle_event("alias_dialog_add", _params, socket) do
    {:halt,
     assign(socket,
       alias_dialog_editing: true,
       alias_dialog_selected: nil,
       alias_dialog_draft_name: "",
       alias_dialog_draft_expansion: "",
       alias_dialog_warning: nil,
       alias_dialog_error: nil
     )}
  end

  def handle_event("alias_dialog_edit", _params, socket) do
    selected = socket.assigns.alias_dialog_selected

    if selected do
      session = socket.assigns.session
      entry = AliasList.find_entry(session.aliases, selected)

      if entry do
        {:halt,
         assign(socket,
           alias_dialog_editing: true,
           alias_dialog_draft_name: entry.name,
           alias_dialog_draft_expansion: entry.expansion,
           alias_dialog_error: nil
         )}
      else
        {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("alias_dialog_save", params, socket) do
    session = socket.assigns.session
    selected = socket.assigns.alias_dialog_selected
    name = selected || Map.get(params, "name", "")
    expansion = Map.get(params, "expansion", "")

    result =
      if selected do
        AliasList.update_entry(session.aliases, selected, expansion)
      else
        AliasList.add_entry(session.aliases, name, expansion)
      end

    case result do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)
        warning = if AliasList.shadows_builtin?(name), do: "Warning: shadows built-in /#{name}"

        {:halt,
         socket
         |> assign(
           session: new_session,
           alias_dialog_editing: false,
           alias_dialog_selected: name,
           alias_dialog_draft_name: "",
           alias_dialog_draft_expansion: "",
           alias_dialog_warning: warning,
           alias_dialog_error: nil
         )
         |> maybe_persist_aliases(new_session)}

      {:error, reason} ->
        {:halt, assign(socket, alias_dialog_error: alias_error_msg(reason, name))}
    end
  end

  def handle_event("alias_dialog_delete", _params, socket) do
    selected = socket.assigns.alias_dialog_selected

    if selected do
      session = socket.assigns.session

      case AliasList.remove_entry(session.aliases, selected) do
        {:ok, updated_list} ->
          new_session = Session.set_aliases(session, updated_list)

          {:halt,
           socket
           |> assign(
             session: new_session,
             alias_dialog_selected: nil,
             alias_dialog_editing: false,
             alias_dialog_warning: nil,
             alias_dialog_error: nil
           )
           |> maybe_persist_aliases(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("alias_dialog_cancel_edit", _params, socket) do
    {:halt,
     assign(socket,
       alias_dialog_editing: false,
       alias_dialog_draft_name: "",
       alias_dialog_draft_expansion: "",
       alias_dialog_error: nil
     )}
  end

  # ── Catch-all: pass unhandled events to next hook ──────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp alias_error_msg(:duplicate_name, name), do: "Alias /#{name} already exists"

  defp alias_error_msg(:invalid_name, _),
    do: "Invalid name. Use letters, numbers, hyphens, underscores."

  defp alias_error_msg(:expansion_too_long, _), do: "Expansion too long (max 500 characters)"

  defp alias_error_msg(:command_chaining, _),
    do: "Expansion must not contain chaining (|, &&, ;, newlines)"

  defp alias_error_msg(:list_full, _), do: "Alias list is full (max 50)"
  defp alias_error_msg(:not_found, _), do: "Alias not found"
end
