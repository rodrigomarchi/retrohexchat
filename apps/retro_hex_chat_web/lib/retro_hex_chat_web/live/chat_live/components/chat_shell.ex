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

  @spec chat_shell_header(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_shell_header(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        account_state: Session.identity_state(session),
        is_admin: ChatContext.admin?(session),
        online_buddy_count: online_buddy_count(session.notify_list),
        channel: session.active_pm || session.active_channel,
        tab_type: if(session.active_pm, do: :pm, else: :channel)
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
    />
    """
  end

  @spec online_buddy_count(%{entries: list()} | nil) :: non_neg_integer()
  defp online_buddy_count(%{entries: entries}) when is_list(entries) do
    Enum.count(entries, &(&1.online == true))
  end

  defp online_buddy_count(_notify_list), do: 0
end
