defmodule RetroHexChatWeb.ShowcaseLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @groups [
    {"Primitives", :icon_btn_ok, 23,
     "SaladUI base widgets — buttons, inputs, badges, toggles, selects, and other atomic form controls."},
    {"Layout", :icon_group_view, 11,
     "Structural containers — dialogs, tabs, tables, menus, tree views, windows, and scroll areas."},
    {"Chat", :icon_chat, 21,
     "Chat-specific components — messages, nicklist, emoji picker, formatting toolbar, context menus, and more."},
    {"Shell", :icon_laptop, 7,
     "Win98 app shell composites — toolbar app, status bar app, app header, config form, and empty states."},
    {"Dialogs", :icon_dialog_options, 25,
     "Complex dialog composites — channel settings, perform, address book, sound settings, and 20+ more."},
    {"P2P", :icon_p2p, 3,
     "Peer-to-peer session components — P2P lobby, file transfer, and media controls."},
    {"Games", :icon_joystick, 5,
     "Arcade and solo game components — game lobby, game canvas, solo lobby, and arcade frame."},
    {"Assets", :icon_folder, 3, "Icons catalog, SVG diagrams, and design tokens reference."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Component Showcase", active_page: "index", groups: @groups)}
  end
end
