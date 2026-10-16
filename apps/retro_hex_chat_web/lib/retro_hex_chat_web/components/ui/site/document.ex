defmodule RetroHexChatWeb.Components.UI.Site.Document do
  @moduledoc """
  The pieces a page of the site is built from.

  Each page opens as one document window over the chat, divided into
  sections: `document_section/1` takes the title, icon and status bar a
  `desktop_window/1` takes, so a section reads as a window of its own — headed,
  with its status line — inside the one document.

  `document_contents/1` is the strip at the top of a document that lists its
  sections, each label a link to its section.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  @doc """
  One section of a document, headed like a window.

  Accepts the attributes a `desktop_window/1` takes; the ones that only place a
  window on a desktop (`width`, `default_*`) are ignored.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :width, :integer, default: nil, doc: "ignored: a section is as wide as its document"
  attr :default_centered, :boolean, default: false, doc: "ignored"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true
  slot :inner_block, required: true
  slot :status, doc: "window_status_bar_field/1 elements, kept as the section's footer"

  @spec document_section(map()) :: Phoenix.LiveView.Rendered.t()
  def document_section(assigns) do
    ~H"""
    <section
      id={@id}
      class={classes(["document-section bg-surface shadow-retro-window p-[3px] scroll-mt-2", @class])}
      {@rest}
    >
      <div class="document-section__title flex items-center gap-retro-4 bg-title-bar px-retro-4 py-[2px] text-xs font-bold text-white">
        <span class="flex shrink-0" aria-hidden="true">{render_slot(@icon)}</span>
        <span class="truncate">{@title}</span>
      </div>
      <div class="document-section__body p-retro-8">
        {render_slot(@inner_block)}
      </div>
      <.window_status_bar :if={@status != []} class="document-section__status">
        {render_slot(@status)}
      </.window_status_bar>
    </section>
    """
  end

  @doc """
  The list of a document's sections, each a link to it. `sections` are the
  `%{id, label, icon}` maps a page describes itself with.
  """
  attr :sections, :list, required: true
  attr :class, :any, default: nil

  @spec document_contents(map()) :: Phoenix.LiveView.Rendered.t()
  def document_contents(assigns) do
    ~H"""
    <nav
      :if={length(@sections) > 1}
      class={classes(["document-contents flex flex-wrap gap-retro-4 text-xs", @class])}
      aria-label={dgettext("landing", "On this page")}
    >
      <a
        :for={section <- @sections}
        href={"#" <> section.id}
        data-testid={"document-contents-" <> section.id}
        class="document-contents__link inline-flex items-center gap-1 px-retro-4 py-[2px] shadow-retro-raised bg-surface text-text no-underline hover:underline"
      >
        {apply(RetroHexChatWeb.Icons, section.icon, [%{class: "h-4 w-4 shrink-0"}])}
        <span>{section.label}</span>
      </a>
    </nav>
    """
  end
end
