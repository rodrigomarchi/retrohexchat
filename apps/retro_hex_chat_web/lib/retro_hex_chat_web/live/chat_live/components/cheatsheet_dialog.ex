defmodule RetroHexChatWeb.ChatLive.Components.CheatsheetDialog do
  @moduledoc """
  The keyboard-shortcuts Cheatsheet dialog.

  The cheatsheet content is fully static (derived from `KeyBindings.defaults/0`),
  so the bindings are computed once in `mount/1` rather than on every parent
  render.

  `cheatsheet_visible` is Escape-managed in `keyboard_events.ex`, so the parent
  keeps it and passes it through as `visible`. Toggling (open/close, including the
  footer Close button) is handled by the parent's `toggle_cheatsheet` event; there
  is no component-owned draft state.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.CheatsheetDialog

  alias RetroHexChat.Chat.KeyBindings

  @id "cheatsheet-dialog"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, visible: false, bindings: cheatsheet_bindings())}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, assign(socket, visible: Map.get(assigns, :visible, socket.assigns.visible))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.cheatsheet_dialog
        id={@id}
        show={@visible}
        bindings={@bindings}
        on_close="toggle_cheatsheet"
      />
    </div>
    """
  end

  @spec cheatsheet_bindings() :: [map()]
  defp cheatsheet_bindings do
    KeyBindings.defaults()
    |> KeyBindings.categories()
    |> Enum.map(fn {category, entries} ->
      %{
        category: KeyBindings.category_label(category),
        items:
          Enum.map(entries, fn entry ->
            %{
              action: entry.label,
              keys: format_binding(entry.binding),
              description: entry.description
            }
          end)
      }
    end)
  end

  @spec format_binding(map() | nil) :: String.t()
  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)
end
