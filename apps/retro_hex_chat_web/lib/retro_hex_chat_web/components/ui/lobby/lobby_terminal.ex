defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyTerminal do
  @moduledoc """
  Full-screen terminal state for the P2P lobby.

  Shown when a lobby has reached its end (closed, expired, failed, peer left) or
  when the link can no longer be opened (unknown token, or the viewer was never a
  participant). For an ended session it reuses the same rich card the chat draws
  (`SessionCard.session_card/1`) — subject icon, creator/peer, lifecycle timeline,
  duration and close reason — so the goodbye screen mirrors the in-chat card. For
  an unresolvable link it shows a friendly explanation instead.

  The action button closes the current browser tab (a lobby link opens in its own
  tab via `LobbyCloseWindowHook`), rather than navigating this tab to the
  single-instance chat.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  alias RetroHexChatWeb.ChatLive.Components.SessionCard
  alias RetroHexChatWeb.Icons

  attr :invalid, :boolean,
    default: false,
    doc: "true when the link is unknown/inaccessible rather than a session that ran and ended"

  attr :summary, :map, default: nil, doc: "resolved lobby session summary; nil for invalid links"
  attr :reason, :string, default: nil, doc: "friendly, humanized end/close reason"
  attr :timezone, :string, default: "Etc/UTC"

  @spec lobby_terminal(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_terminal(assigns) do
    ~H"""
    <div class="lobby-terminal flex h-screen flex-col items-center justify-center bg-background p-8 text-foreground">
      <div
        class="shadow-retro-window bg-surface w-full max-w-sm p-6 text-center"
        data-testid="lobby-ended"
      >
        <.heading_icon invalid={@invalid} class="mx-auto mb-3 h-8 w-8" />
        <p class="mb-1 text-sm font-bold">{heading(@invalid)}</p>
        <p :if={@reason} class="text-muted-foreground mb-4 text-xs">{@reason}</p>

        <div :if={@summary} class="mb-4 flex justify-center">
          <SessionCard.session_card card={@summary} timezone={@timezone} />
        </div>

        <.button
          id="lobby-close-window"
          phx-hook="LobbyCloseWindowHook"
          size="sm"
          variant="outline"
        >
          <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
          {dgettext("lobby", "Close window")}
        </.button>
      </div>
    </div>
    """
  end

  @spec heading(boolean()) :: String.t()
  defp heading(true), do: dgettext("lobby", "Lobby unavailable")
  defp heading(false), do: dgettext("lobby", "Lobby ended")

  attr :invalid, :boolean, required: true
  attr :class, :string, default: nil

  defp heading_icon(%{invalid: true} = assigns), do: ~H"<Icons.icon_question class={@class} />"
  defp heading_icon(assigns), do: ~H"<Icons.icon_btn_disconnect class={@class} />"
end
