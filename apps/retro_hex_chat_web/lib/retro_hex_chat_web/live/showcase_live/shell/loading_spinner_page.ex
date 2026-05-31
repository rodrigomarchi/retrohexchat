defmodule RetroHexChatWeb.ShowcaseLive.Shell.LoadingSpinnerPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.LoadingSpinner
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Loading Spinner"),
       active_page: "loading-spinner"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Loading Spinner")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default")}
        description="Retro-styled animated progress bar for loading states."
      >
        <.loading_spinner />
        <.code_example>
          &lt;.loading_spinner /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Custom Text")}
        description="Loading spinner with custom status text."
      >
        <.loading_spinner text={dgettext("showcase", "Loading messages...")} />
        <.code_example>
          &lt;.loading_spinner text="Loading messages..." /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Sizes")}
        description="Small, default, and large size variants."
      >
        <div class="space-y-4">
          <div class="shadow-retro-field bg-white p-2">
            <.loading_spinner size="sm" text={dgettext("showcase", "Small")} />
          </div>
          <div class="shadow-retro-field bg-white p-2">
            <.loading_spinner size="default" text={dgettext("showcase", "Default")} />
          </div>
          <div class="shadow-retro-field bg-white p-2">
            <.loading_spinner size="lg" text={dgettext("showcase", "Large")} />
          </div>
        </div>
        <.code_example>
          &lt;.loading_spinner size="sm" text="Small" /&gt;
          &lt;.loading_spinner size="default" text="Default" /&gt;
          &lt;.loading_spinner size="lg" text="Large" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Action")}
        description="Loading spinner with a retry button passed as inner block."
      >
        <.loading_spinner text={dgettext("showcase", "Connection timed out")}>
          <.button variant="outline" size="sm" class="pointer-events-auto">
            <:icon><Icons.icon_retry /></:icon>
            {dgettext("showcase", "Retry")}
          </.button>
        </.loading_spinner>
        <.code_example>
          &lt;.loading_spinner text="Connection timed out"&gt;
          &lt;.button variant="outline" size="sm"&gt;
          &lt;:icon&gt;&lt;Icons.icon_retry /&gt;&lt;/:icon&gt;
          Retry
          &lt;/.button&gt;
          &lt;/.loading_spinner&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
