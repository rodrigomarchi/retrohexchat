defmodule RetroHexChatWeb.Components.UI.UserModesDialog do
  @moduledoc """
  Win98-style User Modes panel: the IRC user modes that apply to your own
  connection. Currently `+w` (wallops); this is where further umodes land.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @doc "Renders the User Modes panel."
  attr :id, :string, required: true
  attr :wallops_enabled, :boolean, default: false

  @spec user_modes_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def user_modes_panel(assigns) do
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
          <form phx-submit="user_modes_submit" class="space-y-retro-8">
            <label class="acct-check-row flex items-start gap-retro-4 text-xs">
              <.checkbox name="wallops" value={@wallops_enabled} />
              <span>
                <span class="font-bold">{dgettext("dialogs", "Receive wallops (+w)")}</span>
                <span class="block text-muted-foreground">
                  {dgettext("dialogs", "Operator broadcast messages")}
                </span>
              </span>
            </label>
            <div class="acct-action-row flex justify-end">
              <.button type="submit" size="sm" class="acct-action-button">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Apply")}
              </.button>
            </div>
          </form>
        </div>
      </.focus_wrap>
    </div>
    """
  end
end
