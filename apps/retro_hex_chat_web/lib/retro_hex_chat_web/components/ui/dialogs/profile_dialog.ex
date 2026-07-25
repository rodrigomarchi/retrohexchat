defmodule RetroHexChatWeb.Components.UI.ProfileDialog do
  @moduledoc """
  Win98-style Profile panel: change your nickname and edit the bio shown in
  `/whois`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc "Renders the Profile panel: nickname change and bio editor."
  attr :id, :string, required: true
  attr :nickname, :string, required: true
  attr :nick_error, :string, default: nil
  attr :bio, :string, default: ""
  attr :bio_warning, :string, default: nil

  @spec profile_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def profile_panel(assigns) do
    assigns = assign(assigns, :bio_count, String.length(assigns.bio || ""))

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
          <div class="space-y-retro-10">
            <form phx-submit="profile_change_nick_submit" class="space-y-retro-4">
              <label class="text-xs font-bold" for="profile-new-nick">
                {dgettext("dialogs", "Change nickname:")}
              </label>
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
              <p :if={@nick_error} class="text-xs text-error" data-testid="profile-nick-error">
                {@nick_error}
              </p>
            </form>

            <form
              phx-change="profile_bio_change"
              phx-submit="profile_bio_submit"
              class="space-y-retro-4"
            >
              <label class="acct-label text-xs font-bold" for="profile-bio">
                {dgettext("dialogs", "Bio (about me) — shown in /whois, max 200 chars")}
              </label>
              <.textarea
                id="profile-bio"
                name="bio"
                value={@bio}
                maxlength="200"
                class="acct-textarea min-h-[90px] resize-none"
                data-testid="profile-bio"
              />
              <p :if={@bio_warning} class="text-xs text-error" data-testid="profile-bio-warning">
                {@bio_warning}
              </p>
              <div class="acct-action-footer flex items-center justify-between gap-retro-4">
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
            </form>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end
end
