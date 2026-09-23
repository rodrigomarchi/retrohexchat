defmodule RetroHexChatWeb.Components.UI.AccountDialog do
  @moduledoc """
  Win98-style Account panel: nickname registration, identification, dropping a
  registration and ghosting a stale session.

  Register and Identify are one form with a mode switch, not two — the nickname
  is either registered (identify) or not (register), never both.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

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
  attr :email_available, :boolean, default: false
  attr :email, :string, default: nil
  attr :email_confirmed, :boolean, default: false
  attr :email_draft, :string, default: ""
  attr :email_error, :string, default: nil
  attr :email_notice, :string, default: nil

  @spec account_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def account_panel(assigns) do
    assigns =
      assigns
      |> assign(:status_label, account_state_label(assigns.account_state))
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
            <div class="acct-status-grid grid grid-cols-[90px_1fr] gap-retro-4 text-xs">
              <span class="font-bold">{dgettext("dialogs", "Nickname:")}</span>
              <span class="acct-value">{@nickname}</span>
              <span class="font-bold">{dgettext("dialogs", "Status:")}</span>
              <span class="acct-value">
                {@status_label}
                <span class="text-muted-foreground">
                  ({if @registered,
                    do: dgettext("dialogs", "registered"),
                    else: dgettext("dialogs", "unregistered")})
                </span>
              </span>
            </div>

            <p :if={@error_message} class="text-xs text-error" data-testid="account-error">
              {@error_message}
            </p>

            <.account_email_section
              :if={@email_available and @identified}
              email={@email}
              email_confirmed={@email_confirmed}
              email_draft={@email_draft}
              email_error={@email_error}
              email_notice={@email_notice}
            />

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
              class="space-y-retro-8"
            >
              <input type="hidden" name="mode" value={@form_mode} />

              <div
                :if={!@registered}
                class="text-xs space-y-retro-2"
                data-testid="account-register-only"
              >
                <p class="font-bold">{dgettext("dialogs", "Register this nickname")}</p>
                <p class="text-muted-foreground">
                  {dgettext("dialogs", "Claims your current nickname with a NickServ password.")}
                </p>
              </div>

              <div
                :if={@registered}
                class="text-xs space-y-retro-2"
                data-testid="account-identify-only"
              >
                <p class="font-bold">{dgettext("dialogs", "Identify (log in)")}</p>
                <p class="text-muted-foreground">
                  {dgettext("dialogs", "This nickname is registered. Enter its NickServ password.")}
                </p>
              </div>

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

              <div :if={!@registered} class="acct-field space-y-retro-4">
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

              <div class="acct-action-row flex justify-end gap-retro-4">
                <.button type="submit" size="sm" disabled={!@auth_valid} class="acct-action-button">
                  <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                  {if @form_mode == "register",
                    do: dgettext("dialogs", "Register"),
                    else: dgettext("dialogs", "Identify")}
                </.button>
              </div>
            </form>

            <form
              :if={@registered}
              phx-submit="account_drop_submit"
              class="border-t border-border pt-retro-8 space-y-retro-6"
              data-testid="account-drop-registration"
            >
              <div class="text-xs space-y-retro-2">
                <p class="font-bold">{dgettext("dialogs", "Drop registration...")}</p>
                <p class="text-muted-foreground">
                  {dgettext(
                    "dialogs",
                    "Deletes this nickname registration after you confirm with its password."
                  )}
                </p>
              </div>

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

              <div class="acct-action-row flex justify-end">
                <.button type="submit" size="sm" variant="destructive" class="acct-action-button">
                  <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Drop Registration")}
                </.button>
              </div>
            </form>

            <details
              class="acct-details border-t border-border pt-retro-8 text-xs"
              data-testid="account-ghost-session"
            >
              <summary class="cursor-pointer font-bold">
                {dgettext("dialogs", "Ghost session...")}
              </summary>
              <form phx-submit="account_ghost_submit" class="mt-retro-8 space-y-retro-6">
                <p class="text-muted-foreground">
                  {dgettext(
                    "dialogs",
                    "Disconnect a stale session that is holding a registered nickname."
                  )}
                </p>

                <div class="acct-field space-y-retro-4">
                  <label class="font-bold" for="account-ghost-nickname">
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

                <div class="acct-field space-y-retro-4">
                  <label class="font-bold" for="account-ghost-password">
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

                <p :if={@ghost_error} class="text-xs text-error" data-testid="account-ghost-error">
                  {@ghost_error}
                </p>

                <div class="acct-action-row flex justify-end">
                  <.button type="submit" size="sm" variant="outline" class="acct-action-button">
                    <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Ghost Session")}
                  </.button>
                </div>
              </form>
            </details>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :email, :string, default: nil
  attr :email_confirmed, :boolean, default: false
  attr :email_draft, :string, default: ""
  attr :email_error, :string, default: nil
  attr :email_notice, :string, default: nil

  # Drawn only where there is mail to send and only to somebody who has proved
  # who they are: an address is the way back into an account, so offering to set
  # one before identifying would be offering to take the account.
  defp account_email_section(assigns) do
    ~H"""
    <div class="acct-field space-y-retro-4 text-xs" data-testid="account-email-section">
      <p class="font-bold">{dgettext("dialogs", "Recovery address")}</p>
      <p class="text-muted-foreground">
        {dgettext(
          "dialogs",
          "Optional, and nobody else ever sees it. It exists so you can get back in if you forget your password."
        )}
      </p>

      <div
        :if={@email}
        class="acct-notice flex items-center gap-retro-4"
        data-testid="account-email-current"
      >
        <Icons.icon_checkmark :if={@email_confirmed} class="w-4 h-4" />
        <Icons.icon_warning :if={!@email_confirmed} class="w-4 h-4" />
        <span>
          {@email}
          <span class="text-muted-foreground">
            ({if @email_confirmed,
              do: dgettext("dialogs", "confirmed"),
              else: dgettext("dialogs", "waiting for you to follow the link")})
          </span>
        </span>
      </div>

      <form phx-submit="account_email_submit" class="space-y-retro-4">
        <label class="font-bold" for="account-email">{dgettext("dialogs", "Address:")}</label>
        <.input
          id="account-email"
          name="email"
          type="email"
          value={@email_draft}
          autocomplete="email"
          class="text-xs h-7"
          data-testid="account-email-input"
        />

        <p :if={@email_error} class="text-error" data-testid="account-email-error">
          {@email_error}
        </p>
        <p :if={@email_notice} class="text-muted-foreground" data-testid="account-email-notice">
          {@email_notice}
        </p>

        <div class="acct-action-row flex justify-end gap-retro-4">
          <.button
            :if={@email}
            type="button"
            size="sm"
            variant="outline"
            phx-click="account_email_remove"
            class="acct-action-button"
            data-testid="account-email-remove"
          >
            <:icon><Icons.icon_reject class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Remove")}
          </.button>
          <.button type="submit" size="sm" class="acct-action-button" data-testid="account-email-save">
            <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
            {if @email,
              do: dgettext("dialogs", "Send link again"),
              else: dgettext("dialogs", "Save address")}
          </.button>
        </div>
      </form>
    </div>
    """
  end

  @spec account_state_label(atom()) :: String.t()
  defp account_state_label(:away), do: dgettext("dialogs", "Away")
  defp account_state_label(:identified), do: dgettext("dialogs", "Identified")
  defp account_state_label(_), do: dgettext("dialogs", "Guest")
end
