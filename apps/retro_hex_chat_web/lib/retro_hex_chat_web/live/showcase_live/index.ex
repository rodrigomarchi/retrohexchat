defmodule RetroHexChatWeb.ShowcaseLive.Index do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @groups [
    {gettext("Primitives"), :icon_btn_ok, 23,
     gettext(
       "SaladUI base widgets — buttons, inputs, badges, toggles, selects, and other atomic form controls."
     )},
    {gettext("Layout"), :icon_group_view, 11,
     gettext(
       "Structural containers — dialogs, tabs, tables, menus, tree views, windows, and scroll areas."
     )},
    {gettext("Chat"), :icon_chat, 21,
     gettext(
       "Chat-specific components — messages, nicklist, emoji picker, formatting toolbar, context menus, and more."
     )},
    {gettext("Shell"), :icon_laptop, 7,
     gettext(
       "Win98 app shell composites — toolbar app, status bar app, app header, config form, and empty states."
     )},
    {gettext("Dialogs"), :icon_dialog_options, 25,
     gettext(
       "Complex dialog composites — channel settings, perform, address book, sound settings, and 20+ more."
     )},
    {"P2P", :icon_p2p, 3,
     gettext("Peer-to-peer session components — P2P lobby, file transfer, and media controls.")},
    {gettext("Games"), :icon_joystick, 5,
     gettext(
       "Arcade and solo game components — game lobby, game canvas, solo lobby, and arcade frame."
     )},
    {gettext("Assets"), :icon_folder, 3,
     gettext("Icons catalog, SVG diagrams, and design tokens reference.")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Component Showcase"),
       active_page: "index",
       groups: @groups
     )}
  end
end
