defmodule RetroHexChatWeb.Components.UI.AccountDialog do
  @moduledoc """
  Win98-style Account panel: nickname registration, identification, dropping a
  registration and ghosting a stale session.

  Register and Identify are one form with a mode switch, not two — the nickname
  is either registered (identify) or not (register), never both.

  The banner draws the identity card in the state the session is actually in,
  so the answer to "am I logged in" is a picture before it is a sentence, and
  each region names the NickServ command that does the same thing.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc "Renders the Account panel: register/identify, drop registration, ghost session."
  attr :id, :string, required: true
  attr :nickname, :string, required: true
  attr :account_state, :atom, default: :guest, values: [:guest, :identified, :away]
  attr :registered, :boolean, default: false
  attr :identified, :boolean, default: false
  attr :auth_valid, :boolean, default: false
  attr :auth_password, :string, default: ""
  attr :auth_confirm, :string, default: ""
  attr :error_message, :string, default: nil
  attr :ghost_error, :string, default: nil

  @spec account_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def account_panel(assigns) do
    assigns =
      assigns
      |> assign(:status_label, account_state_label(assigns.account_state))
      |> assign(:card_state, card_state(assigns.identified, assigns.registered))
      |> assign(:form_mode, if(assigns.registered, do: "identify", else: "register"))

    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="account-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="acct-dialog flex h-full min-h-0 flex-col overflow-y-auto"
        >
          <div class="space-y-retro-8">
            <.dialog_banner heading={banner_heading(@card_state)} data-testid="account-banner">
              <:art>
                <Diagrams.diagram_account_card nickname={@nickname} state={@card_state} />
              </:art>
              <:glyph><Icons.icon_status_user class="h-8 w-8" /></:glyph>
              {banner_prose(@card_state)}
            </.dialog_banner>

            <div class="acct-status-grid grid grid-cols-[90px_1fr] gap-retro-4 text-xs">
              <span class="font-bold">{dgettext("dialogs", "Nickname:")}</span>
              <span class="acct-value">{@nickname}</span>
              <span class="font-bold">{dgettext("dialogs", "Status:")}</span>
              <span class="acct-value flex flex-wrap items-center gap-retro-4">
                {@status_label}
                <.badge variant={badge_variant(@card_state)}>
                  {if @registered,
                    do: dgettext("dialogs", "registered"),
                    else: dgettext("dialogs", "unregistered")}
                </.badge>
              </span>
            </div>

            <p :if={@error_message} class="text-xs text-error" data-testid="account-error">
              {@error_message}
            </p>

            <div
              :if={@identified}
              class="acct-notice flex items-center gap-retro-4 text-xs"
              data-testid="account-identified-state"
            >
              <Icons.icon_checkmark class="w-4 h-4" />
              <span>{dgettext("dialogs", "You are identified with NickServ.")}</span>
            </div>

            <form
              :if={!@identified}
              phx-change="account_auth_change"
              phx-submit="account_register_submit"
            >
              <input type="hidden" name="mode" value={@form_mode} />

              <.dialog_section
                legend={
                  if @registered,
                    do: dgettext("dialogs", "Identify (log in)"),
                    else: dgettext("dialogs", "Register this nickname")
                }
                description={
                  if @registered,
                    do:
                      dgettext(
                        "dialogs",
                        "This nickname is registered. Enter its NickServ password to prove it is yours — until you do, anyone can take it when you disconnect."
                      ),
                    else:
                      dgettext(
                        "dialogs",
                        "Claims your current nickname with a NickServ password, so nobody else can use it while you are away."
                      )
                }
                command={
                  if @registered,
                    do: "/ns identify <password>",
                    else: "/ns register <password>"
                }
                data-testid={
                  if @registered, do: "account-identify-only", else: "account-register-only"
                }
              >
                <:icon><Icons.icon_lock class="h-4 w-4" /></:icon>

                <div class="acct-field space-y-retro-4">
                  <label class="text-xs font-bold" for="account-password">
                    {dgettext("dialogs", "Password:")}
                  </label>
                  <.input
                    id="account-password"
                    name="password"
                    type="password"
                    value={@auth_password}
                    autocomplete="current-password"
                    class="text-xs h-7"
                    data-testid="account-password"
                  />
                </div>

                <div :if={!@registered} class="acct-field mt-retro-6 space-y-retro-4">
                  <label class="text-xs font-bold" for="account-confirm">
                    {dgettext("dialogs", "Confirm:")}
                  </label>
                  <.input
                    id="account-confirm"
                    name="confirm"
                    type="password"
                    value={@auth_confirm}
                    autocomplete="new-password"
                    class="text-xs h-7"
                    data-testid="account-confirm"
                  />
                </div>

                <div class="acct-action-row mt-retro-6 flex justify-end gap-retro-4">
                  <.button type="submit" size="sm" disabled={!@auth_valid} class="acct-action-button">
                    <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                    {if @form_mode == "register",
                      do: dgettext("dialogs", "Register"),
                      else: dgettext("dialogs", "Identify")}
                  </.button>
                </div>
              </.dialog_section>
            </form>

            <form :if={@registered} phx-submit="account_drop_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Drop registration")}
                description={
                  dgettext(
                    "dialogs",
                    "Deletes this nickname registration after you confirm with its password. The nickname stays yours only until you disconnect."
                  )
                }
                command="/ns drop <password>"
                data-testid="account-drop-registration"
              >
                <:icon><Icons.icon_trash class="h-4 w-4" /></:icon>

                <div class="acct-field space-y-retro-4">
                  <label class="text-xs font-bold" for="account-drop-password">
                    {dgettext("dialogs", "Password:")}
                  </label>
                  <.input
                    id="account-drop-password"
                    name="password"
                    type="password"
                    autocomplete="current-password"
                    class="text-xs h-7"
                    data-testid="account-drop-password"
                  />
                </div>

                <div class="acct-action-row mt-retro-6 flex justify-end">
                  <.button type="submit" size="sm" variant="destructive" class="acct-action-button">
                    <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Drop Registration")}
                  </.button>
                </div>
              </.dialog_section>
            </form>

            <form phx-submit="account_ghost_submit">
              <.dialog_section
                legend={dgettext("dialogs", "Ghost session")}
                description={
                  dgettext(
                    "dialogs",
                    "Disconnects a stale session that is still holding a registered nickname, so you can take the nickname back."
                  )
                }
                command="/ns ghost <nickname> <password>"
                data-testid="account-ghost-session"
              >
                <:icon><Icons.icon_btn_disconnect class="h-4 w-4" /></:icon>

                <div class="acct-field space-y-retro-4">
                  <label class="text-xs font-bold" for="account-ghost-nickname">
                    {dgettext("dialogs", "Nickname:")}
                  </label>
                  <.input
                    id="account-ghost-nickname"
                    name="nickname"
                    maxlength="16"
                    class="text-xs h-7"
                    data-testid="account-ghost-nickname"
                  />
                </div>

                <div class="acct-field mt-retro-6 space-y-retro-4">
                  <label class="text-xs font-bold" for="account-ghost-password">
                    {dgettext("dialogs", "Password:")}
                  </label>
                  <.input
                    id="account-ghost-password"
                    name="password"
                    type="password"
                    autocomplete="current-password"
                    class="text-xs h-7"
                    data-testid="account-ghost-password"
                  />
                </div>

                <p
                  :if={@ghost_error}
                  class="mt-retro-6 text-xs text-error"
                  data-testid="account-ghost-error"
                >
                  {@ghost_error}
                </p>

                <div class="acct-action-row mt-retro-6 flex justify-end">
                  <.button type="submit" size="sm" variant="outline" class="acct-action-button">
                    <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Ghost Session")}
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

  @spec card_state(boolean(), boolean()) :: :guest | :registered | :identified
  defp card_state(true, _registered), do: :identified
  defp card_state(false, true), do: :registered
  defp card_state(false, false), do: :guest

  @spec badge_variant(atom()) :: String.t()
  defp badge_variant(:identified), do: "success"
  defp badge_variant(:registered), do: "warning"
  defp badge_variant(_), do: "secondary"

  @spec banner_heading(atom()) :: String.t()
  defp banner_heading(:identified), do: dgettext("dialogs", "This nickname is yours")
  defp banner_heading(:registered), do: dgettext("dialogs", "This nickname is taken")
  defp banner_heading(_), do: dgettext("dialogs", "This nickname is unclaimed")

  @spec banner_prose(atom()) :: String.t()
  defp banner_prose(:identified) do
    dgettext(
      "dialogs",
      "NickServ recognises this session, so the nickname is held for you and channel access lists that name it apply."
    )
  end

  defp banner_prose(:registered) do
    dgettext(
      "dialogs",
      "The nickname is registered but this session has not proved it owns it. Identify to hold it and to use the access it was granted."
    )
  end

  defp banner_prose(_) do
    dgettext(
      "dialogs",
      "Anyone can use this nickname once you disconnect. Register it to keep it, and to be recognised in channels that grant access by name."
    )
  end

  @spec account_state_label(atom()) :: String.t()
  defp account_state_label(:away), do: dgettext("dialogs", "Away")
  defp account_state_label(:identified), do: dgettext("dialogs", "Identified")
  defp account_state_label(_), do: dgettext("dialogs", "Guest")
end
