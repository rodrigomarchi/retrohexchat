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

  @spec chat_shell_header(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_header(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        account_state: Session.identity_state(session),
        is_admin: ChatContext.admin?(session),
        online_buddy_count: online_buddy_count(session.notify_list),
        channel: session.active_pm || session.active_channel,
        tab_type: if(session.active_pm, do: :pm, else: :channel),
        p2p: p2p_display(assigns.p2p_session)
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
      p2p={@p2p}
    />
    """
  end

  # Derives the status-bar P2P zone strings from the host state machine —
  # the design-system component receives display text only.
  @spec p2p_display(map() | nil) :: map() | nil
  defp p2p_display(nil), do: nil

  defp p2p_display(%{state: state, peer_nick: peer_nick}) do
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
          label: dgettext("chat", "P2P: %{peer}", peer: peer),
          title: dgettext("chat", "P2P session with %{peer} — click to focus", peer: peer),
          stop_title: dgettext("chat", "End the P2P session")
        }

      _joining_or_connecting ->
        %{
          label: dgettext("chat", "P2P: connecting to %{peer}...", peer: peer),
          title: dgettext("chat", "P2P session connecting"),
          stop_title: dgettext("chat", "End the P2P session")
        }
    end
  end

  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  defp online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  defp online_buddy_count(_notify_list), do: 0
end
