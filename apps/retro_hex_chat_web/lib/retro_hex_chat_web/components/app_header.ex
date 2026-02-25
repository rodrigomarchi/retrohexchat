defmodule RetroHexChatWeb.Components.AppHeader do
  @moduledoc "Shared app header: logo + extensible panels area."
  use Phoenix.Component

  attr :logo_href, :string, default: nil, doc: "When set, wraps the logo in a link"
  attr :logo_variant, :atom, default: :hex, values: [:hex, :full], doc: "Logo variant to display"

  slot :panels, doc: "Content for the panels area (toolbar, nav links, skeleton, etc.)"

  @spec app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def app_header(assigns) do
    ~H"""
    <div class="app-header">
      <%= if @logo_href do %>
        <a href={@logo_href}>
          <.header_logo variant={@logo_variant} />
        </a>
      <% else %>
        <.header_logo variant={@logo_variant} />
      <% end %>
      {render_slot(@panels)}
    </div>
    """
  end

  attr :variant, :atom, required: true

  @spec header_logo(map()) :: Phoenix.LiveView.Rendered.t()
  defp header_logo(%{variant: :full} = assigns) do
    ~H"""
    <img src="/images/header-logo.svg" alt="RetroHexChat" class="app-header-wordmark" />
    """
  end

  defp header_logo(assigns) do
    ~H"""
    <img src="/images/header-hex.svg" alt="RetroHexChat" class="app-header-logo" />
    """
  end
end
