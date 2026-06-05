defmodule RetroHexChatWeb.ChatLive.ChannelCentralEvents do
  @moduledoc """
  Handle events for the Channel Central panel.

  Covers: open_channel_central, close_channel_central, channel_central_tab,
  cc_ban_select, cc_ban_ex_select, cc_invite_ex_select,
  cc_open_add_ban, cc_close_add_ban, cc_open_add_ban_ex, cc_close_add_ban_ex,
  cc_open_add_invite_ex, cc_close_add_invite_ex,
  cc_set_topic, cc_apply_modes,
  cc_add_ban, cc_remove_ban, cc_add_ban_exception, cc_remove_ban_exception,
  cc_add_invite_exception, cc_remove_invite_exception,
  cc_cs_register, cc_cs_drop, cc_cs_access_tab, cc_cs_access_add,
  cc_cs_access_remove.

  Attached as `attach_hook(:channel_central_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.ChanServ

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
    socket = assign(socket, channel_central_tab: tab)

    if tab == "registration" do
      {:halt, refresh_channel_central_registration(socket)}
    else
      {:halt, socket}
    end
  end

  # ── ChanServ Registration / Access ─────────────────────────

  def handle_event("cc_cs_register", _params, socket) do
    cond do
      !socket.assigns.session.identified ->
        {:halt, chanserv_error(socket, identified_required_message())}

      !socket.assigns.channel_central_operator ->
        {:halt, chanserv_error(socket, operator_required_register_message())}

      true ->
        channel = socket.assigns.channel_central_channel
        nickname = socket.assigns.session.nickname

        case ChanServ.register(channel, nickname) do
          {:ok, _message} ->
            _ = Server.mark_registered(channel)

            {:halt,
             socket
             |> assign(
               channel_central_cs_error: nil,
               channel_central_cs_confirm_drop: false,
               channel_central_access_tab: "sop",
               channel_central_access_selected: nil,
               channel_central_access_nick: ""
             )
             |> refresh_channel_central()}

          {:error, message} ->
            {:halt, chanserv_error(socket, message)}
        end
    end
  end

  def handle_event("cc_cs_drop_request", _params, socket) do
    {:halt, assign(socket, channel_central_cs_confirm_drop: true, channel_central_cs_error: nil)}
  end

  def handle_event("cc_cs_drop_cancel", _params, socket) do
    {:halt, assign(socket, channel_central_cs_confirm_drop: false)}
  end

  def handle_event("cc_cs_drop", _params, socket) do
    cond do
      !socket.assigns.session.identified ->
        {:halt, chanserv_error(socket, identified_required_message())}

      viewer_role(socket) != "founder" ->
        {:halt, chanserv_error(socket, dgettext("chat", "Only the founder can drop a channel."))}

      true ->
        channel = socket.assigns.channel_central_channel
        nickname = socket.assigns.session.nickname

        case ChanServ.drop(channel, nickname) do
          {:ok, _message} ->
            {:halt,
             socket
             |> assign(
               channel_central_cs_error: nil,
               channel_central_cs_confirm_drop: false,
               channel_central_access_tab: "sop",
               channel_central_access_selected: nil,
               channel_central_access_nick: ""
             )
             |> refresh_channel_central()}

          {:error, message} ->
            {:halt, chanserv_error(socket, message)}
        end
    end
  end

  def handle_event("cc_cs_access_tab", %{"level" => level}, socket) do
    {:halt,
     socket
     |> assign(
       channel_central_access_tab: normalize_access_level(level),
       channel_central_access_selected: nil,
       channel_central_access_nick: "",
       channel_central_cs_error: nil
     )
     |> refresh_channel_central_registration()}
  end

  def handle_event("cc_cs_access_change", params, socket) do
    {:halt,
     assign(socket,
       channel_central_access_tab:
         normalize_access_level(params["level"] || socket.assigns.channel_central_access_tab),
       channel_central_access_nick: String.trim(to_string(params["nickname"] || "")),
       channel_central_cs_error: nil
     )}
  end

  def handle_event("cc_cs_access_select", %{"nick" => nickname}, socket) do
    {:halt,
     assign(socket,
       channel_central_access_selected: nickname,
       channel_central_access_nick: nickname,
       channel_central_cs_error: nil
     )}
  end

  def handle_event("cc_cs_access_add", params, socket) do
    level = normalize_access_level(params["level"] || socket.assigns.channel_central_access_tab)
    nickname = String.trim(to_string(params["nickname"] || ""))

    cond do
      !socket.assigns.session.identified ->
        {:halt, chanserv_error(socket, identified_required_message())}

      nickname == "" ->
        {:halt, chanserv_error(socket, dgettext("chat", "Nickname is required."))}

      !can_manage_access?(socket, level) ->
        {:halt, chanserv_error(socket, manage_access_denied_message())}

      true ->
        channel = socket.assigns.channel_central_channel
        requester = socket.assigns.session.nickname

        case ChanServ.manage_access(channel, :add, level, nickname, requester) do
          {:ok, _message} ->
            {:halt,
             socket
             |> assign(
               channel_central_access_tab: level,
               channel_central_access_selected: nil,
               channel_central_access_nick: "",
               channel_central_cs_error: nil
             )
             |> refresh_channel_central_registration()}

          {:error, message} ->
            {:halt, chanserv_error(socket, message)}
        end
    end
  end

  def handle_event("cc_cs_access_remove", params, socket) do
    level = normalize_access_level(params["level"] || socket.assigns.channel_central_access_tab)

    target =
      socket.assigns.channel_central_access_selected ||
        String.trim(
          to_string(params["nickname"] || socket.assigns.channel_central_access_nick || "")
        )

    case validate_access_remove(socket, level, target) do
      :ok -> remove_chanserv_access(socket, level, target)
      {:error, message} -> {:halt, chanserv_error(socket, message)}
    end
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
        {:halt, error_event(socket, dgettext("chat", "Topic error: %{message}", message: msg))}
    end
  end

  def handle_event("cc_apply_modes", params, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname
    current = socket.assigns.channel_central_state.modes_detail

    socket = apply_mode_changes(socket, channel, nickname, current, params)
    {:halt, refresh_channel_central(socket)}
  end

  def handle_event("cc_save_welcome", %{"message" => message}, socket) do
    save_welcome(socket, String.trim(message))
  end

  def handle_event("cc_clear_welcome", _params, socket) do
    if socket.assigns.channel_central_operator do
      clear_welcome(socket)
    else
      {:halt, assign(socket, channel_central_notice: operator_required_message())}
    end
  end

  def handle_event("cc_apply_throttle", %{"seconds" => seconds}, socket) do
    if socket.assigns.channel_central_operator do
      case parse_throttle_seconds(seconds) do
        {:ok, 0} ->
          apply_throttle(socket, "-j", [], dgettext("chat", "Join throttle disabled."))

        {:ok, value} ->
          apply_throttle(
            socket,
            "+j",
            ["5:#{value}"],
            dgettext("chat", "Join throttle set to %{seconds} seconds.", seconds: value)
          )

        {:error, message} ->
          {:halt, assign(socket, channel_central_notice: message)}
      end
    else
      {:halt, assign(socket, channel_central_notice: operator_required_message())}
    end
  end

  def handle_event("cc_open_transfer", _params, socket) do
    if socket.assigns.channel_central_owner do
      {:halt, assign(socket, show_cc_transfer_dialog: true, channel_central_transfer_error: nil)}
    else
      {:halt, socket}
    end
  end

  def handle_event("cc_close_transfer", _params, socket) do
    {:halt, assign(socket, show_cc_transfer_dialog: false, channel_central_transfer_error: nil)}
  end

  def handle_event("cc_transfer_ownership", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname)

    cond do
      !socket.assigns.channel_central_owner ->
        {:halt, socket}

      nickname == "" ->
        {:halt,
         assign(socket, channel_central_transfer_error: dgettext("chat", "Nickname is required."))}

      true ->
        channel = socket.assigns.channel_central_channel
        current_owner = socket.assigns.session.nickname

        case Server.transfer_ownership(channel, current_owner, nickname) do
          :ok ->
            {:halt,
             socket
             |> assign(
               show_cc_transfer_dialog: false,
               channel_central_transfer_error: nil,
               channel_central_notice:
                 dgettext("chat", "Channel ownership transferred to %{target}.", target: nickname)
             )
             |> refresh_channel_central()}

          {:error, msg} ->
            {:halt, assign(socket, channel_central_transfer_error: msg)}
        end
    end
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
        {:halt, error_event(socket, dgettext("chat", "Ban error: %{message}", message: msg))}
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
          {:halt, error_event(socket, dgettext("chat", "Unban error: %{message}", message: msg))}
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
         error_event(socket, dgettext("chat", "Ban exception error: %{message}", message: msg))}
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
           error_event(
             socket,
             dgettext("chat", "Remove exception error: %{message}", message: msg)
           )}
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
         error_event(socket, dgettext("chat", "Invite exception error: %{message}", message: msg))}
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
           error_event(
             socket,
             dgettext("chat", "Remove exception error: %{message}", message: msg)
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
          operator =
            nickname in state.operators or nickname in Map.get(state, :owners, [])

          owner = nickname in Map.get(state, :owners, [])

          {:halt,
           assign(socket,
             show_channel_central: true,
             channel_central_tab: "general",
             channel_central_channel: channel,
             channel_central_state: state,
             channel_central_operator: operator,
             channel_central_owner: owner,
             channel_central_ban_selected: nil,
             channel_central_ban_ex_selected: nil,
             channel_central_invite_ex_selected: nil,
             channel_central_modes_form: %{},
             channel_central_notice: nil,
             channel_central_transfer_error: nil,
             channel_central_registration: ChanServ.registration_snapshot(channel, nickname),
             channel_central_access_tab: "sop",
             channel_central_access_selected: nil,
             channel_central_access_nick: "",
             channel_central_cs_error: nil,
             channel_central_cs_confirm_drop: false,
             show_cc_add_ban_dialog: false,
             show_cc_add_ban_ex_dialog: false,
             show_cc_add_invite_ex_dialog: false,
             show_cc_transfer_dialog: false
           )}
        else
          {:halt,
           error_event(
             socket,
             dgettext("chat", "You must be a member of %{channel} to open Channel Central",
               channel: channel
             )
           )}
        end

      {:error, _} ->
        {:halt,
         error_event(socket, dgettext("chat", "Channel %{channel} not found", channel: channel))}
    end
  end

  defp close_channel_central(socket) do
    assign(socket,
      show_channel_central: false,
      channel_central_tab: "general",
      channel_central_channel: nil,
      channel_central_state: nil,
      channel_central_operator: false,
      channel_central_owner: false,
      channel_central_ban_selected: nil,
      channel_central_ban_ex_selected: nil,
      channel_central_invite_ex_selected: nil,
      channel_central_modes_form: %{},
      channel_central_notice: nil,
      channel_central_transfer_error: nil,
      channel_central_registration: nil,
      channel_central_access_tab: "sop",
      channel_central_access_selected: nil,
      channel_central_access_nick: "",
      channel_central_cs_error: nil,
      channel_central_cs_confirm_drop: false,
      show_cc_add_ban_dialog: false,
      show_cc_add_ban_ex_dialog: false,
      show_cc_add_invite_ex_dialog: false,
      show_cc_transfer_dialog: false
    )
  end

  defp refresh_channel_central(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname

          operator =
            nickname in state.operators or nickname in Map.get(state, :owners, [])

          owner = nickname in Map.get(state, :owners, [])

          assign(socket,
            channel_central_state: state,
            channel_central_operator: operator,
            channel_central_owner: owner,
            channel_central_registration: ChanServ.registration_snapshot(channel, nickname)
          )

        {:error, _} ->
          close_channel_central(socket)
      end
    else
      socket
    end
  end

  defp refresh_channel_central_registration(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      assign(socket,
        channel_central_registration:
          ChanServ.registration_snapshot(channel, socket.assigns.session.nickname)
      )
    else
      assign(socket, channel_central_registration: nil)
    end
  end

  defp normalize_access_level(level) when level in ~w(sop aop vop), do: level
  defp normalize_access_level(_level), do: "sop"

  defp viewer_role(socket) do
    case socket.assigns.channel_central_registration do
      nil -> nil
      registration -> Map.get(registration, :viewer_role)
    end
  end

  defp can_manage_access?(socket, level) do
    case {socket.assigns.session.identified, viewer_role(socket), level} do
      {true, "founder", _level} -> true
      {true, "sop", level} when level in ~w(aop vop) -> true
      {true, "aop", "vop"} -> true
      _ -> false
    end
  end

  defp access_entry_in_level?(socket, level, nickname) do
    case socket.assigns.channel_central_registration do
      nil ->
        false

      registration ->
        registration
        |> Map.get(:access, %{})
        |> Map.get(level, [])
        |> Enum.any?(&(&1.nickname == nickname))
    end
  end

  defp validate_access_remove(socket, level, target) do
    cond do
      !socket.assigns.session.identified ->
        {:error, identified_required_message()}

      target in [nil, ""] ->
        {:error, dgettext("chat", "Select a nickname to remove.")}

      !can_manage_access?(socket, level) ->
        {:error, manage_access_denied_message()}

      !access_entry_in_level?(socket, level, target) ->
        {:error, dgettext("chat", "Select a nickname from this list.")}

      true ->
        :ok
    end
  end

  defp remove_chanserv_access(socket, level, target) do
    channel = socket.assigns.channel_central_channel
    requester = socket.assigns.session.nickname

    case ChanServ.manage_access(channel, :remove, level, target, requester) do
      {:ok, _message} ->
        {:halt,
         socket
         |> assign(
           channel_central_access_tab: level,
           channel_central_access_selected: nil,
           channel_central_access_nick: "",
           channel_central_cs_error: nil
         )
         |> refresh_channel_central_registration()}

      {:error, message} ->
        {:halt, chanserv_error(socket, message)}
    end
  end

  defp chanserv_error(socket, message) do
    assign(socket,
      channel_central_cs_error: message,
      channel_central_cs_confirm_drop: false
    )
  end

  defp apply_mode_changes(socket, channel, nickname, current, params) do
    mode_ops = build_mode_ops(current, params)

    Enum.reduce(mode_ops, socket, fn {mode_str, mode_params}, acc ->
      case Server.set_mode(channel, nickname, mode_str, mode_params) do
        :ok ->
          acc

        {:error, msg} ->
          error_event(acc, dgettext("chat", "Mode error: %{message}", message: msg))
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

  defp save_welcome(%{assigns: %{channel_central_operator: false}} = socket, _message) do
    {:halt, assign(socket, channel_central_notice: operator_required_message())}
  end

  defp save_welcome(socket, ""), do: clear_welcome(socket)

  defp save_welcome(socket, message) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_welcome(channel, message, nickname) do
      :ok ->
        {:halt,
         socket
         |> assign(channel_central_notice: dgettext("chat", "Welcome message saved."))
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt,
         socket
         |> assign(
           channel_central_notice: dgettext("chat", "Welcome error: %{message}", message: msg)
         )
         |> error_event(dgettext("chat", "Welcome error: %{message}", message: msg))}
    end
  end

  defp clear_welcome(socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.clear_welcome(channel, nickname) do
      :ok ->
        {:halt,
         socket
         |> assign(channel_central_notice: dgettext("chat", "Welcome message cleared."))
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt,
         socket
         |> assign(
           channel_central_notice: dgettext("chat", "Welcome error: %{message}", message: msg)
         )
         |> error_event(dgettext("chat", "Welcome error: %{message}", message: msg))}
    end
  end

  defp parse_throttle_seconds(seconds) do
    case Integer.parse(String.trim(to_string(seconds))) do
      {value, ""} when value >= 0 ->
        {:ok, value}

      _ ->
        {:error, dgettext("chat", "Join throttle must be a non-negative integer.")}
    end
  end

  defp apply_throttle(socket, mode_string, params, notice) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_mode(channel, nickname, mode_string, params) do
      :ok ->
        {:halt,
         socket
         |> assign(channel_central_notice: notice)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:halt,
         socket
         |> assign(
           channel_central_notice: dgettext("chat", "Throttle error: %{message}", message: msg)
         )
         |> error_event(dgettext("chat", "Throttle error: %{message}", message: msg))}
    end
  end

  defp operator_required_message do
    dgettext("chat", "You must be a channel operator to change this setting.")
  end

  defp operator_required_register_message do
    dgettext("chat", "Only channel operators can register this channel.")
  end

  defp identified_required_message do
    dgettext("chat", "You must be identified with NickServ to use ChanServ.")
  end

  defp manage_access_denied_message do
    dgettext("chat", "You do not have permission to manage this list.")
  end
end
