defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Badge do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Badge"), active_page: "badge")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Badge")}</h2>

      <.showcase_card
        title={gettext("Variants")}
        description="All badge variants — sunken status-bar panel style."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge>{gettext("Default")}</.badge>
          <.badge variant="secondary">{gettext("Secondary")}</.badge>
          <.badge variant="destructive">{gettext("Destructive")}</.badge>
          <.badge variant="outline">{gettext("Outline")}</.badge>
          <.badge variant="success">{gettext("Success")}</.badge>
        </div>
        <.code_example>
          &lt;.badge&gt;Default&lt;/.badge&gt;
          &lt;.badge variant="secondary"&gt;Secondary&lt;/.badge&gt;
          &lt;.badge variant="destructive"&gt;Destructive&lt;/.badge&gt;
          &lt;.badge variant="outline"&gt;Outline&lt;/.badge&gt;
          &lt;.badge variant="success"&gt;Success&lt;/.badge&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Status Indicators")}
        description="Badges as connection or session state labels."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="success">{gettext("Connected")}</.badge>
          <.badge variant="secondary">{gettext("Waiting")}</.badge>
          <.badge variant="destructive">{gettext("Failed")}</.badge>
          <.badge variant="outline">{gettext("Idle")}</.badge>
          <.badge>{gettext("In Call")}</.badge>
        </div>
      </.showcase_card>

      <.showcase_card
        title={gettext("Role Labels")}
        description="Badges as user role indicators in chat."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="destructive">{gettext("Owner")}</.badge>
          <.badge>{gettext("Operator")}</.badge>
          <.badge variant="secondary">{gettext("Half-Op")}</.badge>
          <.badge variant="success">{gettext("Voiced")}</.badge>
          <.badge variant="outline">{gettext("Regular")}</.badge>
        </div>
      </.showcase_card>

      <.showcase_card
        title={gettext("Metadata Tags")}
        description="Badges as small metadata tags on channels or files."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="outline">{gettext("+nt")}</.badge>
          <.badge variant="outline">{gettext("+s")}</.badge>
          <.badge variant="secondary">{gettext("PNG")}</.badge>
          <.badge variant="secondary">{gettext("2.4 MB")}</.badge>
          <.badge>{gettext("ScummVM")}</.badge>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
