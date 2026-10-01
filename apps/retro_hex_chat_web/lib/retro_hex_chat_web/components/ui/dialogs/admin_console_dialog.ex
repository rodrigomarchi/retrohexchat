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
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :results, :list, default: []
  attr :dropped, :integer, default: 0, doc: "Lines the transcript discarded to stay bounded"
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
  attr :dropped, :integer, default: 0, doc: "Lines the transcript discarded to stay bounded"
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
      <.dialog_banner heading={dgettext("dialogs", "The commands behind every other window")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:composer}
            title={dgettext("dialogs", "Console")}
            lines={console_lines(@results)}
            label={
              dgettext("dialogs", "A miniature of the console, showing what a command printed back")
            }
          />
        </:art>
        <:glyph><Icons.icon_dialog_admin_console class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Every other admin window runs one of these commands for you. You can type the same command here. It does the same thing and prints the same answer, one command per line. The transcript keeps only the most recent lines."
        )}
      </.dialog_banner>

      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <div
            class="shadow-retro-sunken bg-black text-green-400 font-mono text-xs p-retro-8 h-[240px] overflow-y-auto"
            id="admin-console-output"
            data-testid="admin-console-output"
          >
            <%!-- The transcript keeps only the most recent lines; saying how
                  many scrolled off is the only record that they ran. --%>
            <div :if={@dropped > 0} class="adm-transcript-trimmed" data-testid="admin-console-trimmed">
              {dgettext("dialogs", "%{count} earlier lines were dropped", count: @dropped)}
            </div>

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
                "Every command starts with a slash. Type /admin with no arguments to list the privileged subcommands."
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

  # The last exchange: what was typed is drawn on the strip, what came back
  # above it.
  @spec console_lines(list()) :: [map()]
  defp console_lines([]), do: []

  defp console_lines(results) do
    last = List.last(results)

    [
      %{text: Map.get(last, :message) || "", tone: :system},
      %{text: Map.get(last, :line) || "", tone: :accent}
    ]
  end
end
