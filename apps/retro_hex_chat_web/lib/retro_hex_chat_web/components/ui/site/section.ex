defmodule RetroHexChatWeb.Components.UI.Site.Section do
  @moduledoc """
  The bodies the windows of the site share.

  A body is a function component a window declares (`RetroHexChatWeb.Site.Window`,
  `:body`); the window's island calls it with what the page loaded, the
  window's own assigns on top and the window itself as `@window`.

  The pieces a body is built from are here too, so every window of the site
  reads alike: its heading, a list of features, and the inset panels its
  illustrations and notes sit in.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Table

  alias RetroHexChatWeb.Icons

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

  slot :item, required: true, doc: "one feature, its words" do
    attr :icon, :atom, required: true, doc: "a `RetroHexChatWeb.Icons` function"
  end

  @doc "What a section offers, a line each, each line led by its icon."
  @spec feature_list(map()) :: Phoenix.LiveView.Rendered.t()
  def feature_list(assigns) do
    ~H"""
    <ul class="space-y-1.5">
      <li :for={item <- @item} class="flex items-start gap-2 text-xs">
        {apply(Icons, item.icon, [%{class: "w-4 h-4 shrink-0 mt-0.5"}])}
        <span>{render_slot(item)}</span>
      </li>
    </ul>
    """
  end

  attr :tone, :string,
    values: ~w(paper canvas diagram screen),
    default: "paper",
    doc:
      "what the panel holds: `paper` notes and tables, a `canvas` mockup of the chat, " <>
        "a `diagram`, or a `screen` of the running app"

  attr :class, :any, default: nil, doc: "its padding and spacing"
  attr :rest, :global
  slot :inner_block, required: true

  @doc "A sunken panel inside a window, the way Win98 framed a field or a picture."
  @spec inset(map()) :: Phoenix.LiveView.Rendered.t()
  def inset(assigns) do
    ~H"""
    <div class={["shadow-retro-field", tone_class(@tone), @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp tone_class("paper"), do: "bg-white"
  defp tone_class("canvas"), do: "bg-canvas-bg text-canvas-fg"
  defp tone_class("diagram"), do: "bg-diagram-bg"
  defp tone_class("screen"), do: "bg-black"

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
