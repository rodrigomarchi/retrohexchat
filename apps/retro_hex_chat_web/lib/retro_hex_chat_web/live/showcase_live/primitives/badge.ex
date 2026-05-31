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
    {:ok, assign(socket, page_title: dgettext("showcase", "Badge"), active_page: "badge")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Badge")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Variants")}
        description="All badge variants — sunken status-bar panel style."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge>{dgettext("showcase", "Default")}</.badge>
          <.badge variant="secondary">{dgettext("showcase", "Secondary")}</.badge>
          <.badge variant="destructive">{dgettext("showcase", "Destructive")}</.badge>
          <.badge variant="outline">{dgettext("showcase", "Outline")}</.badge>
          <.badge variant="success">{dgettext("showcase", "Success")}</.badge>
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
        title={dgettext("showcase", "Status Indicators")}
        description="Badges as connection or session state labels."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="success">{dgettext("showcase", "Connected")}</.badge>
          <.badge variant="secondary">{dgettext("showcase", "Waiting")}</.badge>
          <.badge variant="destructive">{dgettext("showcase", "Failed")}</.badge>
          <.badge variant="outline">{dgettext("showcase", "Idle")}</.badge>
          <.badge>{dgettext("showcase", "In Call")}</.badge>
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Role Labels")}
        description="Badges as user role indicators in chat."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="destructive">{dgettext("showcase", "Owner")}</.badge>
          <.badge>{dgettext("showcase", "Operator")}</.badge>
          <.badge variant="secondary">{dgettext("showcase", "Half-Op")}</.badge>
          <.badge variant="success">{dgettext("showcase", "Voiced")}</.badge>
          <.badge variant="outline">{dgettext("showcase", "Regular")}</.badge>
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Metadata Tags")}
        description="Badges as small metadata tags on channels or files."
      >
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="outline">{dgettext("showcase", "+nt")}</.badge>
          <.badge variant="outline">{dgettext("showcase", "+s")}</.badge>
          <.badge variant="secondary">{dgettext("showcase", "PNG")}</.badge>
          <.badge variant="secondary">{dgettext("showcase", "2.4 MB")}</.badge>
          <.badge>{dgettext("showcase", "ScummVM")}</.badge>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
