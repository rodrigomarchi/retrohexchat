defmodule RetroHexChatWeb.ChatLive.Components.CheatsheetDialog do
  @moduledoc """
  The keyboard-shortcuts Cheatsheet dialog.

  The cheatsheet content is fully static (derived from `KeyBindings.defaults/0`),
  so the bindings are computed once in `mount/1` rather than on every parent
  render.

  Mounted inside a server-managed desktop window (presence in the DOM means
  open; the window manager owns close). There is no component-owned draft state.
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
    {:ok, assign(socket, id: @id, bindings: cheatsheet_bindings())}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.cheatsheet_panel id={@id} bindings={@bindings} />
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
    |> Kernel.++([p2p_session_console_shortcuts()])
  end

  @spec format_binding(map() | nil) :: String.t()
  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)

  @spec p2p_session_console_shortcuts() :: map()
  defp p2p_session_console_shortcuts do
    %{
      category: dgettext("chat", "P2P Session Console"),
      items: [
        shortcut_item(
          dgettext("chat", "Toggle P2P Microphone"),
          %{key: "ArrowUp", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Mute, unmute, or enable your P2P microphone")
        ),
        shortcut_item(
          dgettext("chat", "Toggle P2P Camera"),
          %{key: "ArrowLeft", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Start, pause, or resume your P2P camera")
        ),
        shortcut_item(
          dgettext("chat", "Next P2P Layout"),
          %{key: "ArrowRight", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Cycle Auto, Focus, Split, Speaker and Compact layouts")
        ),
        shortcut_item(
          dgettext("chat", "Cycle P2P Self View"),
          %{key: "ArrowDown", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Move your self-view between tile, picture-in-picture and hidden")
        ),
        shortcut_item(
          dgettext("chat", "Toggle P2P Screen Share"),
          %{key: ".", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Start or stop screen sharing in the focused P2P Session Console")
        ),
        shortcut_item(
          dgettext("chat", "End P2P Call Media"),
          %{key: "q", modifiers: [:ctrl, :shift]},
          dgettext("chat", "Stop only the call media; the P2P session stays open")
        )
      ]
    }
  end

  @spec shortcut_item(String.t(), map(), String.t()) :: map()
  defp shortcut_item(action, binding, description) do
    %{action: action, keys: format_binding(binding), description: description}
  end
end
