defmodule RetroHexChatWeb.ShowcaseLive.Slider do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Slider
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Slider", active_page: "slider")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Slider</h2>

      <.showcase_card
        title="Usage"
        description="An input where the user selects a value from within a given range."
      >
        <div class="max-w-sm space-y-4">
          <.slider id="slider-1" value={50} min={0} max={100} />
          <.slider id="slider-2" value={25} min={0} max={100} step={5} />
        </div>
        <.code_example>
          &lt;.slider id="volume" value=&#123;50&#125; min=&#123;0&#125; max=&#123;100&#125; /&gt;
          &lt;.slider id="step" value=&#123;25&#125; min=&#123;0&#125; max=&#123;100&#125; step=&#123;5&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
