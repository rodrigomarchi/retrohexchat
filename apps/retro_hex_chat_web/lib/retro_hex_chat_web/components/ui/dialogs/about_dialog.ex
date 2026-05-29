defmodule RetroHexChatWeb.Components.UI.AboutDialog do
  @moduledoc """
  About dialog component for the V2 interface.

  Shows the platform logo, version, description, and credits in a
  Win98-style dialog. Designed to be visually striking with the
  full-color compact logo and colored wordmark.

  ## Usage

      <.about_dialog id="about" show={true} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the about dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :version, :string, default: "2.0.0"

  @spec about_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def about_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="md:max-w-sm">
      <.dialog_header id={@id} title="About RetroHexChat">
        <:icon><Icons.icon_dialog_about class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="text-center">
        <%!-- Logo --%>
        <div class="flex justify-center pt-2 pb-3">
          <img
            src="/images/landing/logo-compact.svg"
            alt="RetroHexChat"
            class="w-16 h-16"
            draggable="false"
          />
        </div>

        <%!-- Wordmark --%>
        <p class="text-base font-bold mb-1">
          <span class="text-text">Retro</span><span class="text-desktop">Hex</span><span class="text-selection-bg">Chat</span>
        </p>
        <p class="text-xs text-muted-foreground mb-3">Version {@version}</p>

        <.separator />

        <%!-- Description --%>
        <div class="my-3 space-y-2">
          <p class="text-xs font-bold text-text">Public Chat Platform</p>
          <p class="text-[11px] text-muted-foreground leading-relaxed px-2">
            A retro-styled IRC chat platform inspired by the classic
            desktop chat clients of the late '90s. Real-time messaging,
            channels, peer-to-peer sessions, and arcade games — all
            in the browser.
          </p>
        </div>

        <.separator />

        <%!-- Tech & credits --%>
        <div class="my-3">
          <div class="flex items-center justify-center gap-2 text-[10px] text-muted-foreground mb-2">
            <span class="shadow-retro-raised bg-surface px-1.5 py-px">Elixir</span>
            <span class="shadow-retro-raised bg-surface px-1.5 py-px">Phoenix</span>
            <span class="shadow-retro-raised bg-surface px-1.5 py-px">LiveView</span>
            <span class="shadow-retro-raised bg-surface px-1.5 py-px">WebRTC</span>
          </div>
        </div>

        <.separator />

        <p class="text-[10px] text-muted-foreground mt-3">
          &copy; 2024–2026 RetroHexChat Contributors
        </p>
      </.dialog_body>

      <.dialog_footer>
        <.button
          id={"#{@id}-ok"}
          phx-hook="FocusChatInputOnClickHook"
          variant="default"
          phx-click={hide_modal(@id)}
        >
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
