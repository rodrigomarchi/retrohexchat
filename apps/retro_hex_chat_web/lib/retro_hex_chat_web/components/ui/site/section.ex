defmodule RetroHexChatWeb.Components.UI.Site.Section do
  @moduledoc """
  The bodies the windows of the site share.

  A body is a function component a window declares (`RetroHexChatWeb.Site.Window`,
  `:body`); the window's island calls it with what the page loaded, the
  window's own assigns on top and the window itself as `@window`.

  The pieces a body is built from are here too, so every window of the site
  reads alike: its heading, its comparison table and its links to the other
  pages. The list of features and
  the inset panel are the UI's own (`Components.UI.FeatureList`,
  `Components.UI.Inset`), shared with the chat.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Table

  alias RetroHexChatWeb.PublicPages

  attr :page, :atom, required: true, doc: "a public page by its name, as `PublicPages` lists it"
  attr :class, :any, default: "underline"
  slot :inner_block, required: true

  @doc """
  A link to one of the site's public pages, in the reader's language, named by
  the page rather than spelt as a path: a page that does not exist fails here
  instead of quietly leading home.
  """
  @spec page_link(map()) :: Phoenix.LiveView.Rendered.t()
  def page_link(assigns) do
    %{path: path} =
      PublicPages.find(assigns.page) ||
        raise ArgumentError, "no public page #{inspect(assigns.page)}"

    assigns = assign(assigns, :path, PublicPages.localized_path(path))

    ~H"""
    <.link patch={@path} class={@class}>{render_slot(@inner_block)}</.link>
    """
  end

  attr :window, RetroHexChatWeb.Site.Window, required: true, doc: "its title is the page's h1"
  attr :heading_id, :string, required: true
  attr :description, :string, required: true

  @doc "The window a page opens with, in front of the rest: its heading and what the page is about."
  @spec page_intro(map()) :: Phoenix.LiveView.Rendered.t()
  def page_intro(assigns) do
    ~H"""
    <h1 id={@heading_id} class="text-lg font-bold mb-2 text-text">{@window.title}</h1>
    <p class="text-sm max-w-3xl">{@description}</p>
    """
  end

  attr :id, :string, default: nil, doc: "for the page outline, when something links to it"
  slot :inner_block, required: true

  @doc "A window's heading: the section's own h2, under the h1 of the page's first window."
  @spec section_heading(map()) :: Phoenix.LiveView.Rendered.t()
  def section_heading(assigns) do
    ~H"""
    <h2 id={@id} class="text-sm font-bold mb-2">{render_slot(@inner_block)}</h2>
    """
  end

  attr :theirs, :string, required: true, doc: "whom the site is set against, the middle column"

  attr :rows, :list,
    required: true,
    doc: "`{aspect, theirs, ours}` per row, translated"

  attr :class, :any, default: nil

  @doc "The site set against the platforms a reader knows, one aspect a row."
  @spec comparison_table(map()) :: Phoenix.LiveView.Rendered.t()
  def comparison_table(assigns) do
    ~H"""
    <.inset class={["p-2", @class]}>
      <.table class="text-xs">
        <.table_header>
          <.table_row>
            <.table_head></.table_head>
            <.table_head>{@theirs}</.table_head>
            <.table_head>{dgettext("landing", "Retro Hex Chat")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :for={{aspect, theirs, ours} <- @rows}>
            <.table_cell><strong>{aspect}</strong></.table_cell>
            <.table_cell>{theirs}</.table_cell>
            <.table_cell>{ours}</.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </.inset>
    """
  end
end
