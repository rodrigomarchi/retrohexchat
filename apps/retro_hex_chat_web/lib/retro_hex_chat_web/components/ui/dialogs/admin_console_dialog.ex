defmodule RetroHexChatWeb.Components.UI.AdminConsoleDialog do
  @moduledoc """
  v2 Admin Console dialog — a command-line style admin interface.

  Uses v2 design system primitives (Dialog, Button, Input).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :results, :list, default: []
  attr :on_close, :any, default: nil

  @spec admin_console_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console_dialog(assigns) do
    ~H"""
    <div
      :if={@show}
      phx-window-keydown="close_admin_console"
      phx-key="Escape"
    >
      <.dialog id={@id} show={@show} class="max-w-lg">
        <.dialog_header id={@id} title="Admin Console">
          <:icon><Icons.icon_dialog_admin_console class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>
        <.dialog_body>
          <%!-- Output area --%>
          <div
            class="shadow-retro-sunken bg-black text-green-400 font-mono text-xs p-retro-8 h-[240px] overflow-y-auto mb-retro-8"
            id="admin-console-output"
            data-testid="admin-console-output"
          >
            <div
              :for={result <- @results}
              class={[
                "py-retro-2",
                if(Map.get(result, :status) == :error, do: "text-red-400", else: "text-green-400")
              ]}
            >
              <div :if={Map.get(result, :line)} class="text-yellow-400">
                &gt; {Map.get(result, :line, "")}
              </div>
              <span>
                {Map.get(result, :message, "")}
              </span>
            </div>
            <div :if={@results == []} class="text-muted-foreground">
              Type a command and press Enter. Type "help" for available commands.
            </div>
          </div>

          <%!-- Input --%>
          <form phx-submit="execute_admin_console" class="flex gap-retro-4">
            <span class="text-sm font-mono font-bold shrink-0 self-start mt-retro-4">&gt;</span>
            <textarea
              id="admin-console-input"
              name="input"
              placeholder="Enter admin command(s)... (one per line)"
              class="flex-1 font-mono text-sm shadow-retro-sunken bg-white px-retro-4 py-retro-2 resize-y min-h-[28px] h-[56px]"
              autocomplete="off"
              rows="2"
            />
            <.button type="submit" size="sm" class="self-end">
              <:icon><Icons.icon_btn_play class="w-[14px] h-[14px]" /></:icon>
              Run
            </.button>
          </form>
        </.dialog_body>
        <.dialog_footer>
          <.button type="button" variant="outline" phx-click="clear_admin_console">
            <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
            Clear
          </.button>
          <.button type="button" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            Close
          </.button>
        </.dialog_footer>
      </.dialog>
    </div>
    """
  end
end
