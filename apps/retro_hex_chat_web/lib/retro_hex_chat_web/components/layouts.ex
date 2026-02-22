defmodule RetroHexChatWeb.Layouts do
  @moduledoc """
  Layout components for RetroHexChat.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Icons

  embed_templates "layouts/*"

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
