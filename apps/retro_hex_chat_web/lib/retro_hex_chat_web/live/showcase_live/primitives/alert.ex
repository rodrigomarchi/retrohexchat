defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Alert do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Alert"), active_page: "alert")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Alert")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Variants")}
        description="Displays a callout for user attention."
      >
        <div class="space-y-3">
          <.alert>
            <:icon><Icons.icon_btn_info class="w-4 h-4" /></:icon>
            <.alert_title>{dgettext("showcase", "Default Alert")}</.alert_title>
            <.alert_description>
              {dgettext("showcase", "This is a default informational alert.")}
            </.alert_description>
          </.alert>
          <.alert variant="destructive">
            <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
            <.alert_title>{dgettext("showcase", "Error")}</.alert_title>
            <.alert_description>
              {dgettext("showcase", "Something went wrong. Please try again.")}
            </.alert_description>
          </.alert>
        </div>
        <.code_example>
          &lt;.alert&gt;
          &lt;.alert_title&gt;Default Alert&lt;/.alert_title&gt;
          &lt;.alert_description&gt;This is informational.&lt;/.alert_description&gt;
          &lt;/.alert&gt;

          &lt;.alert variant="destructive"&gt;
          &lt;.alert_title&gt;Error&lt;/.alert_title&gt;
          &lt;.alert_description&gt;Something went wrong.&lt;/.alert_description&gt;
          &lt;/.alert&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
