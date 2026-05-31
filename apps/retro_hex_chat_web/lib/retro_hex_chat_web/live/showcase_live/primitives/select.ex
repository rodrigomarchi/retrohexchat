defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Select do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Select
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Select"), active_page: "select")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Select")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Usage")}
        description="Dropdown selection from a list of options. Uses the builder pattern."
      >
        <div class="max-w-sm">
          <.select
            :let={builder}
            id="showcase-select"
            name="channel"
            placeholder={dgettext("showcase", "Select a channel...")}
          >
            <.select_trigger builder={builder} />
            <.select_content builder={builder}>
              <.select_group>
                <.select_label>{dgettext("showcase", "Channels")}</.select_label>
                <.select_item builder={builder} value="general">#general</.select_item>
                <.select_item builder={builder} value="random">#random</.select_item>
                <.select_item builder={builder} value="help">#help</.select_item>
              </.select_group>
            </.select_content>
          </.select>
        </div>
        <.code_example>
          &lt;.select :let=&#123;builder&#125; id="my-select" name="channel" placeholder="Select..."&gt;
          &lt;.select_trigger builder=&#123;builder&#125; /&gt;
          &lt;.select_content builder=&#123;builder&#125;&gt;
          &lt;.select_group&gt;
          &lt;.select_label&gt;Channels&lt;/.select_label&gt;
          &lt;.select_item builder=&#123;builder&#125; value="general"&gt;#general&lt;/.select_item&gt;
          &lt;.select_item builder=&#123;builder&#125; value="random"&gt;#random&lt;/.select_item&gt;
          &lt;/.select_group&gt;
          &lt;/.select_content&gt;
          &lt;/.select&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
