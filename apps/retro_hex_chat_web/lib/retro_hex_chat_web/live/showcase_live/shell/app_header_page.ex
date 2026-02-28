defmodule RetroHexChatWeb.ShowcaseLive.Shell.AppHeaderPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "App Header", active_page: "app-header")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">App Header</h2>

      <.showcase_card
        title="Hex Logo Variant"
        description="Compact HEX logo for narrow layouts."
      >
        <.app_header logo_variant={:hex} />
        <.code_example>
          &lt;.app_header logo_variant={:hex} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Full Logo Variant"
        description="Full RetroHexChat wordmark for wider layouts."
      >
        <.app_header logo_variant={:full} />
        <.code_example>
          &lt;.app_header logo_variant={:full} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Logo Link"
        description="Logo becomes a clickable link when logo_href is provided."
      >
        <.app_header logo_variant={:hex} logo_href="/" />
      </.showcase_card>

      <.showcase_card
        title="With Panels Slot"
        description="Toolbar or navigation content rendered in the panels slot below the title bar."
      >
        <.app_header logo_variant={:full}>
          <:panels>
            <span class="text-xs px-retro-4 py-[2px] shadow-retro-raised bg-surface cursor-pointer hover:bg-gray-100">
              File
            </span>
            <span class="text-xs px-retro-4 py-[2px] shadow-retro-raised bg-surface cursor-pointer hover:bg-gray-100">
              Edit
            </span>
            <span class="text-xs px-retro-4 py-[2px] shadow-retro-raised bg-surface cursor-pointer hover:bg-gray-100">
              View
            </span>
            <span class="text-xs px-retro-4 py-[2px] shadow-retro-raised bg-surface cursor-pointer hover:bg-gray-100">
              Help
            </span>
          </:panels>
        </.app_header>
        <.code_example>
          &lt;.app_header logo_variant={:full}&gt;
          &lt;:panels&gt;
          &lt;span&gt;File&lt;/span&gt;
          &lt;span&gt;Edit&lt;/span&gt;
          &lt;/panels&gt;
          &lt;/.app_header&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
