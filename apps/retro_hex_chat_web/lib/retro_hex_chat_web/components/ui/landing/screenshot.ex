defmodule RetroHexChatWeb.Components.UI.Landing.Screenshot do
  @moduledoc """
  A picture of the product on a public page: a game, a place of a Space.

  Always at its real size, so the page does not jump when it loads, and on
  black, which is what the edges of every capture are. The page's main picture
  is fetched first; every other one waits until it is scrolled to.

  A picture may come in a smaller copy too (`srcset`, with the `sizes` the page
  draws it at), so a grid of thumbnails does not download the full captures.
  """
  use RetroHexChatWeb.Component

  attr :src, :string, required: true
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :alt, :string, required: true, doc: "empty when a link beside it already names it"
  attr :main, :boolean, default: false, doc: "the page's own picture: fetched first"
  attr :srcset, :string, default: nil
  attr :sizes, :string, default: nil
  attr :class, :any, default: nil

  @spec screenshot(map()) :: Phoenix.LiveView.Rendered.t()
  def screenshot(assigns) do
    ~H"""
    <img
      src={@src}
      srcset={@srcset}
      sizes={@srcset && @sizes}
      width={@width}
      height={@height}
      alt={@alt}
      fetchpriority={if @main, do: "high"}
      loading={if not @main, do: "lazy"}
      decoding={if not @main, do: "async"}
      class={classes(["block h-auto w-full bg-black", @class])}
    />
    """
  end
end
