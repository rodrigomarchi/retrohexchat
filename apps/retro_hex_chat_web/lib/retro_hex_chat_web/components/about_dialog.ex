defmodule RetroHexChatWeb.Components.AboutDialog do
  @moduledoc """
  Retro-style About dialog with ASCII art logo, version, and credits.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false

  @spec about_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def about_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-click="close_dialog"
      phx-value-dialog="about"
    >
      <div
        class="window about-dialog"
        data-testid="about-dialog"
        phx-click-away="close_dialog"
        phx-value-dialog="about"
      >
        <div class="title-bar">
          <Icons.icon_dialog_about class="title-bar-icon" />
          <div class="title-bar-text">About RetroHexChat</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_dialog" phx-value-dialog="about"></button>
          </div>
        </div>
        <div class="window-body about-body">
          <div>
            <pre class="about-logo" data-testid="about-logo">
    ╔══════════════════════╗
    ║   ╦═╗╦ ╦╔═╗          ║
    ║   ╠╦╝╠═╣║            ║
    ║   ╩╚═╩ ╩╚═╝          ║
    ║  RetroHexChat v1.0   ║
    ╚══════════════════════╝</pre>
            <p class="about-title">RetroHexChat v1.0</p>
            <p class="about-description">
              A retro IRC-style chat client with a classic 2000s-era aesthetic.
            </p>
            <hr />
            <p class="about-credits">
              Built with Elixir, Phoenix LiveView, and a retro design system.
            </p>
            <p class="about-credits">
              Inspired by mIRC and the golden age of IRC.
            </p>
          </div>
          <div class="about-buttons">
            <button class="about-ok-btn btn-icon" phx-click="close_dialog" phx-value-dialog="about">
              <Icons.icon_btn_ok class="btn-icon__svg" /> OK
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
