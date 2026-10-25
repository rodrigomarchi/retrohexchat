defmodule RetroHexChatWeb.ChatLive.RegisteredWindow do
  @moduledoc """
  A desktop window drawn entirely from its `WindowRegistry` entry.

  For a window whose island needs nothing but the session, the entry already
  says everything: title, icon, geometry, when it renders (open, or admin and
  open) and which island it holds. The desktop template writes one line per
  such window; a window whose island takes more assigns keeps its own block.
  """

  use Phoenix.Component

  import RetroHexChatWeb.Components.UI.Desktop, only: [desktop_window: 1]

  alias RetroHexChatWeb.ChatLive.{ChatContext, WindowRegistry}

  attr :id, :string, required: true
  attr :session, :map, required: true
  attr :open_windows, :any, required: true

  @spec registered_window(map()) :: Phoenix.LiveView.Rendered.t()
  def registered_window(assigns) do
    window = WindowRegistry.fetch(assigns.id)

    unless window && window.island do
      raise ArgumentError, "#{inspect(assigns.id)} is not a registered window with an island"
    end

    assigns = assign(assigns, island: window.island, shown?: shown?(window, assigns))

    ~H"""
    <.desktop_window
      :if={@shown?}
      {WindowRegistry.attrs(@id)}
      body_class="flex min-h-0 flex-col p-2"
      data-testid={"#{@id}-window"}
    >
      <.live_component module={@island} id={@island.id()} session={@session} />
    </.desktop_window>
    """
  end

  defp shown?(%{render_when: :open, id: id}, assigns), do: id in assigns.open_windows

  defp shown?(%{render_when: :admin, id: id}, assigns),
    do: ChatContext.admin?(assigns.session) and id in assigns.open_windows
end
