defmodule RetroHexChatWeb.ShowcaseLive.Layout.MenuPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Menu
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Menu"), active_page: "menu")}
  end
end
