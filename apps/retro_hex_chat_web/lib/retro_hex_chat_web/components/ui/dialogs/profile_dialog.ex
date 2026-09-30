defmodule RetroHexChatWeb.Components.UI.ProfileDialog do
  @moduledoc """
  Win98-style Profile panel: change your nickname and edit the bio shown in
  `/whois`.

  The banner draws the `/whois` card itself, because that is the only place
  either field is ever read — the dialog is an editor for a screen nobody
  sees while they are editing it.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Components.Diagrams.DialogPreview
  alias RetroHexChatWeb.Icons

  @doc "Renders the Profile panel: nickname change and bio editor."
  attr :id, :string, required: true
  attr :nickname, :string, required: true
  attr :nick_error, :string, default: nil
  attr :bio, :string, default: ""
  attr :bio_warning, :string, default: nil

  @spec profile_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def profile_panel(assigns) do
    assigns =
      assigns
      |> assign(:bio_count, String.length(assigns.bio || ""))
      |> assign(:whois_lines, whois_lines(assigns.nickname, assigns.bio))

    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="profile-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="acct-dialog flex h-full min-h-0 flex-col overflow-y-auto"
        >
          <div class="space-y-retro-8">
            <.dialog_banner heading={dgettext("dialogs", "How you look to other people")}>
              <:art>
                <Diagrams.diagram_dialog_preview
                  kind={:card}
                  title={dgettext("dialogs", "Whois")}
                  lines={@whois_lines}
                  label={dgettext("dialogs", "A miniature of the Whois card other people see")}
                />
              </:art>
              <:glyph><Icons.icon_dialog_profile class="h-8 w-8" /></:glyph>
              {dgettext(
                "dialogs",
                "Both of these show up when somebody runs Whois on you, and nowhere else. The nickname is also what channels grant access to, so changing it can cost you the access the old one had."
              )}
            </.dialog_banner>

            <form phx-submit="profile_change_nick_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Nickname")}
                description={
                  dgettext(
                    "dialogs",
                    "Up to 16 characters. Taking a registered nickname you cannot identify for will be refused."
                  )
                }
                command={command_syntax("nick")}
              >
                <:icon><Icons.icon_dialog_nick class="h-4 w-4" /></:icon>

                <div class="acct-inline-field-row flex gap-retro-4">
                  <.input
                    id="profile-new-nick"
                    name="nickname"
                    value={@nickname}
                    maxlength="16"
                    class="acct-flex-input text-xs h-7"
                    data-testid="profile-new-nick"
                  />
                  <.button type="submit" size="sm" class="acct-action-button">
                    <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Change")}
                  </.button>
                </div>
                <p
                  :if={@nick_error}
                  class="mt-retro-4 text-xs text-error"
                  data-testid="profile-nick-error"
                >
                  {@nick_error}
                </p>
              </.dialog_section>
            </form>

            <form phx-change="profile_bio_change" phx-submit="profile_bio_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Bio")}
                description={
                  dgettext(
                    "dialogs",
                    "A couple of lines about you, up to 200 characters. Everyone can read it; nobody is shown it unless they ask."
                  )
                }
                command={command_syntax("bio")}
              >
                <:icon><Icons.icon_notepad class="h-4 w-4" /></:icon>

                <.textarea
                  id="profile-bio"
                  name="bio"
                  value={@bio}
                  maxlength="200"
                  class="acct-textarea min-h-[90px] resize-none"
                  data-testid="profile-bio"
                />
                <p
                  :if={@bio_warning}
                  class="mt-retro-4 text-xs text-error"
                  data-testid="profile-bio-warning"
                >
                  {@bio_warning}
                </p>
                <div class="acct-action-footer mt-retro-6 flex items-center justify-between gap-retro-4">
                  <span class="text-xs text-muted-foreground">{@bio_count} / 200</span>
                  <div class="acct-action-group flex gap-retro-4">
                    <.button type="submit" size="sm" class="acct-action-button">
                      <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                      {dgettext("dialogs", "Save Bio")}
                    </.button>
                    <.button
                      type="button"
                      size="sm"
                      variant="outline"
                      phx-click="profile_clear_bio"
                      class="acct-action-button"
                    >
                      <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                      {dgettext("dialogs", "Clear Bio")}
                    </.button>
                  </div>
                </div>
              </.dialog_section>
            </form>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  @spec whois_lines(String.t(), String.t() | nil) :: [map()]
  defp whois_lines(nickname, bio) do
    [%{text: nickname, tone: :accent}] ++ DialogPreview.wrap_lines(bio, :normal, 23)
  end
end
