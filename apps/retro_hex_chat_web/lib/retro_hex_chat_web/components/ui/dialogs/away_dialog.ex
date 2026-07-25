defmodule RetroHexChatWeb.Components.UI.AwayDialog do
  @moduledoc """
  Win98-style Away panel: mark yourself away and set the message others see in
  `/whois`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc "Renders the Away panel: away toggle and away message."
  attr :id, :string, required: true
  attr :away, :boolean, default: false
  attr :away_message, :string, default: ""

  @spec away_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def away_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="away-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="acct-dialog flex h-full min-h-0 flex-col overflow-y-auto"
        >
          <form phx-submit="away_submit" class="space-y-retro-8">
            <label class="acct-check-row flex items-center gap-retro-4 text-xs">
              <.checkbox name="away" value={@away} />
              {dgettext("dialogs", "I'm away")}
            </label>
            <div class="acct-field space-y-retro-4">
              <label class="text-xs font-bold" for="away-message">
                {dgettext("dialogs", "Away message:")}
              </label>
              <.textarea
                id="away-message"
                name="away_message"
                value={@away_message}
                placeholder={dgettext("dialogs", "Gone to lunch")}
                class="acct-textarea acct-away-message min-h-[64px] resize-none text-xs"
                data-testid="away-message"
              />
              <p class="text-xs text-muted-foreground">
                {dgettext("dialogs", "Shown to others via /whois.")}
              </p>
            </div>
            <div class="acct-action-row flex justify-end gap-retro-4">
              <.button type="submit" size="sm" class="acct-action-button">
                <:icon><Icons.icon_btn_dnd_active class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Set Away")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="away_clear"
                class="acct-action-button"
              >
                <:icon><Icons.icon_btn_dnd class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Clear Away")}
              </.button>
            </div>
          </form>
        </div>
      </.focus_wrap>
    </div>
    """
  end
end
