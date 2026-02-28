defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Badge do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Badge", active_page: "badge")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Badge</h2>

      <.showcase_card title="Variants" description="All badge variants — sunken status-bar panel style.">
        <div class="flex flex-wrap items-center gap-2">
          <.badge>Default</.badge>
          <.badge variant="secondary">Secondary</.badge>
          <.badge variant="destructive">Destructive</.badge>
          <.badge variant="outline">Outline</.badge>
          <.badge variant="success">Success</.badge>
        </div>
        <.code_example>
          &lt;.badge&gt;Default&lt;/.badge&gt;
          &lt;.badge variant="secondary"&gt;Secondary&lt;/.badge&gt;
          &lt;.badge variant="destructive"&gt;Destructive&lt;/.badge&gt;
          &lt;.badge variant="outline"&gt;Outline&lt;/.badge&gt;
          &lt;.badge variant="success"&gt;Success&lt;/.badge&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Status Indicators" description="Badges as connection or session state labels.">
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="success">Connected</.badge>
          <.badge variant="secondary">Waiting</.badge>
          <.badge variant="destructive">Failed</.badge>
          <.badge variant="outline">Idle</.badge>
          <.badge>In Call</.badge>
        </div>
      </.showcase_card>

      <.showcase_card title="Role Labels" description="Badges as user role indicators in chat.">
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="destructive">Owner</.badge>
          <.badge>Operator</.badge>
          <.badge variant="secondary">Half-Op</.badge>
          <.badge variant="success">Voiced</.badge>
          <.badge variant="outline">Regular</.badge>
        </div>
      </.showcase_card>

      <.showcase_card title="Metadata Tags" description="Badges as small metadata tags on channels or files.">
        <div class="flex flex-wrap items-center gap-2">
          <.badge variant="outline">+nt</.badge>
          <.badge variant="outline">+s</.badge>
          <.badge variant="secondary">PNG</.badge>
          <.badge variant="secondary">2.4 MB</.badge>
          <.badge>ScummVM</.badge>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
