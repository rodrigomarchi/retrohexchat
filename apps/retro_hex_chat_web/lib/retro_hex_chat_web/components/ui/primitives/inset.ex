defmodule RetroHexChatWeb.Components.UI.Inset do
  @moduledoc """
  A sunken panel, the way Win98 framed a field or a picture: the frame a
  card in the conversation sits in, and the one a page of the site sets its
  illustrations and notes in.

  ## Usage

      <.inset class="p-2">notes</.inset>
      <.inset tone="screen" class="p-1"><img src={@shot} /></.inset>
  """
  use RetroHexChatWeb.Component

  attr :tone, :string,
    values: ~w(paper canvas diagram screen),
    default: "paper",
    doc:
      "what the panel holds: `paper` text, cards and tables, a `canvas` mockup of the chat, " <>
        "a `diagram`, or a `screen` of the running app"

  attr :class, :any, default: nil, doc: "its padding and spacing"
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a sunken panel in the given tone."
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
end
