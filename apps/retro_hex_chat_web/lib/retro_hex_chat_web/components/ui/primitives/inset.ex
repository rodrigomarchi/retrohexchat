defmodule RetroHexChatWeb.Components.UI.Inset do
  @moduledoc """
  A sunken panel, the way Win98 framed a field or a picture: the frame a page
  of the site sets its illustrations and notes in. A card in the conversation
  has no frame — that is `ChatCard`.

  Win98 has two of these, and so does this: the `field` bevel a text box
  wears (the default), and the deeper `sunken` one a status box or a group of
  controls sits in.

  ## Usage

      <.inset class="p-2">notes</.inset>
      <.inset tone="screen" class="p-1"><img src={@shot} /></.inset>
      <.inset bevel="sunken" tone="surface" as="section" class="p-2">...</.inset>
  """
  use RetroHexChatWeb.Component

  attr :bevel, :string,
    values: ~w(field sunken),
    default: "field",
    doc: "`field`, the bevel of a text box, or the deeper `sunken` one of a status box"

  attr :tone, :string,
    values: ~w(paper canvas diagram screen surface none),
    default: "paper",
    doc:
      "what the panel holds: `paper` text, cards and tables, a `canvas` mockup of the chat, " <>
        "a `diagram`, a `screen` of the running app, the window's own grey `surface`, " <>
        "or `none` to keep whatever is behind it"

  attr :as, :string, default: "div", doc: "the element, when the panel is a section of the page"
  attr :class, :any, default: nil, doc: "its padding and spacing"
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a sunken panel in the given bevel and tone."
  @spec inset(map()) :: Phoenix.LiveView.Rendered.t()
  def inset(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@as}
      class={[bevel_class(@bevel), tone_class(@tone), @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  defp bevel_class("field"), do: "shadow-retro-field"
  defp bevel_class("sunken"), do: "shadow-retro-sunken"

  defp tone_class("paper"), do: "bg-white"
  defp tone_class("canvas"), do: "bg-canvas-bg text-canvas-fg"
  defp tone_class("diagram"), do: "bg-diagram-bg"
  defp tone_class("screen"), do: "bg-black"
  defp tone_class("surface"), do: "bg-surface"
  defp tone_class("none"), do: nil
end
