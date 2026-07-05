defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyTerminal do
  @moduledoc """
  Terminal desktop state for the P2P lobby.

  Shown when a lobby has reached its end (closed, expired, failed, peer left) or
  when the link can no longer be opened (unknown token, or the viewer was never a
  participant). Runs on the same Win98 window manager as the rest of the app: a
  minimal desktop whose only surface is a pinned, centered goodbye dialog over a
  taskbar with a Start menu and tray clock. For an ended session the dialog
  reuses the same rich card the chat draws (`SessionCard.session_card/1`) —
  subject icon, creator/peer, lifecycle timeline, duration and close reason — so
  the goodbye screen mirrors the in-chat card. For an unresolvable link it shows
  a friendly explanation instead.

  The Close window action closes the current browser tab (a lobby link opens in
  its own tab via `LobbyCloseWindowHook`), rather than navigating this tab to
  the single-instance chat.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Desktop

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
    <div class="lobby-terminal flex h-screen flex-col bg-background text-foreground">
      <.desktop id="lobby-terminal-desktop" persist={false} data-testid="lobby-terminal-desktop">
        <.desktop_window
          id="lobby-ended"
          title={heading(@invalid)}
          pinned
          default_centered
          width={400}
          min_width={320}
          resizable={false}
          body_class="p-6 text-center"
          data-testid="lobby-ended"
        >
          <:icon><.heading_icon invalid={@invalid} class="h-4 w-4" /></:icon>
          <.heading_icon invalid={@invalid} class="mx-auto mb-3 h-8 w-8" />
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
        </.desktop_window>

        <:taskbar>
          <.taskbar>
            <:start>
              <div class="relative">
                <.start_button label={dgettext("lobby", "Lobby")}>
                  <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
                </.start_button>
                <.start_menu id="lobby-terminal-start-menu">
                  <.start_menu_item data-window-open="lobby-ended" label={heading(@invalid)}>
                    <:icon><.heading_icon invalid={@invalid} class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                  <.start_menu_separator />
                  <.start_menu_item
                    id="lobby-close-window-menu"
                    phx-hook="LobbyCloseWindowHook"
                    label={dgettext("lobby", "Close window")}
                    data-testid="lobby-terminal-menu-close"
                  >
                    <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
                  </.start_menu_item>
                </.start_menu>
              </div>
            </:start>

            <.taskbar_button window="lobby-ended" label={heading(@invalid)}>
              <:icon><.heading_icon invalid={@invalid} class="h-4 w-4" /></:icon>
            </.taskbar_button>

            <:tray>
              <.desktop_tray>
                <span
                  id="lobby-terminal-tray-clock"
                  phx-hook="ClockHook"
                  class="font-mono tabular-nums"
                >
                </span>
              </.desktop_tray>
            </:tray>
          </.taskbar>
        </:taskbar>
      </.desktop>
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
