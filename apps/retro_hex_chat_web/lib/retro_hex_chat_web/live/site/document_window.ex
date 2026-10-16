defmodule RetroHexChatWeb.Site.DocumentWindow do
  @moduledoc """
  A page of the site as a window of the one desktop.

  The window is the page's own frame: its title and icon, the menus that hang
  under its title bar — the site's (Navigate / Help / Language), the help
  viewer's, or the sign-in window's — the strip listing its sections, the page
  itself, and the site's About at the foot of every page.

  It is rendered on the first response, fully, so a reader and a search engine
  get the page before any script runs; `data-window-initial-focus` tells the
  window manager it is the window in front.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Help.HelpMenuBar
  import RetroHexChatWeb.Components.UI.Help.HelpStatusBar
  import RetroHexChatWeb.Components.UI.Landing.LandingShell
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.Site.Document

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Icons

  attr :doc, :map, required: true, doc: "a `RetroHexChatWeb.Site.Documents.doc/0`"
  attr :focused, :boolean, default: false

  @spec document_window(map()) :: Phoenix.LiveView.Rendered.t()
  def document_window(assigns) do
    ~H"""
    <.desktop_window
      id={@doc.id}
      title={@doc.title}
      managed
      default_centered
      default_fill={fill(@doc.slot)}
      width={width(@doc.slot)}
      height={height(@doc.slot)}
      min_width={320}
      persist_geometry={false}
      class="desktop-window--document"
      body_class="flex min-h-0 flex-col p-0"
      data-document-slot={@doc.slot}
      data-document-page={@doc.active_page}
      data-window-initial-focus={to_string(@focused)}
      data-testid={"document-window-#{@doc.slot}"}
    >
      <:icon>{apply(Icons, @doc.icon, [%{class: "h-4 w-4"}])}</:icon>
      <:meta :if={@doc.meta}>{@doc.meta}</:meta>

      <:menu :if={@doc.menu == :site}>
        <.landing_menu_bar
          active_page={@doc.active_page}
          current_path={@doc.assigns[:canonical_path]}
        />
      </:menu>
      <:menu :if={@doc.menu == :help}>
        <.help_menu_bar
          id="help-menubar"
          current_path={@doc.assigns[:canonical_path]}
          phx-hook="MenuBarHook"
        />
      </:menu>
      <:menu :if={@doc.menu == :connect}>
        <.menu_bar_app id="connect-menubar" phx-hook="MenuBarHook" connected={false} />
      </:menu>

      <:status :if={@doc.menu == :help}>
        <.help_status_zones
          selected_topic={@doc.assigns[:selected_topic]}
          topic_count={length(HelpTopics.all_topics())}
        />
      </:status>

      <div class="min-h-0 flex-1 overflow-y-auto" data-document-body>
        <.document_contents :if={@doc.slot == :site} sections={@doc.sections} class="p-retro-8 pb-0" />
        {@doc.page.render(@doc.assigns)}
        <div :if={@doc.slot == :site} class="m-4">
          <.site_about current_path={@doc.assigns[:canonical_path] || "/"} />
        </div>
      </div>
    </.desktop_window>
    """
  end

  # A page of the site reads like a document, so it opens large; the help is
  # a viewer with a navigator beside the topic; the small windows are a card
  # and a form.
  defp width(:site), do: 960
  defp width(:help), do: 900
  defp width(:archive), do: 760
  defp width(_slot), do: 560

  defp height(:site), do: 640
  defp height(:help), do: 620
  defp height(:archive), do: 560
  defp height(_slot), do: nil

  defp fill(slot) when slot in [:site, :help], do: 0.9
  defp fill(_slot), do: 0.0
end
