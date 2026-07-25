defmodule RetroHexChatWeb.Components.UI.AdminConsoleDialog do
  @moduledoc """
  Admin Console window — a batch command runner.

  A terminal for provisioning: paste several slash commands, one per line, and
  they run in order against a privileged context. Everything the other admin
  windows do with forms can be done here as a script, which is what makes it
  worth keeping alongside them.

  Output is a transcript, not a snapshot: each line echoes the command and its
  answer, green or red, until cleared.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :results, :list, default: []
  attr :on_run, :any, default: nil
  attr :on_clear, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_console_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-lg">
      <.dialog_header id={@id} title={dgettext("dialogs", "Admin Console")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_admin_console class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_console_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :results, :list, default: []
  attr :on_run, :any, default: nil
  attr :on_clear, :any, default: nil

  @spec admin_console_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-console-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <div
            class="shadow-retro-sunken bg-black text-green-400 font-mono text-xs p-retro-8 h-[240px] overflow-y-auto"
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
              <span>{Map.get(result, :message, "")}</span>
            </div>
            <div :if={@results == []} class="text-muted-foreground">
              {dgettext(
                "dialogs",
                "Type a command and press Enter. Type \"help\" for available commands."
              )}
            </div>
          </div>

          <form
            id="admin-console-form"
            phx-submit={@on_run}
            phx-target={@target}
            class="flex gap-retro-4"
          >
            <span class="text-sm font-mono font-bold shrink-0 self-start mt-retro-4">&gt;</span>
            <textarea
              id="admin-console-input"
              name="input"
              placeholder={dgettext("dialogs", "Enter admin command(s)... (one per line)")}
              class="flex-1 font-mono text-sm shadow-retro-sunken bg-white px-retro-4 py-retro-2 resize-y min-h-[28px] h-[56px]"
              autocomplete="off"
              rows="2"
            />
            <.button type="submit" size="sm" class="self-end">
              <:icon><Icons.icon_btn_play class="w-[14px] h-[14px]" /></:icon>
              {dgettext("dialogs", "Run")}
            </.button>
          </form>
        </div>
      </div>

      <div class="flex justify-end">
        <.button type="button" variant="outline" phx-click={@on_clear} phx-target={@target}>
          <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Clear")}
        </.button>
      </div>
    </div>
    """
  end
end
