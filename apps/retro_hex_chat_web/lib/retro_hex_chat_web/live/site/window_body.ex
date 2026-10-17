defmodule RetroHexChatWeb.Site.WindowBody do
  @moduledoc """
  The island inside every window of a page: it renders what the window holds
  from the window's declaration (`RetroHexChatWeb.Site.Window`) and what the
  page loaded.

  The desktop the pages share is the chat's, which re-renders on every message.
  The island takes two values that change only when the page does — the
  window and the page's assigns — so a window's body is diffed when the page
  it belongs to changes, and never because the chat behind it moved.

  A section of the site has nothing to do: it is read, and its links patch the
  address, so the island carries no events. A body that does have something
  to do mounts an island of its own inside (`Site.HelpViewer`,
  `RetroHexChatWeb.ConnectForm`).
  """
  use Phoenix.LiveComponent

  alias RetroHexChatWeb.Site.Window

  @doc "The id of the island inside the window whose DOM id is `window_dom_id`."
  @spec id(String.t()) :: String.t()
  def id(window_dom_id), do: window_dom_id <> "-body"

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="contents" data-window-body={@window.id}>
      {@window.body.(Window.body_assigns(@window, @page_assigns))}
    </div>
    """
  end
end
