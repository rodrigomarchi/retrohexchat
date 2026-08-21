defmodule RetroHexChatWeb.Layouts do
  @moduledoc """
  Layout components for RetroHexChat.
  """
  use RetroHexChatWeb, :html

  alias RetroHexChatWeb.Icons.Sprite

  embed_templates "layouts/*"

  @doc """
  The `<head>` links every surface shares, in the order the browser should act on them.

  Two of these earn their place by what they *don't* do. The icon sprite is not
  discoverable until the parser reaches the first `<use>`, deep in the body, so
  it is announced here and downloads alongside the stylesheet. And the web font
  arrives as `media="print"`, which the browser fetches without letting it hold
  up the first paint; the `onload` promotes it once it is there.
  """
  @spec head_assets(map()) :: Phoenix.LiveView.Rendered.t()
  def head_assets(assigns) do
    ~H"""
    <link rel="preload" as="image" type="image/svg+xml" href={Sprite.url()} />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;500;700&display=swap"
      rel="stylesheet"
      media="print"
      onload="this.media='all'"
    />
    <noscript>
      <link
        href="https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;500;700&display=swap"
        rel="stylesheet"
      />
    </noscript>
    """
  end

  @doc """
  Renders the app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    {render_slot(@inner_block)}
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          JS.show(to: ".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: "#client-error")
        }
        phx-connected={
          JS.hide(to: "#client-error") |> JS.set_attribute({"hidden", ""}, to: "#client-error")
        }
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          JS.show(to: ".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: "#server-error")
        }
        phx-connected={
          JS.hide(to: "#server-error") |> JS.set_attribute({"hidden", ""}, to: "#server-error")
        }
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>
    </div>
    """
  end
end
