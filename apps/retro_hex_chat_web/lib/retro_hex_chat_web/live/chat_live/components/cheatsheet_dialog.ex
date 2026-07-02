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
  end

  @spec format_binding(map() | nil) :: String.t()
  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)
end
