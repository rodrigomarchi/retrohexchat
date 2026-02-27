defmodule RetroHexChatWeb.ShowcaseLive.Button do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Button", active_page: "button")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Button</h2>

      <.showcase_card title="Variants" description="All button style variants.">
        <div class="flex flex-wrap gap-2">
          <.button variant="default">Default</.button>
          <.button variant="secondary">Secondary</.button>
          <.button variant="destructive">Destructive</.button>
          <.button variant="outline">Outline</.button>
          <.button variant="ghost">Ghost</.button>
          <.button variant="link">Link</.button>
        </div>
        <.code_example>
          &lt;.button variant="default"&gt;Default&lt;/.button&gt;
          &lt;.button variant="secondary"&gt;Secondary&lt;/.button&gt;
          &lt;.button variant="destructive"&gt;Destructive&lt;/.button&gt;
          &lt;.button variant="outline"&gt;Outline&lt;/.button&gt;
          &lt;.button variant="ghost"&gt;Ghost&lt;/.button&gt;
          &lt;.button variant="link"&gt;Link&lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Sizes" description="Available button sizes.">
        <div class="flex flex-wrap items-center gap-2">
          <.button size="sm">Small</.button>
          <.button size="default">Default</.button>
          <.button size="lg">Large</.button>
          <.button size="icon">+</.button>
        </div>
        <.code_example>
          &lt;.button size="sm"&gt;Small&lt;/.button&gt;
          &lt;.button size="default"&gt;Default&lt;/.button&gt;
          &lt;.button size="lg"&gt;Large&lt;/.button&gt;
          &lt;.button size="icon"&gt;+&lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="States" description="Disabled state.">
        <div class="flex flex-wrap gap-2">
          <.button>Normal</.button>
          <.button disabled>Disabled</.button>
        </div>
        <.code_example>
          &lt;.button&gt;Normal&lt;/.button&gt;
          &lt;.button disabled&gt;Disabled&lt;/.button&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
