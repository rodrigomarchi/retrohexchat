defmodule RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog do
  @moduledoc """
  Stateful island for Channel Central — the per-channel admin mini-app
  (general/modes/bans/exceptions/registration-access tabs + 4 sub-form modals).

  Owns the ENTIRE dialog: every `channel_central_*` and `show_cc_*` assign that
  used to live in the parent `assign_defaults`, plus all of the event handling
  and the privileged `Server`/`ChanServ` calls. Nothing about this dialog lives
  in `ChatLive` anymore — the parent only routes the open trigger here via
  `send_update` and forwards live channel updates from PubSub.

  Every UI event targets this component (`phx-target={@myself}` threaded through
  the design-system `channel_central_panel/1`), so the 4 add/transfer sub-forms
  (`fixed inset-0` overlays) submit to the component that owns their DOM subtree —
  the component-id matches, so LiveView preserves the typed input across the
  background re-renders that channel PubSub triggers (the modal-in-modal
  anti-pattern, §0a-anti, fixed at the root instead of worked around).

  Effects that belong to the chat surface rather than the dialog (system error
  lines) bubble to the parent via `send(self(), {:cc_system_error, msg})`; the
  parent runs `error_event`. Inline errors (ChanServ, transfer, welcome notice)
  stay in the dialog's own assigns.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChannelCentralDialog

  alias Phoenix.LiveView.JS
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.ChanServ
  alias RetroHexChatWeb.App.ChatHelpers

  @id "channel-central-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @closed %{
    show_channel_central: false,
    channel_central_tab: "general",
    channel_central_channel: nil,
    channel_central_state: nil,
    channel_central_operator: false,
    channel_central_owner: false,
    channel_central_ban_selected: nil,
    channel_central_ban_ex_selected: nil,
    channel_central_invite_ex_selected: nil,
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
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@closed)
     |> assign(session: nil, timezone: "Etc/UTC")}
  end

  # ── Directives (driven by parent send_update) ────────────────────

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{open: channel}, socket), do: {:ok, open_channel_central(socket, channel)}

  def update(%{refresh: channel}, socket) do
    if socket.assigns.show_channel_central and socket.assigns.channel_central_channel == channel do
      {:ok, refresh_channel_central(socket)}
    else
      {:ok, socket}
    end
  end

  def update(%{close: true}, socket), do: {:ok, close_channel_central(socket)}

  # passthrough context (session/timezone)
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Open / Close / Tab ───────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("channel_central_tab", %{"tab" => tab}, socket) do
    socket = assign(socket, channel_central_tab: tab)

    if tab == "registration" do
      {:noreply, refresh_channel_central_registration(socket)}
    else
      {:noreply, socket}
    end
  end

  # ── ChanServ Registration / Access ───────────────────────────────

  def handle_event("cc_cs_register", _params, socket) do
    cond do
      !socket.assigns.session.identified ->
        {:noreply, chanserv_error(socket, identified_required_message())}

      !socket.assigns.channel_central_operator ->
        {:noreply, chanserv_error(socket, operator_required_register_message())}

      true ->
        channel = socket.assigns.channel_central_channel
        nickname = socket.assigns.session.nickname

        case ChanServ.register(channel, nickname) do
          {:ok, _message} ->
            _ = Server.mark_registered(channel)

            {:noreply,
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
            {:noreply, chanserv_error(socket, message)}
        end
    end
  end

  def handle_event("cc_cs_drop_request", _params, socket) do
    {:noreply,
     assign(socket, channel_central_cs_confirm_drop: true, channel_central_cs_error: nil)}
  end

  def handle_event("cc_cs_drop_cancel", _params, socket) do
    {:noreply, assign(socket, channel_central_cs_confirm_drop: false)}
  end

  def handle_event("cc_cs_drop", _params, socket) do
    cond do
      !socket.assigns.session.identified ->
        {:noreply, chanserv_error(socket, identified_required_message())}

      viewer_role(socket) != "founder" ->
        {:noreply,
         chanserv_error(socket, dgettext("chat", "Only the founder can drop a channel."))}

      true ->
        channel = socket.assigns.channel_central_channel
        nickname = socket.assigns.session.nickname

        case ChanServ.drop(channel, nickname) do
          {:ok, _message} ->
            {:noreply,
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
            {:noreply, chanserv_error(socket, message)}
        end
    end
  end

  def handle_event("cc_cs_access_tab", %{"level" => level}, socket) do
    {:noreply,
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
    {:noreply,
     assign(socket,
       channel_central_access_tab:
         normalize_access_level(params["level"] || socket.assigns.channel_central_access_tab),
       channel_central_access_nick: String.trim(to_string(params["nickname"] || "")),
       channel_central_cs_error: nil
     )}
  end

  def handle_event("cc_cs_access_select", %{"nick" => nickname}, socket) do
    {:noreply,
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
        {:noreply, chanserv_error(socket, identified_required_message())}

      nickname == "" ->
        {:noreply, chanserv_error(socket, dgettext("chat", "Nickname is required."))}

      !can_manage_access?(socket, level) ->
        {:noreply, chanserv_error(socket, manage_access_denied_message())}

      true ->
        channel = socket.assigns.channel_central_channel
        requester = socket.assigns.session.nickname

        case ChanServ.manage_access(channel, :add, level, nickname, requester) do
          {:ok, _message} ->
            {:noreply,
             socket
             |> assign(
               channel_central_access_tab: level,
               channel_central_access_selected: nil,
               channel_central_access_nick: "",
               channel_central_cs_error: nil
             )
             |> refresh_channel_central_registration()}

          {:error, message} ->
            {:noreply, chanserv_error(socket, message)}
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
      :ok -> {:noreply, remove_chanserv_access(socket, level, target)}
      {:error, message} -> {:noreply, chanserv_error(socket, message)}
    end
  end

  # ── Selection ────────────────────────────────────────────────────

  def handle_event("cc_ban_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_ban_selected: nick)}
  end

  def handle_event("cc_ban_ex_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_ban_ex_selected: nick)}
  end

  def handle_event("cc_invite_ex_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, channel_central_invite_ex_selected: nick)}
  end

  # ── Add/Close sub-form dialogs ───────────────────────────────────

  def handle_event("cc_open_add_ban", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_dialog: true)}
  end

  def handle_event("cc_close_add_ban", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_dialog: false)}
  end

  def handle_event("cc_open_add_ban_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_ex_dialog: true)}
  end

  def handle_event("cc_close_add_ban_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_ban_ex_dialog: false)}
  end

  def handle_event("cc_open_add_invite_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_invite_ex_dialog: true)}
  end

  def handle_event("cc_close_add_invite_ex", _params, socket) do
    {:noreply, assign(socket, show_cc_add_invite_ex_dialog: false)}
  end

  # ── Topic & Modes ────────────────────────────────────────────────

  def handle_event("cc_set_topic", %{"topic" => topic}, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_topic(channel, nickname, topic) do
      :ok ->
        {:noreply, refresh_channel_central(socket)}

      {:error, msg} ->
        {:noreply,
         bubble_error(socket, dgettext("chat", "Topic error: %{message}", message: msg))}
    end
  end

  def handle_event("cc_apply_modes", params, socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname
    current = socket.assigns.channel_central_state.modes_detail

    socket = apply_mode_changes(socket, channel, nickname, current, params)
    {:noreply, refresh_channel_central(socket)}
  end

  def handle_event("cc_save_welcome", %{"message" => message}, socket) do
    {:noreply, save_welcome(socket, String.trim(message))}
  end

  def handle_event("cc_clear_welcome", _params, socket) do
    if socket.assigns.channel_central_operator do
      {:noreply, clear_welcome(socket)}
    else
      {:noreply, assign(socket, channel_central_notice: operator_required_message())}
    end
  end

  def handle_event("cc_apply_throttle", %{"seconds" => seconds}, socket) do
    if socket.assigns.channel_central_operator do
      case parse_throttle_seconds(seconds) do
        {:ok, 0} ->
          {:noreply,
           apply_throttle(socket, "-j", [], dgettext("chat", "Join throttle disabled."))}

        {:ok, value} ->
          {:noreply,
           apply_throttle(
             socket,
             "+j",
             ["5:#{value}"],
             dgettext("chat", "Join throttle set to %{seconds} seconds.", seconds: value)
           )}

        {:error, message} ->
          {:noreply, assign(socket, channel_central_notice: message)}
      end
    else
      {:noreply, assign(socket, channel_central_notice: operator_required_message())}
    end
  end

  def handle_event("cc_open_transfer", _params, socket) do
    if socket.assigns.channel_central_owner do
      {:noreply,
       assign(socket, show_cc_transfer_dialog: true, channel_central_transfer_error: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cc_close_transfer", _params, socket) do
    {:noreply,
     assign(socket, show_cc_transfer_dialog: false, channel_central_transfer_error: nil)}
  end

  def handle_event("cc_transfer_ownership", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname)

    cond do
      !socket.assigns.channel_central_owner ->
        {:noreply, socket}

      nickname == "" ->
        {:noreply,
         assign(socket, channel_central_transfer_error: dgettext("chat", "Nickname is required."))}

      true ->
        channel = socket.assigns.channel_central_channel
        current_owner = socket.assigns.session.nickname

        case Server.transfer_ownership(channel, current_owner, nickname) do
          :ok ->
            {:noreply,
             socket
             |> assign(
               show_cc_transfer_dialog: false,
               channel_central_transfer_error: nil,
               channel_central_notice:
                 dgettext("chat", "Channel ownership transferred to %{target}.", target: nickname)
             )
             |> refresh_channel_central()}

          {:error, msg} ->
            {:noreply, assign(socket, channel_central_transfer_error: msg)}
        end
    end
  end

  # ── Bans ─────────────────────────────────────────────────────────

  def handle_event("cc_add_ban", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.ban(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_ban_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply, bubble_error(socket, dgettext("chat", "Ban error: %{message}", message: msg))}
    end
  end

  def handle_event("cc_remove_ban", _params, socket) do
    nick = socket.assigns.channel_central_ban_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.unban(channel, operator, nick) do
        :ok ->
          {:noreply,
           socket
           |> assign(channel_central_ban_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply,
           bubble_error(socket, dgettext("chat", "Unban error: %{message}", message: msg))}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Ban Exceptions ───────────────────────────────────────────────

  def handle_event("cc_add_ban_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_ban_exception(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_ban_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply,
         bubble_error(socket, dgettext("chat", "Ban exception error: %{message}", message: msg))}
    end
  end

  def handle_event("cc_remove_ban_exception", _params, socket) do
    nick = socket.assigns.channel_central_ban_ex_selected

    if nick do
      channel = socket.assigns.channel_central_channel
      operator = socket.assigns.session.nickname

      case Server.remove_ban_exception(channel, operator, nick) do
        :ok ->
          {:noreply,
           socket
           |> assign(channel_central_ban_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply,
           bubble_error(socket, dgettext("chat", "Ban exception error: %{message}", message: msg))}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Invite Exceptions ────────────────────────────────────────────

  def handle_event("cc_add_invite_exception", %{"nickname" => nick}, socket) do
    channel = socket.assigns.channel_central_channel
    operator = socket.assigns.session.nickname

    case Server.add_invite_exception(channel, operator, nick) do
      :ok ->
        {:noreply,
         socket
         |> assign(show_cc_add_invite_ex_dialog: false)
         |> refresh_channel_central()}

      {:error, msg} ->
        {:noreply,
         bubble_error(
           socket,
           dgettext("chat", "Invite exception error: %{message}", message: msg)
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
          {:noreply,
           socket
           |> assign(channel_central_invite_ex_selected: nil)
           |> refresh_channel_central()}

        {:error, msg} ->
          {:noreply,
           bubble_error(
             socket,
             dgettext("chat", "Invite exception error: %{message}", message: msg)
           )}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    state = assigns.channel_central_state

    assigns =
      assign(assigns,
        cc_topic: channel_central_topic(state),
        cc_topic_set_by: channel_central_topic_set_by(state),
        cc_topic_set_at: channel_central_topic_set_at(state, assigns.timezone),
        cc_created_at: channel_central_created_at(state, assigns.timezone),
        cc_member_count: channel_central_member_count(state),
        cc_welcome_message: channel_central_welcome_message(state),
        cc_throttle_seconds: channel_central_throttle_seconds(state),
        cc_modes: channel_central_modes(state),
        cc_bans: channel_central_bans(state),
        cc_ban_exceptions: channel_central_ban_exceptions(state),
        cc_invite_exceptions: channel_central_invite_exceptions(state)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.channel_central_panel
        id={@id}
        target={@myself}
        active_tab={@channel_central_tab}
        channel_name={@channel_central_channel}
        topic={@cc_topic}
        topic_set_by={@cc_topic_set_by}
        topic_set_at={@cc_topic_set_at}
        created_at={@cc_created_at}
        member_count={@cc_member_count}
        operator={@channel_central_operator}
        owner={@channel_central_owner}
        welcome_message={@cc_welcome_message}
        throttle_seconds={@cc_throttle_seconds}
        notice={@channel_central_notice}
        transfer_error={@channel_central_transfer_error}
        registration={@channel_central_registration}
        access_tab={@channel_central_access_tab}
        access_selected={@channel_central_access_selected}
        access_nick={@channel_central_access_nick}
        cs_error={@channel_central_cs_error}
        cs_confirm_drop={@channel_central_cs_confirm_drop}
        identified={@session.identified}
        modes={@cc_modes}
        bans={@cc_bans}
        ban_exceptions={@cc_ban_exceptions}
        invite_exceptions={@cc_invite_exceptions}
        ban_selected={@channel_central_ban_selected}
        ban_ex_selected={@channel_central_ban_ex_selected}
        invite_ex_selected={@channel_central_invite_ex_selected}
        show_add_ban_dialog={@show_cc_add_ban_dialog}
        show_add_ban_ex_dialog={@show_cc_add_ban_ex_dialog}
        show_add_invite_ex_dialog={@show_cc_add_invite_ex_dialog}
        show_transfer_dialog={@show_cc_transfer_dialog}
        on_tab={JS.push("channel_central_tab", target: @myself)}
        on_topic_save="cc_set_topic"
        on_welcome_save="cc_save_welcome"
        on_welcome_clear="cc_clear_welcome"
        on_throttle_apply="cc_apply_throttle"
        on_transfer_open="cc_open_transfer"
        on_transfer_close="cc_close_transfer"
        on_transfer_submit="cc_transfer_ownership"
        on_mode_apply="cc_apply_modes"
        on_ban_add="cc_open_add_ban"
        on_ban_remove="cc_remove_ban"
        on_ban_select="cc_ban_select"
        on_ban_ex_add="cc_open_add_ban_ex"
        on_ban_ex_remove="cc_remove_ban_exception"
        on_ban_ex_select="cc_ban_ex_select"
        on_invite_ex_add="cc_open_add_invite_ex"
        on_invite_ex_remove="cc_remove_invite_exception"
        on_invite_ex_select="cc_invite_ex_select"
        on_cs_register="cc_cs_register"
        on_cs_drop_request="cc_cs_drop_request"
        on_cs_drop="cc_cs_drop"
        on_cs_drop_cancel="cc_cs_drop_cancel"
        on_cs_access_tab="cc_cs_access_tab"
        on_cs_access_change="cc_cs_access_change"
        on_cs_access_add="cc_cs_access_add"
        on_cs_access_select="cc_cs_access_select"
        on_cs_access_remove="cc_cs_access_remove"
      />
    </div>
    """
  end

  # ── Open / Close / Refresh ───────────────────────────────────────

  defp open_channel_central(socket, channel) do
    nickname = socket.assigns.session.nickname

    case Server.get_state(channel) do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if nickname in member_nicks do
          operator = nickname in state.operators or nickname in Map.get(state, :owners, [])
          owner = nickname in Map.get(state, :owners, [])

          send(self(), {:cc_window_channel, channel})

          socket
          |> assign(@closed)
          |> assign(
            show_channel_central: true,
            channel_central_channel: channel,
            channel_central_state: state,
            channel_central_operator: operator,
            channel_central_owner: owner,
            channel_central_registration: ChanServ.registration_snapshot(channel, nickname)
          )
          |> push_event("window_command", %{action: "open", id: "channel-central"})
        else
          bubble_error(
            socket,
            dgettext("chat", "You must be a member of %{channel} to open Channel Central",
              channel: channel
            )
          )
        end

      {:error, _} ->
        bubble_error(socket, dgettext("chat", "Channel %{channel} not found", channel: channel))
    end
  end

  defp close_channel_central(socket) do
    socket
    |> assign(@closed)
    |> push_event("window_command", %{action: "close", id: "channel-central"})
  end

  defp refresh_channel_central(socket) do
    channel = socket.assigns.channel_central_channel

    if channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname
          operator = nickname in state.operators or nickname in Map.get(state, :owners, [])
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

  defp bubble_error(socket, message) do
    send(self(), {:cc_system_error, message})
    socket
  end

  # ── ChanServ helpers ─────────────────────────────────────────────

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
        socket
        |> assign(
          channel_central_access_tab: level,
          channel_central_access_selected: nil,
          channel_central_access_nick: "",
          channel_central_cs_error: nil
        )
        |> refresh_channel_central_registration()

      {:error, message} ->
        chanserv_error(socket, message)
    end
  end

  defp chanserv_error(socket, message) do
    assign(socket, channel_central_cs_error: message, channel_central_cs_confirm_drop: false)
  end

  # ── Mode ops ─────────────────────────────────────────────────────

  defp apply_mode_changes(socket, channel, nickname, current, params) do
    current
    |> build_mode_ops(params)
    |> Enum.reduce(socket, fn {mode_str, mode_params}, acc ->
      case Server.set_mode(channel, nickname, mode_str, mode_params) do
        :ok ->
          acc

        {:error, msg} ->
          bubble_error(acc, dgettext("chat", "Mode error: %{message}", message: msg))
      end
    end)
  end

  defp build_mode_ops(current, params) do
    []
    |> toggle_flag_op(current.moderated, params["moderated"] == "true", "m")
    |> toggle_flag_op(current.invite_only, params["invite_only"] == "true", "i")
    |> toggle_flag_op(current.topic_lock, params["topic_lock"] == "true", "t")
    |> build_key_op(current.key, params["has_key"] == "true", params["key_value"])
    |> build_limit_op(current.limit, params["has_limit"] == "true", params["limit_value"])
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

  # ── Welcome / Throttle ───────────────────────────────────────────

  defp save_welcome(%{assigns: %{channel_central_operator: false}} = socket, _message) do
    assign(socket, channel_central_notice: operator_required_message())
  end

  defp save_welcome(socket, ""), do: clear_welcome(socket)

  defp save_welcome(socket, message) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_welcome(channel, message, nickname) do
      :ok ->
        socket
        |> assign(channel_central_notice: dgettext("chat", "Welcome message saved."))
        |> refresh_channel_central()

      {:error, msg} ->
        socket
        |> assign(
          channel_central_notice: dgettext("chat", "Welcome error: %{message}", message: msg)
        )
        |> bubble_error(dgettext("chat", "Welcome error: %{message}", message: msg))
    end
  end

  defp clear_welcome(socket) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.clear_welcome(channel, nickname) do
      :ok ->
        socket
        |> assign(channel_central_notice: dgettext("chat", "Welcome message cleared."))
        |> refresh_channel_central()

      {:error, msg} ->
        socket
        |> assign(
          channel_central_notice: dgettext("chat", "Welcome error: %{message}", message: msg)
        )
        |> bubble_error(dgettext("chat", "Welcome error: %{message}", message: msg))
    end
  end

  defp parse_throttle_seconds(seconds) do
    case Integer.parse(String.trim(to_string(seconds))) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, dgettext("chat", "Join throttle must be a non-negative integer.")}
    end
  end

  defp apply_throttle(socket, mode_string, params, notice) do
    channel = socket.assigns.channel_central_channel
    nickname = socket.assigns.session.nickname

    case Server.set_mode(channel, nickname, mode_string, params) do
      :ok ->
        socket
        |> assign(channel_central_notice: notice)
        |> refresh_channel_central()

      {:error, msg} ->
        socket
        |> assign(
          channel_central_notice: dgettext("chat", "Throttle error: %{message}", message: msg)
        )
        |> bubble_error(dgettext("chat", "Throttle error: %{message}", message: msg))
    end
  end

  # ── Derived render data (from channel_central_state) ─────────────

  defp channel_central_bans(nil), do: []
  defp channel_central_bans(state), do: state |> Map.get(:bans, []) |> Enum.map(&to_list_entry/1)

  defp channel_central_ban_exceptions(nil), do: []

  defp channel_central_ban_exceptions(state),
    do: state |> Map.get(:ban_exceptions, []) |> Enum.map(&to_list_entry/1)

  defp channel_central_invite_exceptions(nil), do: []

  defp channel_central_invite_exceptions(state),
    do: state |> Map.get(:invite_exceptions, []) |> Enum.map(&to_list_entry/1)

  defp channel_central_modes(nil), do: %{}
  defp channel_central_modes(state), do: Map.get(state, :modes_detail, %{})

  defp channel_central_welcome_message(nil), do: ""

  defp channel_central_welcome_message(state) do
    case Map.get(state, :welcome_message) do
      %{message: message} when is_binary(message) -> message
      _ -> ""
    end
  end

  defp channel_central_throttle_seconds(nil), do: 0

  defp channel_central_throttle_seconds(state) do
    case state |> Map.get(:modes_detail, %{}) |> Map.get(:join_throttle) do
      {_count, seconds} when is_integer(seconds) -> seconds
      _ -> 0
    end
  end

  defp to_list_entry(%{mask: _} = map), do: map
  defp to_list_entry(nick) when is_binary(nick), do: %{mask: nick, set_by: "—", set_at: "—"}

  defp channel_central_topic(nil), do: ""
  defp channel_central_topic(state), do: Map.get(state, :topic, "")

  defp channel_central_topic_set_by(nil), do: nil
  defp channel_central_topic_set_by(state), do: Map.get(state, :topic_set_by)

  defp channel_central_topic_set_at(nil, _tz), do: nil

  defp channel_central_topic_set_at(state, timezone) do
    case Map.get(state, :topic_set_at) do
      nil -> nil
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_created_at(nil, _tz), do: nil

  defp channel_central_created_at(state, timezone) do
    case Map.get(state, :created_at) do
      nil -> nil
      dt -> ChatHelpers.format_datetime(dt, timezone)
    end
  end

  defp channel_central_member_count(nil), do: 0
  defp channel_central_member_count(state), do: Map.get(state, :member_count, 0)

  # ── Messages ─────────────────────────────────────────────────────

  defp operator_required_message,
    do: dgettext("chat", "You must be a channel operator to change this setting.")

  defp operator_required_register_message,
    do: dgettext("chat", "Only channel operators can register this channel.")

  defp identified_required_message,
    do: dgettext("chat", "You must be identified with NickServ to use ChanServ.")

  defp manage_access_denied_message,
    do: dgettext("chat", "You do not have permission to manage this list.")
end
