defmodule RetroHexChatWeb.Components.AppHeader do
  @moduledoc "Shared app header: logo + extensible panels area."
  use Phoenix.Component

  attr :logo_href, :string, default: nil, doc: "When set, wraps the logo in a link"

  slot :panels, doc: "Content for the panels area (toolbar, nav links, skeleton, etc.)"

  @spec app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def app_header(assigns) do
    ~H"""
    <div class="app-header">
      <%= if @logo_href do %>
        <a href={@logo_href}>
          <img src="/images/header-logo.svg" alt="RetroHexChat" class="app-header-wordmark" />
        </a>
      <% else %>
        <img src="/images/header-logo.svg" alt="RetroHexChat" class="app-header-wordmark" />
      <% end %>
      <div class="app-header-panels">
        {render_slot(@panels)}
      </div>
    </div>
    """
  end
end
