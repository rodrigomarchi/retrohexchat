defmodule RetroHexChatWeb.Components.UI.Site.Document do
  @moduledoc """
  The pages of the site as windows of the desktop.

  Every window is drawn from its declaration (`RetroHexChatWeb.Site.Window`):
  its title, icon, size and status bar from the entry, its body by the island
  inside it (`RetroHexChatWeb.Site.WindowBody`). A page of the site opens as a
  group of windows, one per section, all in the `site` group — the window
  manager lays the group out together when the page opens, and the page closes
  when the last of them does (`Site.Documents`). Help, an
  invitation and sign-in are one window each, with the menus and status their
  page declares.

  The desktop hands `site_documents/1` the documents and their order and
  nothing else, so the chat re-rendering around them never reaches a page.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Help.HelpMenuBar
  import RetroHexChatWeb.Components.UI.Help.HelpStatusBar
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Site.Registry
  alias RetroHexChatWeb.Site.Window
  alias RetroHexChatWeb.Site.WindowBody

  @group "site"

  @doc "The window group every page of the site opens in."
  @spec group() :: String.t()
  def group, do: @group

  @doc "The DOM id of a window of a page of the site."
  @spec window_id(Window.t()) :: String.t()
  def window_id(%Window{id: id}), do: "site-" <> id

  @doc "The DOM id of the window a document's `window` is drawn in."
  @spec dom_id(map(), Window.t()) :: String.t()
  def dom_id(%{slot: :site}, window), do: window_id(window)
  def dom_id(%{slot: slot}, _window), do: Registry.window_id(slot)

  @doc """
  Every document on the desktop, the one in front last: a page of the site as
  its group of windows, any other as its one window.
  """
  attr :docs, :map, required: true, doc: "`Site.Documents.doc/0` by slot"
  attr :order, :list, required: true, doc: "the slots, the one in front first"
  attr :focused, :atom, default: nil, doc: "the slot in front, or nil when the chat is"

  @spec site_documents(map()) :: Phoenix.LiveView.Rendered.t()
  def site_documents(assigns) do
    assigns =
      assign(
        assigns,
        :documents,
        for(slot <- Enum.reverse(assigns.order), do: assigns.docs[slot])
      )

    ~H"""
    <%= for doc <- @documents do %>
      <.site_group :if={doc.slot == :site} doc={doc} focused={doc.slot == @focused} />
      <.document_window :if={doc.slot != :site} doc={doc} focused={doc.slot == @focused} />
    <% end %>
    """
  end

  attr :doc, :map, required: true
  attr :focused, :boolean, required: true

  # Whether the group opens on screen, and whether its first window takes the
  # front, is the page's to say, once for all of its windows: the home a
  # visitor's chat is in front of waits closed for its desktop icon.
  defp site_group(assigns) do
    assigns = assign(assigns, :group, @group)

    ~H"""
    <div
      class="contents"
      data-window-group-root={@group}
      data-window-group-open={to_string(@doc.open?)}
      data-window-group-focus={to_string(@focused)}
      data-document-page={@doc.active_page}
      data-document-address={@doc.assigns.canonical_path}
      data-testid="site-windows"
    >
      <.site_window
        :for={window <- @doc.windows}
        window={window}
        page_assigns={@doc.assigns}
        group={@group}
      />
    </div>
    """
  end

  @doc """
  A window of the site: its title bar, its body — the island — and its status
  bar, all from the declaration. A member of a group belongs to `group`; one
  standing alone (the site's About) opens as `open` says.
  """
  attr :window, Window, required: true
  attr :page_assigns, :map, required: true, doc: "what the window's page loaded"
  attr :group, :string, default: nil
  attr :open, :boolean, default: true
  attr :rest, :global

  @spec site_window(map()) :: Phoenix.LiveView.Rendered.t()
  def site_window(assigns) do
    assigns = assign(assigns, :dom_id, window_id(assigns.window))

    ~H"""
    <.desktop_window
      id={@dom_id}
      title={@window.title}
      open={@open}
      default_centered={is_nil(@group)}
      width={@window.width}
      height={@window.height}
      min_width={280}
      persist_geometry={false}
      class="desktop-window--site"
      body_class="site-window__body p-retro-8"
      data-window-group={@group}
      data-document-slot={@group}
      data-testid={"site-window-" <> @window.id}
      {@rest}
    >
      <:icon>{Window.icon(@window)}</:icon>
      <.live_component
        module={WindowBody}
        id={WindowBody.id(@dom_id)}
        window={@window}
        page_assigns={@page_assigns}
      />
      <:status :if={@window.status != []}><.status_fields fields={@window.status} /></:status>
    </.desktop_window>
    """
  end

  attr :doc, :map, required: true, doc: "a one-window `Site.Documents.doc/0`"
  attr :focused, :boolean, required: true

  # A page that is one window — help, an invitation, sign-in —
  # rendered on the first response, whole, so a reader and a search engine get
  # it before any script runs; `data-window-initial-focus` tells the window
  # manager it is the window in front.
  defp document_window(assigns) do
    assigns =
      assign(assigns,
        window: hd(assigns.doc.windows),
        dom_id: Registry.window_id(assigns.doc.slot)
      )

    ~H"""
    <.desktop_window
      id={@dom_id}
      title={@window.title}
      default_centered
      default_fill={@window.fill}
      width={@window.width}
      height={@window.height}
      min_width={320}
      persist_geometry={false}
      class="desktop-window--document"
      body_class="flex min-h-0 flex-col p-0"
      data-document-slot={@doc.slot}
      data-document-page={@doc.active_page}
      data-window-initial-focus={to_string(@focused)}
      data-testid={"document-window-#{@doc.slot}"}
    >
      <:icon>{Window.icon(@window)}</:icon>
      <:meta :if={@window.meta}>{@window.meta}</:meta>

      <:menu :if={@window.menu == :help}>
        <.help_menu_bar
          id="help-menubar"
          current_path={@doc.assigns[:canonical_path]}
          phx-hook="MenuBarHook"
        />
      </:menu>

      <:status :if={@window.menu == :help}>
        <.help_status_zones
          selected_topic={@doc.assigns[:selected_topic]}
          topic_count={length(HelpTopics.all_topics())}
        />
      </:status>
      <:status :if={@window.menu != :help and @window.status != []}>
        <.status_fields fields={@window.status} />
      </:status>

      <div class="min-h-0 flex-1 overflow-y-auto" data-document-body>
        <.live_component
          module={WindowBody}
          id={WindowBody.id(@dom_id)}
          window={@window}
          page_assigns={@doc.assigns}
        />
      </div>
    </.desktop_window>
    """
  end

  attr :fields, :list, required: true, doc: "`Site.Window.status_field/0`s, the first growing"

  defp status_fields(assigns) do
    assigns = assign(assigns, :fields, Enum.with_index(assigns.fields))

    ~H"""
    <.window_status_bar_field :for={{field, index} <- @fields} grow={index == 0}>
      <%= case field do %>
        <% {:check, text} -> %>
          <Icons.icon_checkmark class="w-3 h-3 inline" /> {text}
        <% text -> %>
          {text}
      <% end %>
    </.window_status_bar_field>
    """
  end
end
