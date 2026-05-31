defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Avatar do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Avatar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Avatar"), active_page: "avatar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Avatar")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Usage")}
        description="An image element with a fallback for when the image fails to load."
      >
        <div class="flex gap-3 items-center">
          <.avatar>
            <.avatar_image src="https://github.com/shadcn.png" alt={dgettext("showcase", "User")} />
            <.avatar_fallback>{dgettext("showcase", "CN")}</.avatar_fallback>
          </.avatar>
          <.avatar>
            <.avatar_fallback>{dgettext("showcase", "RH")}</.avatar_fallback>
          </.avatar>
          <.avatar>
            <.avatar_fallback>{dgettext("showcase", "JD")}</.avatar_fallback>
          </.avatar>
        </div>
        <.code_example>
          &lt;.avatar&gt;
          &lt;.avatar_image src="/images/user.png" alt="User" /&gt;
          &lt;.avatar_fallback&gt;CN&lt;/.avatar_fallback&gt;
          &lt;/.avatar&gt;

          &lt;.avatar&gt;
          &lt;.avatar_fallback&gt;RH&lt;/.avatar_fallback&gt;
          &lt;/.avatar&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
