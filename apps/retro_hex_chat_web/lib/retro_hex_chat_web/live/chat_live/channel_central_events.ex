defmodule RetroHexChatWeb.ChatLive.ChannelCentralEvents do
  @moduledoc """
  Handle events for the Channel Central panel.

  Covers: open_channel_central, close_channel_central, channel_central_tab,
  cc_ban_select, cc_ban_ex_select, cc_invite_ex_select,
  cc_open_add_ban, cc_close_add_ban, cc_open_add_ban_ex, cc_close_add_ban_ex,
  cc_open_add_invite_ex, cc_close_add_invite_ex,
  cc_set_topic, cc_apply_modes,
  cc_add_ban, cc_remove_ban, cc_add_ban_exception, cc_remove_ban_exception,
  cc_add_invite_exception, cc_remove_invite_exception.

  Attached as `attach_hook(:channel_central_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_message: 1]

  alias RetroHexChat.Channels.Server

  # ── Open / Close / Tab ─────────────────────────────────────

  def handle_event("open_channel_central", params, socket) do
    channel = params["cc_channel"] || socket.assigns.session.active_channel

    if channel do
      open_channel_central(socket, channel)
    else
      {:halt, socket}
    end
  end

  def handle_event("close_channel_central", _params, socket) do
    {:halt, close_channel_central(socket)}
  end

  def handle_event("channel_central_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, channel_central_tab: tab)}
  end

  # ── Selection ──────────────────────────────────────────────

  def handle_event("cc_ban_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, channel_central_ban_selected: nick)}
  end

  def handle_event("cc_ban_ex_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, channel_central_ban_ex_selected: nick)}
  end

  def handle_event("cc_invite_ex_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, channel_central_invite_ex_selected: nick)}
  end

  # ── Add/Close dialogs ─────────────────────────────────────

  def handle_event("cc_open_add_ban", _params, socket) do
    {:halt, assign(socket, show_cc_add_ban_dialog: true)}
  end

  def handle_event("cc_close_add_ban", _params, socket) do
    {:halt, assign(socket, show_cc_add_ban_dialog: false)}
  end

  def handle_event("cc_open_add_ban_ex", _params, socket) do
    {:halt, assign(socket, show_cc_add_ban_ex_dialog: true)}
  end

  def handle_event("cc_close_add_ban_ex", _params, socket) do
    {:halt, assign(socket, show_cc_add_ban_ex_dialog: false)}
  end

  def handle_event("cc_open_add_invite_ex", _params, socket) do
    {:halt, assign(socket, show_cc_add_invite_ex_dialog: true)}
  end

  def handle_event("cc_close_add_invite_ex", _params, socket) do
    {:halt, assign(socket, show_cc_add_invite_ex_dialog: false)}
  end

  # ── Topic & Modes ──────────────────────────────────────────

  def handle_event("cc_set_topic", %{"topic" => topic}, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_topic(channel, nickname, topic) do
      :ok ->
        {:halt, refresh_channel_central(socket)}

      {:error, msg} ->
        {:halt, stream_insert(socket, :chat_messages, error_message("Topic error: #{msg}"))}
    end
  end

  def handle_event("cc_apply_modes", params, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname
    current = socket.assigns.channel_central_state.modes_detail

    socket = apply_mode_changes(socket, channel, nickname, current, params)
    {:halt, refresh_channel_central(socket)}
  end

  # ── Bans ───────────────────────────────────────────────────

  def handle_event("cc_add_ban", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.ban(channel, operator, nick) do
      :ok ->
        {:halt,
         socket
         |> assign(show_cc_add_ban_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt, stream_insert(socket, :chat_messages, error_message("Ban error: #{msg}"))}
    end
  end

  def handle_event("cc_remove_ban", _params, socket) do
    nick = socket.assigns.channel_central_ban_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.unban(channel, operator, nick) do
        :ok ->
          {:halt,
           socket
           |> assign(channel_central_ban_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:halt, stream_insert(socket, :chat_messages, error_message("Unban error: #{msg}"))}
      end
    else
      {:halt, socket}
    end
  end

  # ── Ban Exceptions ─────────────────────────────────────────

  def handle_event("cc_add_ban_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_ban_exception(channel, operator, nick) do
      :ok ->
        {:halt,
         socket
         |> assign(show_cc_add_ban_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt,
         stream_insert(socket, :chat_messages, error_message("Ban exception error: #{msg}"))}
    end
  end

  def handle_event("cc_remove_ban_exception", _params, socket) do
    nick = socket.assigns.channel_central_ban_ex_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.remove_ban_exception(channel, operator, nick) do
        :ok ->
          {:halt,
           socket
           |> assign(channel_central_ban_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:halt,
           stream_insert(socket, :chat_messages, error_message("Remove exception error: #{msg}"))}
      end
    else
      {:halt, socket}
    end
  end

  # ── Invite Exceptions ──────────────────────────────────────

  def handle_event("cc_add_invite_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_invite_exception(channel, operator, nick) do
      :ok ->
        {:halt,
         socket
         |> assign(show_cc_add_invite_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt,
         stream_insert(
           socket,
           :chat_messages,
           error_message("Invite exception error: #{msg}")
         )}
    end
  end

  def handle_event("cc_remove_invite_exception", _params, socket) do
    nick = socket.assigns.channel_central_invite_ex_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.remove_invite_exception(channel, operator, nick) do
        :ok ->
          {:halt,
           socket
           |> assign(channel_central_invite_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:halt,
           stream_insert(
             socket,
             :chat_messages,
             error_message("Remove exception error: #{msg}")
           )}
      end
    else
      {:halt, socket}
    end
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp open_channel_central(socket, channel) do
    nickname = socket.assigns.session.nickname

    case Server.get_state(channel) do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if nickname in member_nicks do
          operator = nickname in state.operators

          {:halt,
           assign(socket,
             show_channel_central: true,
             channel_central_tab: "general",
             channel_central_channel: channel,
             channel_central_state: state,
             channel_central_operator: operator,
             channel_central_ban_selected: nil,
             channel_central_ban_ex_selected: nil,
             channel_central_invite_ex_selected: nil,
             channel_central_modes_form: %{},
             show_cc_add_ban_dialog: false,
             show_cc_add_ban_ex_dialog: false,
             show_cc_add_invite_ex_dialog: false
           )}
        else
          {:halt,
           stream_insert(
             socket,
             :chat_messages,
             error_message("You must be a member of #{channel} to open Channel Central")
           )}
        end

      {:error, _} ->
        {:halt,
         stream_insert(socket, :chat_messages, error_message("Channel #{channel} not found"))}
    end
  end

  defp close_channel_central(socket) do
    assign(socket,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_channel: nil,
      channel_central_state: nil,
      channel_central_operator: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false
    )
  end

  defp refresh_channel_central(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname
          operator = nickname in state.operators
          assign(socket, channel_central_state: state, channel_central_operator: operator)

        {:error, _} ->
          close_channel_central(socket)
      end
    else
      socket
    end
  end

  defp apply_mode_changes(socket, channel, nickname, current, params) do
    mode_ops = build_mode_ops(current, params)

    Enum.reduce(mode_ops, socket, fn {mode_str, mode_params}, acc ->
      case Server.set_mode(channel, nickname, mode_str, mode_params) do
        :ok -> acc
        {:error, msg} -> stream_insert(acc, :chat_messages, error_message("Mode error: #{msg}"))
      end
    end)
  end

  defp build_mode_ops(current, params) do
    ops = []

    ops = toggle_flag_op(ops, current.moderated, params["moderated"] == "true", "m")
    ops = toggle_flag_op(ops, current.invite_only, params["invite_only"] == "true", "i")
    ops = toggle_flag_op(ops, current.topic_lock, params["topic_lock"] == "true", "t")
    ops = build_key_op(ops, current.key, params["has_key"] == "true", params["key_value"])
    ops = build_limit_op(ops, current.limit, params["has_limit"] == "true", params["limit_value"])

    ops
  end

  defp toggle_flag_op(ops, was_on, is_on, flag) do
    cond do
      !was_on and is_on -> [{"+#{flag}", []} | ops]
      was_on and !is_on -> [{"-#{flag}", []} | ops]
      true -> ops
    end
  end

  defp build_key_op(ops, nil, true, key_value) when is_binary(key_value) and key_value != "",
    do: [{"+k", [key_value]} | ops]

  defp build_key_op(ops, old_key, false, _) when old_key != nil,
    do: [{"-k", []} | ops]

  defp build_key_op(ops, old_key, true, key_value)
       when old_key != nil and is_binary(key_value) and key_value != "" and key_value != old_key,
       do: [{"-k", []}, {"+k", [key_value]} | ops]

  defp build_key_op(ops, _, _, _), do: ops

  defp build_limit_op(ops, nil, true, val) when is_binary(val) and val != "",
    do: [{"+l", [val]} | ops]

  defp build_limit_op(ops, old, false, _) when old != nil,
    do: [{"-l", []} | ops]

  defp build_limit_op(ops, old, true, val) when old != nil and is_binary(val) and val != "" do
    if val != to_string(old), do: [{"-l", []}, {"+l", [val]} | ops], else: ops
  end

  defp build_limit_op(ops, _, _, _), do: ops
end
