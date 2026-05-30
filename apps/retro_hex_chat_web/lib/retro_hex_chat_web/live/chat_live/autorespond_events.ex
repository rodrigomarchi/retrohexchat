defmodule RetroHexChatWeb.ChatLive.AutorespondEvents do
  @moduledoc """
  Handle events for the Auto-Respond Rules dialog.

  Covers: open/close_autorespond_dialog, autorespond_select, autorespond_toggle,
  autorespond_dialog_add, autorespond_dialog_edit, autorespond_dialog_save,
  autorespond_dialog_delete, autorespond_dialog_cancel_edit.

  Attached as `attach_hook(:autorespond_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [maybe_persist_autorespond_rules: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoRespondRules

  def handle_event("open_autorespond_dialog", _params, socket) do
    {:halt, assign(socket, show_autorespond_dialog: true)}
  end

  def handle_event("close_autorespond_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_autorespond_dialog: false,
       autorespond_dialog_selected: nil,
       autorespond_dialog_editing: false,
       autorespond_dialog_draft_trigger: "on_join",
       autorespond_dialog_draft_channel: "",
       autorespond_dialog_draft_command: "",
       autorespond_dialog_error: nil
     )}
  end

  def handle_event("autorespond_select", %{"position" => pos_str}, socket) do
    {pos, _} = Integer.parse(pos_str)
    {:halt, assign(socket, autorespond_dialog_selected: pos)}
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

  def handle_event("autorespond_dialog_add", _params, socket) do
    {:halt,
     assign(socket,
       autorespond_dialog_editing: true,
       autorespond_dialog_selected: nil,
       autorespond_dialog_draft_trigger: "on_join",
       autorespond_dialog_draft_channel: "",
       autorespond_dialog_draft_command: "",
       autorespond_dialog_error: nil
     )}
  end

  def handle_event("autorespond_dialog_edit", _params, socket) do
    selected = socket.assigns.autorespond_dialog_selected
    session = socket.assigns.session

    case Enum.find(
           AutoRespondRules.entries(session.autorespond_rules),
           &(&1.position == selected)
         ) do
      nil ->
        {:halt, socket}

      entry ->
        {:halt,
         assign(socket,
           autorespond_dialog_editing: true,
           autorespond_dialog_draft_trigger: Atom.to_string(entry.trigger_event),
           autorespond_dialog_draft_channel: entry.channel_filter || "",
           autorespond_dialog_draft_command: entry.command,
           autorespond_dialog_error: nil
         )}
    end
  end

  def handle_event("autorespond_dialog_save", params, socket) do
    session = socket.assigns.session
    selected = socket.assigns.autorespond_dialog_selected
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

        {:halt,
         socket
         |> assign(
           session: new_session,
           autorespond_dialog_editing: false,
           autorespond_dialog_selected: nil,
           autorespond_dialog_error: nil
         )
         |> maybe_persist_autorespond_rules(new_session)}

      {:error, reason} ->
        msg = autorespond_error_msg(reason)
        {:halt, assign(socket, autorespond_dialog_error: msg)}
    end
  end

  def handle_event("autorespond_dialog_delete", _params, socket) do
    selected = socket.assigns.autorespond_dialog_selected
    session = socket.assigns.session

    case AutoRespondRules.remove_entry(session.autorespond_rules, selected) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        {:halt,
         socket
         |> assign(
           session: new_session,
           autorespond_dialog_selected: nil,
           autorespond_dialog_editing: false
         )
         |> maybe_persist_autorespond_rules(new_session)}

      {:error, _} ->
        {:halt, socket}
    end
  end

  def handle_event("autorespond_dialog_cancel_edit", _params, socket) do
    {:halt,
     assign(socket,
       autorespond_dialog_editing: false,
       autorespond_dialog_error: nil
     )}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  defp autorespond_error_msg(:list_full), do: "Maximum 10 auto-respond rules"
  defp autorespond_error_msg(:invalid_trigger), do: "Invalid trigger event"
  defp autorespond_error_msg(:invalid_channel), do: "Channel filter must start with #"
  defp autorespond_error_msg(:invalid_command), do: "Command is required"
  defp autorespond_error_msg(:command_too_long), do: "Command too long (max 500 characters)"

  defp autorespond_error_msg(:command_chaining),
    do: "Command must not contain chaining (|, &&, ;)"

  defp autorespond_error_msg(:not_found), do: "Rule not found"
end
