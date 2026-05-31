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
    {dgettext("showcase", "Primitives"), :icon_btn_ok, 23,
     dgettext(
       "showcase",
       "SaladUI base widgets — buttons, inputs, badges, toggles, selects, and other atomic form controls."
     )},
    {dgettext("showcase", "Layout"), :icon_group_view, 11,
     dgettext(
       "showcase",
       "Structural containers — dialogs, tabs, tables, menus, tree views, windows, and scroll areas."
     )},
    {dgettext("showcase", "Chat"), :icon_chat, 21,
     dgettext(
       "showcase",
       "Chat-specific components — messages, nicklist, emoji picker, formatting toolbar, context menus, and more."
     )},
    {dgettext("showcase", "Shell"), :icon_laptop, 7,
     dgettext(
       "showcase",
       "Win98 app shell composites — toolbar app, status bar app, app header, config form, and empty states."
     )},
    {dgettext("showcase", "Dialogs"), :icon_dialog_options, 25,
     dgettext(
       "showcase",
       "Complex dialog composites — channel settings, perform, address book, sound settings, and 20+ more."
     )},
    {"P2P", :icon_p2p, 3,
     dgettext(
       "showcase",
       "Peer-to-peer session components — P2P lobby, file transfer, and media controls."
     )},
    {dgettext("showcase", "Games"), :icon_joystick, 5,
     dgettext(
       "showcase",
       "Arcade and solo game components — game lobby, game canvas, solo lobby, and arcade frame."
     )},
    {dgettext("showcase", "Assets"), :icon_folder, 3,
     dgettext("showcase", "Icons catalog, SVG diagrams, and design tokens reference.")}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Component Showcase"),
       active_page: "index",
       groups: @groups
     )}
  end
end
