defmodule RetroHexChatWeb.ChatLive.Components.ChatShell do
  @moduledoc """
  Chat-layer glue for the shell header.

  Derives the three view values the header needs — identity state, online-buddy
  count, and admin? — from the `Session` struct and delegates the markup to the
  design-system `chat_app_header/1`, so the main template no longer carries those
  computations or the shell imports.

  Pure function component (the header owns no draft/selection state). It holds the
  domain derivation only (no raw layout markup — that lives in `components/ui/`),
  keeping this lint-scanned glue free of raw Tailwind. Change-tracking memoizes it
  on the assigns it reads, so a plain chat message that does not touch
  `session`/`lag`/`mute` produces no header diff.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.ChatAppHeader

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.ChatContext

  attr :session, Session, required: true, doc: "Chat session struct (header is a function of it)"
  attr :channel_user_count, :integer, default: 0, doc: "Member count of the active channel/PM"
  attr :lag_ms, :any, default: nil, doc: "Lag in milliseconds, or nil when unknown/timed out"

  attr :lag_status, :atom,
    default: :normal,
    values: [:normal, :warning, :critical, :timeout]

  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  attr :p2p_session, :map,
    default: nil,
    doc: "The host's @p2p_session state-machine assign (nil when no session)"

  attr :group_call, :map,
    default: nil,
    doc: "The host's @group_call state assign (nil when no channel call is active)"

  @spec chat_shell_header(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_header(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        account_state: Session.identity_state(session),
        is_admin: ChatContext.admin?(session),
        arcade_available: session.identified == true,
        online_buddy_count: online_buddy_count(session.notify_list),
        channel: session.active_pm || session.active_channel,
        tab_type: if(session.active_pm, do: :pm, else: :channel),
        group_call_display: group_call_display(assigns.group_call),
        p2p: p2p_display(assigns.p2p_session),
        p2p_turn_available: (assigns.p2p_session || %{})[:turn_configured] == true
      )

    ~H"""
    <.chat_app_header
      nickname={@session.nickname}
      account_state={@account_state}
      away={@session.away}
      channel={@channel}
      user_count={@channel_user_count}
      tab_type={@tab_type}
      lag_ms={@lag_ms}
      lag_status={@lag_status}
      online_buddy_count={@online_buddy_count}
      muted={@muted}
      timezone={@timezone}
      is_admin={@is_admin}
      arcade_available={@arcade_available}
      group_call={@group_call_display}
      p2p={@p2p}
      p2p_turn_available={@p2p_turn_available}
    />
    """
  end

  @spec group_call_display(map() | nil) :: map() | nil
  defp group_call_display(nil), do: nil

  defp group_call_display(%{
         channel_name: channel_name,
         status: status,
         participants: participants
       }) do
    channel = channel_name || dgettext("group_call", "Group Call")
    count = length(participants || [])

    %{
      label: group_call_label(status, channel, count),
      title:
        dgettext("group_call", "Group call in %{channel} — click to focus", channel: channel),
      stop_title: dgettext("group_call", "Leave the group call")
    }
  end

  defp group_call_label(:connected, channel, count) when count > 0 do
    dgettext("group_call", "Call: %{channel} (%{count})", channel: channel, count: count)
  end

  defp group_call_label(:joining, channel, _count) do
    dgettext("group_call", "Call: joining %{channel}...", channel: channel)
  end

  defp group_call_label(:connecting, channel, _count) do
    dgettext("group_call", "Call: connecting %{channel}...", channel: channel)
  end

  defp group_call_label(:negotiating, channel, _count) do
    dgettext("group_call", "Call: negotiating %{channel}...", channel: channel)
  end

  defp group_call_label(:error, channel, _count) do
    dgettext("group_call", "Call: error in %{channel}", channel: channel)
  end

  defp group_call_label(_status, channel, count) when count > 0 do
    dgettext("group_call", "Call: %{channel} (%{count})", channel: channel, count: count)
  end

  defp group_call_label(_status, channel, _count) do
    dgettext("group_call", "Call: %{channel}", channel: channel)
  end

  # Derives the status-bar P2P zone strings from the host state machine —
  # the design-system component receives display text only.
  @spec p2p_display(map() | nil) :: map() | nil
  defp p2p_display(nil), do: nil

  defp p2p_display(%{state: state, peer_nick: peer_nick} = p2p) do
    peer = peer_nick || "?"

    case state do
      :invite_sent ->
        %{
          label: dgettext("chat", "P2P: waiting for %{peer}...", peer: peer),
          title: dgettext("chat", "P2P invite pending"),
          stop_title: dgettext("chat", "Cancel the P2P invite")
        }

      :connected ->
        %{
          label: connected_p2p_label(peer, p2p[:call_summary]),
          title: connected_p2p_title(peer, p2p),
          stop_title: dgettext("chat", "End the P2P session"),
          facets: p2p_facets(p2p),
          duration: get_in(p2p, [:call_summary, :duration]),
          quality: get_in(p2p, [:call_summary, :quality_label]),
          turn_only: p2p[:turn_only] == true and p2p[:turn_configured] == true
        }

      _joining_or_connecting ->
        %{
          label: dgettext("chat", "P2P: connecting to %{peer}...", peer: peer),
          title: dgettext("chat", "P2P session connecting"),
          stop_title: dgettext("chat", "End the P2P session")
        }
    end
  end

  defp connected_p2p_label(peer, %{duration: duration}) when is_binary(duration) do
    dgettext("chat", "P2P: %{peer} %{duration}", peer: peer, duration: duration)
  end

  defp connected_p2p_label(peer, _call_summary) do
    dgettext("chat", "P2P: %{peer}", peer: peer)
  end

  defp connected_p2p_title(peer, p2p) do
    facets = p2p_facets(p2p)

    suffix =
      case facets do
        [] -> dgettext("chat", "session ready")
        _ -> Enum.map_join(facets, ", ", &facet_title/1)
      end

    dgettext("chat", "P2P session with %{peer} — %{facets}. Click to focus",
      peer: peer,
      facets: suffix
    )
  end

  defp p2p_facets(p2p) do
    []
    |> maybe_add_facet(:call, p2p[:call_summary] != nil)
    |> maybe_add_facet(:file, p2p[:file_summary] != nil)
    |> maybe_add_facet(:game, get_in(p2p, [:game_summary, :active?]) == true)
  end

  defp maybe_add_facet(facets, facet, true), do: facets ++ [facet]
  defp maybe_add_facet(facets, _facet, _false), do: facets

  defp facet_title(:call), do: dgettext("chat", "call active")
  defp facet_title(:file), do: dgettext("chat", "file transfer active")
  defp facet_title(:game), do: dgettext("chat", "game active")

  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  defp online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  defp online_buddy_count(_notify_list), do: 0
end
