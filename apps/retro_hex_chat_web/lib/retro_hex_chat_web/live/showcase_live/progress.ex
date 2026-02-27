defmodule RetroHexChatWeb.ShowcaseLive.Progress do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Progress
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Progress", active_page: "progress")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Progress</h2>

      <.showcase_card title="Values" description="Displays an indicator showing completion progress.">
        <div class="max-w-sm space-y-3">
          <.progress value={25} />
          <.progress value={50} />
          <.progress value={80} />
          <.progress value={100} />
        </div>
        <.code_example>
          &lt;.progress value=&#123;25&#125; /&gt;
          &lt;.progress value=&#123;50&#125; /&gt;
          &lt;.progress value=&#123;100&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
