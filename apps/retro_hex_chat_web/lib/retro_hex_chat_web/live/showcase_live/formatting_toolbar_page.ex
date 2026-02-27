defmodule RetroHexChatWeb.ShowcaseLive.FormattingToolbarPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.FormattingToolbar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Formatting Toolbar", active_page: "formatting-toolbar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Formatting Toolbar</h2>

      <.showcase_card
        title="Default"
        description="Formatting toolbar with B/I/U, color, control, and emoji buttons."
      >
        <.formatting_toolbar />
        <.code_example>
          &lt;.formatting_toolbar /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Active Formatting"
        description="Bold and underline active (pressed state)."
      >
        <.formatting_toolbar bold_active={true} underline_active={true} />
      </.showcase_card>

      <.showcase_card
        title="With Color Picker"
        description="Color picker panel expanded below the toolbar."
      >
        <.formatting_toolbar show_color_picker={true} selected_color={4} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
