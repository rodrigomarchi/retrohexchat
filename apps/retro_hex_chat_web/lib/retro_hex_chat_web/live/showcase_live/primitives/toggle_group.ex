defmodule RetroHexChatWeb.ShowcaseLive.Primitives.ToggleGroup do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ToggleGroup
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Toggle Group"), active_page: "toggle-group")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Toggle Group")}</h2>

      <.showcase_card
        title={gettext("Single")}
        description="A set of two-state buttons where only one can be active (single mode)."
      >
        <.toggle_group :let={builder} name="align" value="left">
          <.toggle_group_item value="left" builder={builder}>{gettext("Left")}</.toggle_group_item>
          <.toggle_group_item value="center" builder={builder}>
            {gettext("Center")}
          </.toggle_group_item>
          <.toggle_group_item value="right" builder={builder}>{gettext("Right")}</.toggle_group_item>
        </.toggle_group>
        <.code_example>
          &lt;.toggle_group :let=&#123;builder&#125; name="align" value="left"&gt;
          &lt;.toggle_group_item value="left" builder=&#123;builder&#125;&gt;Left&lt;/.toggle_group_item&gt;
          &lt;.toggle_group_item value="center" builder=&#123;builder&#125;&gt;Center&lt;/.toggle_group_item&gt;
          &lt;.toggle_group_item value="right" builder=&#123;builder&#125;&gt;Right&lt;/.toggle_group_item&gt;
          &lt;/.toggle_group&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Multiple")}
        description="Multiple buttons can be active simultaneously. Pass multiple={true} and a list value."
      >
        <.code_example>
          &lt;.toggle_group :let=&#123;builder&#125; name="style" multiple=&#123;true&#125; value=&#123;["bold"]&#125;&gt;
          &lt;.toggle_group_item value="bold" builder=&#123;builder&#125;&gt;Bold&lt;/.toggle_group_item&gt;
          &lt;.toggle_group_item value="italic" builder=&#123;builder&#125;&gt;Italic&lt;/.toggle_group_item&gt;
          &lt;/.toggle_group&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
