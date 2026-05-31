defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Input do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Input"), active_page: "input")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Input")}</h2>

      <.showcase_card title={gettext("Types")} description="Text input field for user data entry.">
        <div class="space-y-3 max-w-sm">
          <.input type="text" placeholder={gettext("Enter text...")} />
          <.input type="email" placeholder={gettext("email@example.com")} />
          <.input type="password" placeholder={gettext("Password")} />
          <.input type="text" placeholder={gettext("Disabled")} disabled />
        </div>
        <.code_example>
          &lt;.input type="text" placeholder="Enter text..." /&gt;
          &lt;.input type="email" placeholder="email@example.com" /&gt;
          &lt;.input type="password" placeholder="Password" /&gt;
          &lt;.input type="text" placeholder="Disabled" disabled /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
