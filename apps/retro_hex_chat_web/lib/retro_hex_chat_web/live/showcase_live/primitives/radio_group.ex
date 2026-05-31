defmodule RetroHexChatWeb.ShowcaseLive.Primitives.RadioGroup do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.RadioGroup
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "Radio Group"), active_page: "radio-group")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Radio Group")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Usage")}
        description="A set of checkable buttons where only one can be checked at a time. Uses the builder pattern."
      >
        <.radio_group :let={builder} name="preference" value="option-1">
          <div class="space-y-2">
            <div class="flex items-center gap-2">
              <.radio_group_item builder={builder} value="option-1" id="r1" />
              <.label for="r1">{dgettext("showcase", "Default")}</.label>
            </div>
            <div class="flex items-center gap-2">
              <.radio_group_item builder={builder} value="option-2" id="r2" />
              <.label for="r2">{dgettext("showcase", "Comfortable")}</.label>
            </div>
            <div class="flex items-center gap-2">
              <.radio_group_item builder={builder} value="option-3" id="r3" />
              <.label for="r3">{dgettext("showcase", "Compact")}</.label>
            </div>
          </div>
        </.radio_group>
        <.code_example>
          &lt;.radio_group :let=&#123;builder&#125; name="preference" value="option-1"&gt;
          &lt;.radio_group_item builder=&#123;builder&#125; value="option-1" id="r1" /&gt;
          &lt;.label for="r1"&gt;Default&lt;/.label&gt;

          &lt;.radio_group_item builder=&#123;builder&#125; value="option-2" id="r2" /&gt;
          &lt;.label for="r2"&gt;Comfortable&lt;/.label&gt;
          &lt;/.radio_group&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
