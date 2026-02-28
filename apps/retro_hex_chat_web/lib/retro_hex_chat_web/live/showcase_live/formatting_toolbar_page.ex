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
        description="Formatting toolbar with B/I/U, color, control, strip, and emoji buttons. Click the color button to toggle the dropdown."
      >
        <.formatting_toolbar id="demo-default" />
        <.code_example>
          &lt;.formatting_toolbar id="my-toolbar" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Active Formatting"
        description="Bold and underline active (pressed state)."
      >
        <.formatting_toolbar id="demo-active" bold_active={true} underline_active={true} />
      </.showcase_card>

      <.showcase_card
        title="Strip Active"
        description="Strip formatting toggle active."
      >
        <.formatting_toolbar id="demo-strip" strip_active={true} />
      </.showcase_card>

      <.showcase_card
        title="All Active"
        description="All formatting states active simultaneously."
      >
        <.formatting_toolbar
          id="demo-all"
          bold_active={true}
          italic_active={true}
          underline_active={true}
          strip_active={true}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
