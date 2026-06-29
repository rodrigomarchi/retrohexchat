defmodule RetroHexChatWeb.ChatLive.AliasEvents do
  @moduledoc """
  Handle events for the Alias dialog (Scripting > Aliases).

  The dialog's UI/draft state (select/add/edit/cancel) lives in the
  `Components.AliasDialog` LiveComponent. This module handles the events that need
  the session: open/close, and the mutating save/delete (which carry the selected
  entry via `JS.push` and reflect results back to the component via
  `send_update/2`). The parent keeps `show_alias_dialog` for the Escape map.

  Attached as an `attach_hook(:alias_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_aliases: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AliasList
  alias RetroHexChatWeb.ChatLive.Components.AliasDialog

  # ── Handled events ─────────────────────────────────────────

  def handle_event("open_alias_dialog", _params, socket) do
    {:halt, assign(socket, show_alias_dialog: true)}
  end

  def handle_event("close_alias_dialog", _params, socket) do
    send_update(AliasDialog, id: AliasDialog.id(), action: :reset)
    {:halt, assign(socket, show_alias_dialog: false)}
  end

  def handle_event("alias_dialog_save", params, socket) do
    session = socket.assigns.session
    selected = params["selected"]
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
        warning = alias_warning(name, expansion)
        send_update(AliasDialog, id: AliasDialog.id(), action: {:saved, name, warning})

        {:halt,
         socket
         |> assign(session: new_session)
         |> maybe_persist_aliases(new_session)}

      {:error, reason} ->
        send_update(AliasDialog,
          id: AliasDialog.id(),
          action: {:error, alias_error_msg(reason, name)}
        )

        {:halt, socket}
    end
  end

  def handle_event("alias_dialog_delete", params, socket) do
    selected = params["selected"]

    if selected do
      session = socket.assigns.session

      case AliasList.remove_entry(session.aliases, selected) do
        {:ok, updated_list} ->
          new_session = Session.set_aliases(session, updated_list)
          send_update(AliasDialog, id: AliasDialog.id(), action: :deleted)

          {:halt,
           socket
           |> assign(session: new_session)
           |> maybe_persist_aliases(new_session)}

        {:error, _} ->
          {:halt, socket}
      end
    else
      {:halt, socket}
    end
  end

  # ── Catch-all: pass unhandled events to next hook ──────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp alias_error_msg(:duplicate_name, name),
    do: dgettext("chat", "Alias /%{name} already exists", name: name)

  defp alias_error_msg(:invalid_name, _),
    do: dgettext("chat", "Invalid name. Use letters, numbers, hyphens, underscores.")

  defp alias_error_msg(:invalid_expansion, _), do: dgettext("chat", "Expansion is required")

  defp alias_error_msg(:expansion_too_long, _),
    do: dgettext("chat", "Expansion too long (max 500 characters)")

  defp alias_error_msg(:command_chaining, _),
    do: dgettext("chat", "Expansion must not contain chaining (|, &&, ;, newlines)")

  defp alias_error_msg(:list_full, _), do: dgettext("chat", "Alias list is full (max 50)")
  defp alias_error_msg(:not_found, _), do: dgettext("chat", "Alias not found")

  defp alias_warning(name, expansion) do
    [
      if(AliasList.shadows_builtin?(name),
        do: dgettext("chat", "shadows built-in /%{name}", name: name)
      ),
      if(AliasList.recursive_expansion?(name, expansion),
        do: dgettext("chat", "expands to itself and will hit the recursion limit")
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      warnings -> dgettext("chat", "Warning: %{warnings}", warnings: Enum.join(warnings, "; "))
    end
  end
end
