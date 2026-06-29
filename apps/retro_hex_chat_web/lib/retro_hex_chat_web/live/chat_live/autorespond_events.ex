defmodule RetroHexChatWeb.ChatLive.AutorespondEvents do
  @moduledoc """
  Handle events for the Auto-Respond Rules dialog.

  Covers: open/close_autorespond_dialog, autorespond_select, autorespond_toggle,
  autorespond_dialog_add, autorespond_dialog_edit, autorespond_dialog_save,
  autorespond_dialog_delete, autorespond_dialog_cancel_edit.

  Attached as `attach_hook(:autorespond_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_autorespond_rules: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoRespondRules
  alias RetroHexChatWeb.ChatLive.Components.AutoRespondDialog

  def handle_event("open_autorespond_dialog", _params, socket) do
    {:halt, assign(socket, show_autorespond_dialog: true)}
  end

  def handle_event("close_autorespond_dialog", _params, socket) do
    send_update(AutoRespondDialog, id: AutoRespondDialog.id(), action: :reset)
    {:halt, assign(socket, show_autorespond_dialog: false)}
  end

  def handle_event("autorespond_toggle", %{"position" => pos_str}, socket) do
    {pos, _} = Integer.parse(pos_str)
    session = socket.assigns.session

    case AutoRespondRules.toggle_entry(session.autorespond_rules, pos) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        {:halt,
         socket
         |> assign(session: new_session)
         |> maybe_persist_autorespond_rules(new_session)}

      {:error, _} ->
        {:halt, socket}
    end
  end

  def handle_event("autorespond_dialog_save", params, socket) do
    session = socket.assigns.session
    selected = params["selected"]
    trigger = String.to_existing_atom(params["trigger"])
    channel = params["channel"]
    channel = if channel == "", do: nil, else: channel
    command = params["command"] || ""

    result =
      if selected != nil do
        AutoRespondRules.update_entry(session.autorespond_rules, selected, %{
          trigger_event: trigger,
          channel_filter: channel,
          command: command
        })
      else
        AutoRespondRules.add_entry(session.autorespond_rules, trigger, channel, command)
      end

    case result do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)
        send_update(AutoRespondDialog, id: AutoRespondDialog.id(), action: {:saved})

        {:halt,
         socket
         |> assign(session: new_session)
         |> maybe_persist_autorespond_rules(new_session)}

      {:error, reason} ->
        send_update(AutoRespondDialog,
          id: AutoRespondDialog.id(),
          action: {:error, autorespond_error_msg(reason)}
        )

        {:halt, socket}
    end
  end

  def handle_event("autorespond_dialog_delete", params, socket) do
    selected = params["selected"]
    session = socket.assigns.session

    case AutoRespondRules.remove_entry(session.autorespond_rules, selected) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)
        send_update(AutoRespondDialog, id: AutoRespondDialog.id(), action: :deleted)

        {:halt,
         socket
         |> assign(session: new_session)
         |> maybe_persist_autorespond_rules(new_session)}

      {:error, _} ->
        {:halt, socket}
    end
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  defp autorespond_error_msg(:list_full), do: dgettext("chat", "Maximum 10 auto-respond rules")
  defp autorespond_error_msg(:invalid_trigger), do: dgettext("chat", "Invalid trigger event")

  defp autorespond_error_msg(:invalid_channel),
    do: dgettext("chat", "Channel filter must start with #")

  defp autorespond_error_msg(:invalid_command), do: dgettext("chat", "Command is required")

  defp autorespond_error_msg(:command_too_long),
    do: dgettext("chat", "Command too long (max 500 characters)")

  defp autorespond_error_msg(:command_chaining),
    do: dgettext("chat", "Command must not contain chaining (|, &&, ;)")

  defp autorespond_error_msg(:not_found), do: dgettext("chat", "Rule not found")
end
