defmodule RetroHexChatWeb.Components.UI.AwayDialog do
  @moduledoc """
  Win98-style Away panel: mark yourself away and set the message others see in
  `/whois`.

  The banner draws the conversation on the other side — the person who
  messaged you and got the automatic reply — because that is who the setting
  is actually for.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc "Renders the Away panel: away toggle and away message."
  attr :id, :string, required: true
  attr :nickname, :string, default: ""
  attr :away, :boolean, default: false
  attr :away_message, :string, default: ""

  @spec away_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def away_panel(assigns) do
    assigns = assign(assigns, :reply_lines, reply_lines(assigns.away, assigns.away_message))

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
          <div class="space-y-retro-8">
            <.dialog_banner heading={banner_heading(@away)}>
              <:art>
                <Diagrams.diagram_dialog_preview
                  kind={:query}
                  title={if @nickname == "", do: dgettext("dialogs", "Query"), else: @nickname}
                  lines={@reply_lines}
                  label={
                    dgettext("dialogs", "A miniature of the reply somebody messaging you receives")
                  }
                />
              </:art>
              <:glyph><Icons.icon_dialog_away class="h-8 w-8" /></:glyph>
              {dgettext(
                "dialogs",
                "While you are away, anybody who messages you privately gets this back once, and your nickname is marked away in every channel you are in."
              )}
            </.dialog_banner>

            <form phx-submit="away_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Away")}
                description={
                  dgettext(
                    "dialogs",
                    "Leaving the message empty still marks you away — the reply just says so without a reason."
                  )
                }
                command={command_syntax("away")}
              >
                <:icon><Icons.icon_dialog_away class="h-4 w-4" /></:icon>

                <label class="acct-check-row flex items-center gap-retro-4 text-xs">
                  <.checkbox name="away" value={@away} />
                  {dgettext("dialogs", "I'm away")}
                </label>

                <div class="acct-field mt-retro-6 space-y-retro-4">
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
                </div>

                <div class="acct-action-row mt-retro-6 flex justify-end gap-retro-4">
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
              </.dialog_section>
            </form>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  @spec banner_heading(boolean()) :: String.t()
  defp banner_heading(true), do: dgettext("dialogs", "You are marked away")
  defp banner_heading(false), do: dgettext("dialogs", "You are here")

  # Away off means no automatic reply at all, so the miniature shows the
  # message arriving and nothing coming back.
  @spec reply_lines(boolean(), String.t() | nil) :: [map()]
  defp reply_lines(false, _message), do: [%{text: dgettext("dialogs", "hey, got a minute?")}]

  defp reply_lines(true, message) do
    [
      %{text: dgettext("dialogs", "hey, got a minute?")},
      %{text: system_line(dgettext("dialogs", "is away")), tone: :system}
    ] ++ message_line(message)
  end

  @spec message_line(String.t() | nil) :: [map()]
  defp message_line(message) when is_binary(message) do
    case String.trim(message) do
      "" -> []
      text -> [%{text: text, tone: :muted}]
    end
  end

  defp message_line(_), do: []

  # The chat's own marker for a line nobody typed. It is punctuation, not
  # prose: inside a msgid the engine reads it as list markup and mangles the
  # sentence after it, so it is prefixed here instead.
  @spec system_line(String.t()) :: String.t()
  defp system_line(text), do: "* " <> text
end
