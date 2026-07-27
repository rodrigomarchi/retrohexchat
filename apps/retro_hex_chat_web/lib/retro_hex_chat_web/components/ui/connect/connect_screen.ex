defmodule RetroHexChatWeb.Components.UI.ConnectScreen do
  @moduledoc """
  Full visual composition for the pre-auth connect desktop.

  The LiveView owns validation, authentication and navigation. This component
  owns the visual shell: desktop, connect window, step forms, taskbar, hidden
  session POST form and About dialog.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.ConnectStatusBar
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.MenuBarApp

  alias RetroHexChatWeb.Icons

  attr :step, :atom, required: true, values: [:nickname, :password, :register]
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :auth_token, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :trusted_device_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""
  attr :flash, :map, default: %{}
  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true

  @spec connect_screen(map()) :: Phoenix.LiveView.Rendered.t()
  def connect_screen(assigns) do
    ~H"""
    <div id="connect-root" phx-hook="ConnectFormHook" class="flex flex-col h-screen bg-background">
      <.desktop id="connect-desktop" persist={false} data-testid="connect-desktop">
        <:header>
          <.app_header on_logo_click={show_modal("about-dialog")}>
            <:panels>
              <.menu_bar_app
                id="menubar"
                phx-hook="MenuBarHook"
                connected={false}
                on_action="menu_action"
              />
              <.connect_status_bar class="ml-auto" step={@step} />
            </:panels>
          </.app_header>
        </:header>

        <.connect_window
          step={@step}
          nickname={@nickname}
          nickname_error={@nickname_error}
          password={@password}
          password_confirm={@password_confirm}
          password_error={@password_error}
          remembered_nicks={@remembered_nicks}
          remember_device={@remember_device}
          device_label={@device_label}
          flash={@flash}
        />

        <:taskbar>
          <.connect_taskbar />
        </:taskbar>
      </.desktop>

      <.connect_session_form
        csrf_token={@csrf_token}
        chat_session_path={@chat_session_path}
        nickname={@nickname}
        auth_token={@auth_token}
        trusted_device_login={@trusted_device_login}
        remember_device={@remember_device}
        device_label={@device_label}
      />
      <.about_dialog id="about-dialog" />
    </div>
    """
  end

  attr :step, :atom, required: true
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""
  attr :flash, :map, default: %{}

  defp connect_window(assigns) do
    ~H"""
    <.desktop_window
      id="connect"
      title={dgettext("connect", "Connect to RetroHexChat")}
      pinned
      default_centered
      width={448}
      min_width={320}
      resizable={false}
      body_class="p-4"
      data-testid="connect-window"
    >
      <:icon><Icons.icon_connect class="w-4 h-4" /></:icon>
      <.alert
        :if={@flash["error"]}
        variant="destructive"
        class="mb-4"
        data-testid="session-alert"
      >
        <:icon><Icons.icon_warning /></:icon>
        <.alert_description>{@flash["error"]}</.alert_description>
      </.alert>

      <.connect_step
        step={@step}
        nickname={@nickname}
        nickname_error={@nickname_error}
        password={@password}
        password_confirm={@password_confirm}
        password_error={@password_error}
        remembered_nicks={@remembered_nicks}
        remember_device={@remember_device}
        device_label={@device_label}
      />
    </.desktop_window>
    """
  end

  attr :step, :atom, required: true
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp connect_step(%{step: :nickname} = assigns) do
    ~H"""
    <.connect_nickname_step
      nickname={@nickname}
      nickname_error={@nickname_error}
      remembered_nicks={@remembered_nicks}
    />
    """
  end

  defp connect_step(%{step: :password} = assigns) do
    ~H"""
    <.connect_password_step
      nickname={@nickname}
      password={@password}
      password_error={@password_error}
      remember_device={@remember_device}
      device_label={@device_label}
    />
    """
  end

  defp connect_step(assigns) do
    ~H"""
    <.connect_register_step
      nickname={@nickname}
      password={@password}
      password_confirm={@password_confirm}
      password_error={@password_error}
      remember_device={@remember_device}
      device_label={@device_label}
    />
    """
  end

  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :remembered_nicks, :list, default: []

  defp connect_nickname_step(assigns) do
    ~H"""
    <form phx-submit="connect">
      <div
        :if={@remembered_nicks != []}
        class="mb-3 space-y-retro-4"
        data-testid="remembered-nicks"
      >
        <p class="text-xs font-bold flex items-center gap-retro-4">
          <Icons.icon_devices class="w-4 h-4" />
          {dgettext("connect", "Trusted terminal")}
        </p>
        <div class="grid gap-retro-4">
          <button
            :for={entry <- @remembered_nicks}
            type="button"
            class="shadow-retro-raised bg-surface px-2 py-1 text-left text-xs hover:bg-selection-bg hover:text-selection-fg focus-visible:outline focus-visible:outline-2 focus-visible:outline-black"
            phx-click="connect_remembered"
            phx-value-nickname={entry.nickname}
            data-testid={"remembered-nick-#{entry.nickname}"}
          >
            <span class="inline-flex items-center gap-retro-4 min-w-0">
              <Icons.icon_status_user class="w-3.5 h-3.5 shrink-0" />
              <span class="truncate font-bold">{entry.nickname}</span>
              <span class="truncate text-muted-foreground">{entry.label}</span>
            </span>
          </button>
        </div>
      </div>

      <.retro_fieldset legend={dgettext("connect", "User Information")}>
        <.field_row stacked>
          <.label for="nickname">
            <Icons.icon_status_user class="w-3.5 h-3.5 inline-block" /> {dgettext(
              "connect",
              "Nickname"
            )}
          </.label>
          <.input
            type="text"
            id="nickname"
            name="nickname"
            value={@nickname}
            maxlength="16"
            autocomplete="off"
            required
            placeholder={dgettext("connect", "Enter your nickname...")}
            phx-mounted={JS.focus()}
          />
        </.field_row>
        <ul class="text-xs mt-2 space-y-0.5 text-muted-foreground">
          <li>
            <Icons.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext(
              "connect",
              "1-16 characters"
            )}
          </li>
          <li>
            <Icons.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext(
              "connect",
              "Must start with a letter"
            )}
          </li>
          <li>
            <Icons.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext(
              "connect",
              "No spaces allowed"
            )}
          </li>
          <li>
            <Icons.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext(
              "connect",
              "Case sensitive"
            )}
          </li>
        </ul>
        <p :if={@nickname_error} class="text-destructive text-xs mt-2">
          <Icons.icon_reject class="w-3 h-3 inline-block" /> {@nickname_error}
        </p>
      </.retro_fieldset>

      <div class="flex justify-end gap-2 mt-4">
        <.button
          type="submit"
          data-testid="connect-btn"
        >
          <:icon><Icons.icon_connect /></:icon>
          {dgettext("connect", "Connect")}
        </.button>
      </div>

      <div class="mt-4 space-y-2 text-xs">
        <.connect_notice icon={:connect} title={dgettext("connect", "One session per nickname")}>
          {dgettext("connect", "Connecting from another window ends the previous session.")}
        </.connect_notice>
        <.connect_notice icon={:clock} title={dgettext("connect", "Session expiry")}>
          {dgettext("connect", "Sessions expire after 10 failed reconnection attempts.")}
        </.connect_notice>
        <.connect_notice
          icon={:warning}
          title={dgettext("connect", "Nickname cleanup")}
          data-testid="nick-expiry-notice"
        >
          {dgettext("connect", "Nicknames unused for 7 days are automatically released.")}
        </.connect_notice>
      </div>
    </form>
    """
  end

  attr :nickname, :string, required: true
  attr :password, :string, required: true
  attr :password_error, :string, default: nil
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp connect_password_step(assigns) do
    ~H"""
    <form phx-submit="authenticate" autocomplete="off">
      <.retro_fieldset legend={dgettext("connect", "Authentication")}>
        <.alert class="mb-3">
          <:icon><Icons.icon_shield /></:icon>
          <.alert_description>
            {dgettext(
              "connect",
              "The nickname %{nickname} is registered. Please enter your password to continue.",
              nickname: @nickname
            )}
          </.alert_description>
        </.alert>

        <.field_row stacked>
          <.label for="password">
            <Icons.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext(
              "connect",
              "Password"
            )}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="password"
            name="password"
            value={@password}
            placeholder={dgettext("connect", "Enter your password...")}
            autocomplete="off"
            required
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
            phx-mounted={JS.focus()}
          />
        </.field_row>
        <p :if={@password_error} class="text-destructive text-xs mt-2">
          <Icons.icon_reject class="w-3 h-3 inline-block" /> {@password_error}
        </p>
      </.retro_fieldset>

      <.remember_terminal_fields remember_device={@remember_device} device_label={@device_label} />

      <div class="flex justify-end gap-2 mt-4">
        <.button type="button" variant="outline" phx-click="back" data-testid="back-btn">
          <:icon><Icons.icon_btn_prev /></:icon>
          {dgettext("connect", "Back")}
        </.button>
        <.button type="submit" data-testid="auth-btn">
          <:icon><Icons.icon_connect /></:icon>
          {dgettext("connect", "Connect")}
        </.button>
      </div>
    </form>
    """
  end

  attr :nickname, :string, required: true
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp connect_register_step(assigns) do
    ~H"""
    <form phx-submit="register" autocomplete="off">
      <.retro_fieldset legend={dgettext("connect", "Registration")}>
        <.alert class="mb-3">
          <:icon><Icons.icon_checkmark /></:icon>
          <.alert_description>
            {dgettext(
              "connect",
              "The nickname %{nickname} is available! Choose a password to register it.",
              nickname: @nickname
            )}
          </.alert_description>
        </.alert>

        <.field_row stacked class="mb-2">
          <.label for="reg-password">
            <Icons.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext(
              "connect",
              "Password"
            )}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password"
            name="password"
            value={@password}
            placeholder={dgettext("connect", "Choose a password (min. 5 characters)...")}
            autocomplete="off"
            required
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
            phx-mounted={JS.focus()}
          />
        </.field_row>

        <.field_row stacked>
          <.label for="reg-password-confirm">
            <Icons.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext(
              "connect",
              "Confirm password"
            )}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password-confirm"
            name="password_confirm"
            value={@password_confirm}
            placeholder={dgettext("connect", "Repeat your password...")}
            autocomplete="off"
            required
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
          />
        </.field_row>
        <p :if={@password_error} class="text-destructive text-xs mt-2">
          <Icons.icon_reject class="w-3 h-3 inline-block" /> {@password_error}
        </p>
      </.retro_fieldset>

      <.remember_terminal_fields remember_device={@remember_device} device_label={@device_label} />

      <div class="flex justify-end gap-2 mt-4">
        <.button type="button" variant="outline" phx-click="back" data-testid="back-btn">
          <:icon><Icons.icon_btn_prev /></:icon>
          {dgettext("connect", "Back")}
        </.button>
        <.button type="submit" data-testid="register-btn">
          <:icon><Icons.icon_connect /></:icon>
          {dgettext("connect", "Register & Connect")}
        </.button>
      </div>
    </form>
    """
  end

  attr :icon, :atom, required: true, values: [:connect, :clock, :warning]
  attr :title, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp connect_notice(assigns) do
    ~H"""
    <div class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field" {@rest}>
      <.notice_icon icon={@icon} class="w-3.5 h-3.5 shrink-0 mt-0.5" />
      <div>
        <strong>{@title}</strong>
        <p class="text-muted-foreground">{render_slot(@inner_block)}</p>
      </div>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :class, :string, default: nil

  defp notice_icon(%{icon: :clock} = assigns), do: ~H"<Icons.icon_clock class={@class} />"
  defp notice_icon(%{icon: :warning} = assigns), do: ~H"<Icons.icon_warning class={@class} />"
  defp notice_icon(assigns), do: ~H"<Icons.icon_connect class={@class} />"

  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp remember_terminal_fields(assigns) do
    ~H"""
    <div class="mt-3 p-2 bg-canvas shadow-retro-field text-xs space-y-retro-6">
      <label class="flex items-start gap-retro-4">
        <.checkbox
          id="remember-device"
          name="remember_device"
          value={@remember_device}
          data-testid="remember-device"
        />
        <span class="min-w-0">
          <span class="font-bold">{dgettext("connect", "Remember this terminal")}</span>
          <span class="block text-muted-foreground">
            {dgettext("connect", "Use this browser for faster NickServ login later.")}
          </span>
        </span>
      </label>
      <div class="space-y-retro-2">
        <label for="device-label" class="font-bold">
          {dgettext("connect", "Terminal label:")}
        </label>
        <.input
          id="device-label"
          name="device_label"
          value={@device_label}
          maxlength="100"
          placeholder={dgettext("connect", "Home laptop")}
          class="h-7 text-xs"
          data-testid="device-label"
        />
      </div>
    </div>
    """
  end

  defp connect_taskbar(assigns) do
    ~H"""
    <.taskbar>
      <:start>
        <div class="relative">
          <.start_button label={dgettext("ui", "Start")}>
            <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
          </.start_button>
          <.start_menu id="connect-start-menu">
            <.start_menu_item data-window-open="connect" label={dgettext("connect", "Connect")}>
              <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
            </.start_menu_item>
            <.start_menu_item
              phx-click="help_topics"
              label={dgettext("ui", "Help Topics")}
              data-testid="connect-start-help-topics"
            >
              <:icon><Icons.icon_btn_help_topics class="h-4 w-4" /></:icon>
            </.start_menu_item>
            <.start_menu_separator />
            <.start_menu_item
              phx-click={show_modal("about-dialog")}
              label={dgettext("ui", "About RetroHexChat")}
              data-testid="connect-start-about"
            >
              <:icon><Icons.icon_dialog_about class="h-4 w-4" /></:icon>
            </.start_menu_item>
          </.start_menu>
        </div>
      </:start>
      <.taskbar_button window="connect" label={dgettext("connect", "Connect")}>
        <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <:tray>
        <.desktop_tray>
          <span id="connect-tray-clock" phx-hook="ClockHook" class="font-mono tabular-nums"></span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true
  attr :nickname, :string, required: true
  attr :auth_token, :string, default: nil
  attr :trusted_device_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp connect_session_form(assigns) do
    ~H"""
    <form id="connect-session-form" action={@chat_session_path} method="post" class="hidden">
      <input type="hidden" name="_csrf_token" value={@csrf_token} />
      <input type="hidden" name="nickname" value={@nickname} />
      <input :if={@auth_token} type="hidden" name="auth_token" value={@auth_token} />
      <input type="hidden" name="trusted_device_login" value={to_string(@trusted_device_login)} />
      <input type="hidden" name="remember_device" value={to_string(@remember_device)} />
      <input type="hidden" name="device_label" value={@device_label} />
      <input type="hidden" name="timezone" id="connect-timezone-input" value="Etc/UTC" />
      <input type="hidden" name="client_info" id="connect-client-info-input" value="{}" />
    </form>
    """
  end
end
