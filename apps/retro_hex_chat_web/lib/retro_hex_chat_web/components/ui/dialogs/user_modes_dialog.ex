defmodule RetroHexChatWeb.Components.UI.UserModesDialog do
  @moduledoc """
  Win98-style User Modes panel: the IRC user modes that apply to your own
  connection. Currently `+w` (wallops); this is where further umodes land.

  The banner draws the Status window, because a user mode is invisible until
  something arrives because of it — and with the mode off, the miniature is
  the empty window that is the whole point of leaving it off.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Fieldset

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc "Renders the User Modes panel."
  attr :id, :string, required: true
  attr :wallops_enabled, :boolean, default: false

  @spec user_modes_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def user_modes_panel(assigns) do
    assigns = assign(assigns, :status_lines, status_lines(assigns.wallops_enabled))

    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="user-modes-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="acct-dialog flex h-full min-h-0 flex-col overflow-y-auto"
        >
          <div class="space-y-retro-8">
            <.dialog_banner heading={dgettext("dialogs", "What reaches your Status window")}>
              <:art>
                <Diagrams.diagram_dialog_preview
                  kind={:status}
                  title={dgettext("dialogs", "Status")}
                  lines={@status_lines}
                  label={
                    dgettext("dialogs", "A miniature of the Status window these modes deliver to")
                  }
                />
              </:art>
              <:glyph><Icons.icon_dialog_user_modes class="h-8 w-8" /></:glyph>
              {dgettext(
                "dialogs",
                "A user mode applies to your whole connection rather than to one channel, and what it lets through arrives in Status."
              )}
            </.dialog_banner>

            <form phx-submit="user_modes_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Modes")}
                description={
                  dgettext(
                    "dialogs",
                    "Wallops are the announcements operators send to the whole server — restarts, downtime, anything everybody needs at once."
                  )
                }
                command={command_syntax("umode")}
              >
                <:icon><Icons.icon_megaphone class="h-4 w-4" /></:icon>

                <label class="acct-check-row flex items-start gap-retro-4 text-xs">
                  <.checkbox name="wallops" value={@wallops_enabled} />
                  <span>
                    <span class="font-bold">{dgettext("dialogs", "Receive wallops (+w)")}</span>
                    <span class="block text-muted-foreground">
                      {dgettext("dialogs", "Operator broadcast messages")}
                    </span>
                  </span>
                </label>

                <div class="acct-action-row mt-retro-6 flex justify-end">
                  <.button type="submit" size="sm" class="acct-action-button">
                    <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Apply")}
                  </.button>
                </div>
              </.dialog_section>
            </form>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  @spec status_lines(boolean()) :: [map()]
  defp status_lines(false), do: []

  defp status_lines(true) do
    [
      %{text: "*** WALLOPS", tone: :danger},
      %{text: dgettext("dialogs", "Restarting in 5 minutes"), tone: :normal}
    ]
  end
end
