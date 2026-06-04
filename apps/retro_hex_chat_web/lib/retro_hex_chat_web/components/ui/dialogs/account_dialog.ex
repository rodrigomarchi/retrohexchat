defmodule RetroHexChatWeb.Components.UI.AccountDialog do
  @moduledoc """
  Win98-style Account dialog for nickname registration, profile, presence, and user modes.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.RadioGroup
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @doc "Renders the Account dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :nickname, :string, required: true
  attr :account_state, :atom, default: :guest, values: [:guest, :identified, :away]
  attr :registered, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :active_tab, :string, default: "register"
  attr :auth_mode, :string, default: "register"
  attr :bio, :string, default: ""
  attr :away, :boolean, default: false
  attr :away_message, :string, default: ""
  attr :wallops_enabled, :boolean, default: false
  attr :error_message, :string, default: nil
  attr :on_close, :any, default: nil

  @spec account_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def account_dialog(assigns) do
    assigns =
      assigns
      |> assign(:bio_count, String.length(assigns.bio || ""))
      |> assign(:status_label, account_state_label(assigns.account_state))

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_close} class="md:max-w-xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Account")} on_close={@on_close}>
        <:icon><Icons.icon_status_user class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <div data-testid="account-dialog">
          <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
            <.tabs_list class="px-0 pt-0">
              <.tabs_trigger builder={builder} value="register">
                <:icon><Icons.icon_lock class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Register/Login")}
              </.tabs_trigger>
              <.tabs_trigger builder={builder} value="profile">
                <:icon><Icons.icon_status_user class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Profile")}
              </.tabs_trigger>
              <.tabs_trigger builder={builder} value="presence">
                <:icon><Icons.icon_btn_dnd class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "Presence")}
              </.tabs_trigger>
              <.tabs_trigger builder={builder} value="modes">
                <:icon><Icons.icon_tab_status class="w-4 h-4" /></:icon>
                {dgettext("dialogs", "User Modes")}
              </.tabs_trigger>
            </.tabs_list>

            <.tabs_content builder={builder} value="register">
              <.register_tab
                nickname={@nickname}
                status_label={@status_label}
                registered={@registered}
                identified={@identified}
                auth_mode={@auth_mode}
                error_message={@error_message}
              />
            </.tabs_content>

            <.tabs_content builder={builder} value="profile">
              <.profile_tab nickname={@nickname} bio={@bio || ""} bio_count={@bio_count} />
            </.tabs_content>

            <.tabs_content builder={builder} value="presence">
              <.presence_tab away={@away} away_message={@away_message || ""} />
            </.tabs_content>

            <.tabs_content builder={builder} value="modes">
              <.modes_tab wallops_enabled={@wallops_enabled} />
            </.tabs_content>
          </.tabs>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button type="button" variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  attr :nickname, :string, required: true
  attr :status_label, :string, required: true
  attr :registered, :boolean, required: true
  attr :identified, :boolean, required: true
  attr :auth_mode, :string, required: true
  attr :error_message, :string, default: nil

  defp register_tab(assigns) do
    ~H"""
    <form phx-submit="account_register_submit" class="space-y-retro-8">
      <div class="grid grid-cols-[90px_1fr] gap-retro-4 text-xs">
        <span class="font-bold">{dgettext("dialogs", "Nickname:")}</span>
        <span>{@nickname}</span>
        <span class="font-bold">{dgettext("dialogs", "Status:")}</span>
        <span>
          {@status_label}
          <span class="text-muted-foreground">
            ({if @registered,
              do: dgettext("dialogs", "registered"),
              else: dgettext("dialogs", "unregistered")})
          </span>
        </span>
      </div>

      <.radio_group :let={radio} name="mode" value={@auth_mode} class="space-y-retro-4">
        <label class="flex items-center gap-retro-4 text-xs">
          <.radio_group_item
            builder={radio}
            value="register"
            data-testid="account-register-mode"
          />
          {dgettext("dialogs", "Register this nickname")}
        </label>
        <label class="flex items-center gap-retro-4 text-xs">
          <.radio_group_item
            builder={radio}
            value="identify"
            data-testid="account-identify-mode"
          />
          {dgettext("dialogs", "Identify (log in)")}
        </label>
      </.radio_group>

      <div class="space-y-retro-4">
        <label class="text-xs font-bold" for="account-password">
          {dgettext("dialogs", "Password:")}
        </label>
        <.input
          id="account-password"
          name="password"
          type="password"
          autocomplete="current-password"
          class="text-xs h-7"
          data-testid="account-password"
        />
      </div>

      <div :if={@auth_mode == "register"} class="space-y-retro-4">
        <label class="text-xs font-bold" for="account-confirm">
          {dgettext("dialogs", "Confirm:")}
        </label>
        <.input
          id="account-confirm"
          name="confirm"
          type="password"
          autocomplete="new-password"
          class="text-xs h-7"
          data-testid="account-confirm"
        />
      </div>

      <p :if={@error_message} class="text-xs text-error" data-testid="account-error">
        {@error_message}
      </p>

      <div class="flex justify-end gap-retro-4">
        <.button type="submit" size="sm">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {if @auth_mode == "register",
            do: dgettext("dialogs", "Register"),
            else: dgettext("dialogs", "Identify")}
        </.button>
      </div>
    </form>
    """
  end

  attr :nickname, :string, required: true
  attr :bio, :string, required: true
  attr :bio_count, :integer, required: true

  defp profile_tab(assigns) do
    ~H"""
    <div class="space-y-retro-10">
      <form phx-submit="account_change_nick_submit" class="space-y-retro-4">
        <label class="text-xs font-bold" for="account-new-nick">
          {dgettext("dialogs", "Change nickname:")}
        </label>
        <div class="flex gap-retro-4">
          <.input
            id="account-new-nick"
            name="nickname"
            value={@nickname}
            maxlength="16"
            class="text-xs h-7"
            data-testid="account-new-nick"
          />
          <.button type="submit" size="sm">
            <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Change")}
          </.button>
        </div>
      </form>

      <form phx-submit="account_profile_submit" class="space-y-retro-4">
        <label class="text-xs font-bold" for="account-bio">
          {dgettext("dialogs", "Bio (about me) — shown in /whois, max 200 chars")}
        </label>
        <.textarea
          id="account-bio"
          name="bio"
          value={@bio}
          maxlength="200"
          class="min-h-[90px] resize-none"
          data-testid="account-bio"
        />
        <div class="flex items-center justify-between gap-retro-4">
          <span class="text-xs text-muted-foreground">{@bio_count} / 200</span>
          <div class="flex gap-retro-4">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Save Bio")}
            </.button>
            <.button type="button" size="sm" variant="outline" phx-click="account_clear_bio">
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Clear Bio")}
            </.button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  attr :away, :boolean, required: true
  attr :away_message, :string, required: true

  defp presence_tab(assigns) do
    ~H"""
    <form phx-submit="account_presence_submit" class="space-y-retro-8">
      <label class="flex items-center gap-retro-4 text-xs">
        <.checkbox name="away" value={@away} />
        {dgettext("dialogs", "I'm away")}
      </label>
      <div class="space-y-retro-4">
        <label class="text-xs font-bold" for="account-away-message">
          {dgettext("dialogs", "Away message:")}
        </label>
        <.input
          id="account-away-message"
          name="away_message"
          value={@away_message}
          placeholder={dgettext("dialogs", "Gone to lunch")}
          class="text-xs h-7"
          data-testid="account-away-message"
        />
        <p class="text-xs text-muted-foreground">
          {dgettext("dialogs", "Shown to others via /whois.")}
        </p>
      </div>
      <div class="flex justify-end gap-retro-4">
        <.button type="submit" size="sm">
          <:icon><Icons.icon_btn_dnd_active class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Set Away")}
        </.button>
        <.button type="button" size="sm" variant="outline" phx-click="account_clear_away">
          <:icon><Icons.icon_btn_dnd class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Clear Away")}
        </.button>
      </div>
    </form>
    """
  end

  attr :wallops_enabled, :boolean, required: true

  defp modes_tab(assigns) do
    ~H"""
    <form phx-submit="account_user_modes_submit" class="space-y-retro-8">
      <label class="flex items-start gap-retro-4 text-xs">
        <.checkbox name="wallops" value={@wallops_enabled} />
        <span>
          <span class="font-bold">{dgettext("dialogs", "Receive wallops (+w)")}</span>
          <span class="block text-muted-foreground">
            {dgettext("dialogs", "Operator broadcast messages")}
          </span>
        </span>
      </label>
      <div class="flex justify-end">
        <.button type="submit" size="sm">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Apply")}
        </.button>
      </div>
    </form>
    """
  end

  @spec account_state_label(atom()) :: String.t()
  defp account_state_label(:away), do: dgettext("dialogs", "Away")
  defp account_state_label(:identified), do: dgettext("dialogs", "Identified")
  defp account_state_label(_), do: dgettext("dialogs", "Guest")
end
