defmodule RetroHexChatWeb.Components.UI.P2PLobby do
  @moduledoc """
  P2P lobby component for the showcase design system.

  Composed from window + button + progress + badge primitives.
  P2P connection setup, status display, and connection buttons.

  ## Usage

      <.p2p_lobby
        peer="alice"
        state="waiting"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Progress
  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  @doc "Renders the P2P lobby."
  attr :peer, :string, required: true
  attr :state, :string, default: "idle", values: ~w(idle waiting connecting connected failed)
  attr :on_connect, :any, default: nil, doc: "Connect button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"
  attr :on_disconnect, :any, default: nil, doc: "Disconnect button callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec p2p_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_lobby(assigns) do
    ~H"""
    <.window class={classes(["w-[320px]", @class])} data-testid="p2p-lobby" {@rest}>
      <.window_title_bar title="P2P Connection" controls={[:close]}>
        <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Peer info --%>
        <div class="flex items-center gap-retro-4 text-xs">
          <Icons.icon_status_user class="w-4 h-4" />
          <span class="font-bold">{@peer}</span>
          <.state_badge state={@state} />
        </div>

        <%!-- Connection diagram placeholder --%>
        <div class="shadow-retro-field bg-white p-retro-8 text-center text-xs">
          <div class="flex items-center justify-center gap-retro-8">
            <div class="text-center">
              <Icons.icon_laptop class="w-6 h-6 mx-auto" />
              <span class="block mt-retro-2">You</span>
            </div>
            <div class={[
              "w-16 h-[2px]",
              state_line_class(@state)
            ]} />
            <div class="text-center">
              <Icons.icon_laptop class="w-6 h-6 mx-auto" />
              <span class="block mt-retro-2">{@peer}</span>
            </div>
          </div>
        </div>

        <%!-- Progress bar when connecting --%>
        <.progress :if={@state == "connecting"} value={50} class="h-3" />

        <%!-- Action buttons --%>
        <div class="flex gap-retro-4">
          <.button
            :if={@state in ["idle", "failed"]}
            variant="default"
            phx-click={@on_connect}
            data-testid="p2p-lobby-connect"
          >
            <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
            Connect
          </.button>
          <.button
            :if={@state in ["waiting", "connecting"]}
            variant="destructive"
            phx-click={@on_cancel}
            data-testid="p2p-lobby-cancel"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            Cancel
          </.button>
          <.button
            :if={@state == "connected"}
            variant="outline"
            phx-click={@on_disconnect}
            data-testid="p2p-lobby-disconnect"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            Disconnect
          </.button>
        </div>
      </.window_body>
    </.window>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :state, :string, required: true

  defp state_badge(%{state: "idle"} = assigns), do: ~H|<.badge variant="outline">Idle</.badge>|

  defp state_badge(%{state: "waiting"} = assigns),
    do: ~H|<.badge variant="secondary">Waiting</.badge>|

  defp state_badge(%{state: "connecting"} = assigns),
    do: ~H|<.badge variant="secondary">Connecting</.badge>|

  defp state_badge(%{state: "connected"} = assigns),
    do: ~H|<.badge variant="default">Connected</.badge>|

  defp state_badge(%{state: "failed"} = assigns),
    do: ~H|<.badge variant="destructive">Failed</.badge>|

  defp state_line_class("connected"), do: "bg-success"
  defp state_line_class("connecting"), do: "bg-warning-alt"
  defp state_line_class("failed"), do: "bg-error"
  defp state_line_class(_), do: "bg-border"
end
