defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Skeleton do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Skeleton
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Skeleton"), active_page: "skeleton")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Skeleton")}</h2>

      <.showcase_card title={gettext("Shapes")} description="Placeholder while content is loading.">
        <div class="space-y-3 max-w-sm">
          <.skeleton class="h-4 w-3/4" />
          <.skeleton class="h-4 w-1/2" />
          <.skeleton class="h-10 w-10 rounded-full" />
        </div>
        <.code_example>
          &lt;.skeleton class="h-4 w-3/4" /&gt;
          &lt;.skeleton class="h-4 w-1/2" /&gt;
          &lt;.skeleton class="h-10 w-10 rounded-full" /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
