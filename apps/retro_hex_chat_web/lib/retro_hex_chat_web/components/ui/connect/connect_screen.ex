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
  import RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Timezone

  attr :step, :atom, required: true, values: [:nickname, :password, :register]
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :auth_token, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :takeover_session, :map, default: nil
  attr :manual_login, :boolean, default: false
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
          takeover_session={@takeover_session}
          manual_login={@manual_login}
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
  attr :takeover_session, :map, default: nil
  attr :manual_login, :boolean, default: false
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
      width={560}
      min_width={360}
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
        takeover_session={@takeover_session}
        manual_login={@manual_login}
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
  attr :takeover_session, :map, default: nil
  attr :manual_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  defp connect_step(%{step: :nickname} = assigns) do
    ~H"""
    <.connect_nickname_step
      nickname={@nickname}
      nickname_error={@nickname_error}
      remembered_nicks={@remembered_nicks}
      takeover_session={@takeover_session}
      manual_login={@manual_login}
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
  attr :takeover_session, :map, default: nil
  attr :manual_login, :boolean, default: false

  defp connect_nickname_step(assigns) do
    ~H"""
    <form phx-submit="connect">
      <.takeover_session_card :if={@takeover_session} session={@takeover_session} />

      <.remembered_terminal_choices
        :if={@remembered_nicks != [] and not @manual_login}
        remembered_nicks={@remembered_nicks}
      />

      <.nickname_connect_fields
        :if={@remembered_nicks == [] or @manual_login}
        nickname={@nickname}
        nickname_error={@nickname_error}
        show_trusted_back={@remembered_nicks != []}
      />
    </form>
    """
  end

  attr :session, :map, required: true

  defp takeover_session_card(assigns) do
    assigns =
      assigns
      |> assign(:terminal_label, takeover_terminal_label(assigns.session))
      |> assign(:nickname, session_field(assigns.session, :nickname) || "")
      |> assign(:specs, takeover_specs(assigns.session))

    ~H"""
    <div
      class="mb-3 bg-white p-2 text-xs shadow-retro-field"
      data-testid="takeover-session-card"
    >
      <div class="flex min-w-0 items-start gap-retro-4">
        <span class="inline-flex h-9 w-9 shrink-0 items-center justify-center bg-canvas shadow-retro-sunken">
          <Icons.icon_laptop class="h-6 w-6" />
        </span>
        <div class="min-w-0 flex-1">
          <div class="flex min-w-0 flex-wrap items-center gap-retro-3">
            <span class="font-bold">{dgettext("connect", "Machine that disconnected you")}</span>
            <span class="inline-flex items-center gap-retro-2 bg-selection-bg px-1 text-selection-fg shadow-retro-status">
              <Icons.icon_status_signal class="h-3 w-3 shrink-0" />
              {dgettext("ui", "Active")}
            </span>
          </div>

          <div class="mt-1 flex min-w-0 flex-wrap items-center gap-retro-3">
            <span class="truncate text-sm font-bold">{@terminal_label}</span>
            <span :if={@nickname != ""} class="inline-flex min-w-0 items-center gap-retro-2">
              <Icons.icon_status_user class="h-3.5 w-3.5 shrink-0" />
              <span class="truncate font-bold">{@nickname}</span>
            </span>
          </div>
        </div>
      </div>

      <div
        :if={@specs != []}
        class="mt-2 flex flex-wrap gap-retro-3 border-t border-border pt-2 text-muted-foreground"
      >
        <span
          :for={spec <- @specs}
          class="inline-flex max-w-full min-w-0 items-center gap-retro-2 bg-white px-1 py-px shadow-retro-status"
        >
          <.device_meta_icon item={spec.item} class="h-3.5 w-3.5 shrink-0" />
          <span class="shrink-0 font-bold text-foreground">{spec.label}:</span>
          <span class="min-w-0 truncate">{spec.value}</span>
        </span>
      </div>
    </div>
    """
  end

  attr :remembered_nicks, :list, default: []

  defp remembered_terminal_choices(assigns) do
    ~H"""
    <div class="space-y-retro-4" data-testid="remembered-nicks">
      <div class="flex items-start justify-between gap-retro-6">
        <div class="min-w-0">
          <p class="flex items-center gap-retro-4 text-xs font-bold">
            <Icons.icon_devices class="w-4 h-4 shrink-0" />
            {dgettext("connect", "Trusted terminals")}
          </p>
          <p class="mt-1 text-xs text-muted-foreground">
            {dgettext("connect", "Choose a remembered NickServ identity.")}
          </p>
        </div>
        <.button
          type="button"
          size="sm"
          variant="outline"
          phx-click="manual_login"
          data-testid="manual-login-btn"
          class="shrink-0"
        >
          <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
          {dgettext("connect", "Use another nick/password")}
        </.button>
      </div>

      <div class="grid max-h-[430px] gap-retro-6 overflow-y-auto pr-1 retro-scrollbar">
        <.trusted_terminal_card
          :for={entry <- @remembered_nicks}
          entry={entry}
          nickname={entry.nickname}
          current
          testid={"remembered-nick-#{entry.nickname}"}
          auto_login_testid={"trusted-auto-login-#{entry.nickname}"}
          on_auto_login_toggle="trusted_auto_login_toggle"
          data-trusted-terminal-choice
        >
          <:actions :let={terminal}>
            <.button
              type="button"
              size="sm"
              phx-click="connect_remembered"
              phx-value-nickname={terminal.nickname}
              data-testid={"remembered-nick-login-#{terminal.nickname}"}
            >
              <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
              {dgettext("connect", "Enter as %{nickname}", nickname: terminal.nickname)}
            </.button>
          </:actions>
        </.trusted_terminal_card>
      </div>
    </div>
    """
  end

  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :autofocus, :boolean, default: true
  attr :show_trusted_back, :boolean, default: false

  defp nickname_connect_fields(assigns) do
    ~H"""
    <div :if={@show_trusted_back} class="mb-3 flex justify-end">
      <.button
        type="button"
        size="sm"
        variant="outline"
        phx-click="trusted_choices"
        data-testid="trusted-choices-btn"
      >
        <:icon><Icons.icon_devices class="h-4 w-4" /></:icon>
        {dgettext("connect", "Back to trusted terminals")}
      </.button>
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
          phx-mounted={if @autofocus, do: JS.focus()}
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
          data-device-remember-toggle
          data-testid="remember-device"
        />
        <span class="min-w-0">
          <span class="font-bold">{dgettext("connect", "Remember this terminal")}</span>
          <span class="block text-muted-foreground">
            {dgettext("connect", "Use this browser for faster NickServ login later.")}
          </span>
        </span>
      </label>
      <div
        hidden={not @remember_device}
        data-device-remember-panel
        data-testid="remember-device-panel"
        class="space-y-retro-3"
      >
        <div class="flex items-center gap-retro-4 min-w-0">
          <label for="device-label" class="font-bold shrink-0">
            {dgettext("connect", "Terminal label:")}
          </label>
          <span
            hidden
            data-device-label-suggestion
            data-testid="device-label-suggestion"
            class="inline-flex items-center min-w-0 gap-retro-2 bg-white px-1 shadow-retro-field text-muted-foreground"
          >
            <Icons.icon_tag class="w-3 h-3 shrink-0" />
            <span class="truncate" data-device-label-suggestion-value></span>
          </span>
        </div>
        <.input
          id="device-label"
          name="device_label"
          value={@device_label}
          maxlength="100"
          placeholder="Mac Firefox"
          class="h-7 text-xs"
          data-device-label-input
          data-testid="device-label"
        />

        <details
          open
          class="bg-white p-2 shadow-retro-field"
          data-testid="device-metadata-details"
        >
          <summary class="flex cursor-pointer list-none items-center gap-retro-3 font-bold [&::-webkit-details-marker]:hidden">
            <Icons.icon_devices class="w-3.5 h-3.5 shrink-0" />
            <span class="min-w-0 truncate">{dgettext("connect", "Device metadata")}</span>
          </summary>
          <div
            hidden
            data-device-label-metadata
            data-testid="device-label-metadata"
            class="mt-retro-4 grid grid-cols-2 gap-x-retro-8 gap-y-retro-3 text-muted-foreground"
          >
            <.device_meta_item item="device_type" label={dgettext("connect", "Device")} />
            <.device_meta_item item="browser" label={dgettext("connect", "Browser")} />
            <.device_meta_item item="os" label={dgettext("connect", "OS")} />
            <.device_meta_item item="language" label={dgettext("connect", "Language")} />
            <.device_meta_item item="screen" label={dgettext("connect", "Screen")} />
            <.device_meta_item item="timezone" label={dgettext("connect", "Timezone")} />
            <.device_meta_item item="color_depth" label={dgettext("connect", "Color")} />
            <.device_meta_item item="cores" label={dgettext("connect", "CPU")} />
            <.device_meta_item item="touch" label={dgettext("connect", "Touch")} />
          </div>
        </details>
      </div>
    </div>
    """
  end

  attr :item, :string, required: true
  attr :label, :string, required: true

  defp device_meta_item(assigns) do
    ~H"""
    <span hidden class="inline-flex min-w-0 items-center gap-retro-3" data-device-meta-item={@item}>
      <.device_meta_icon item={@item} class="w-3.5 h-3.5 shrink-0" />
      <span class="font-bold text-foreground">{@label}:</span>
      <span class="min-w-0 truncate" data-device-meta-value={@item}></span>
    </span>
    """
  end

  attr :item, :string, required: true
  attr :class, :string, default: nil

  defp device_meta_icon(%{item: "browser"} = assigns),
    do: ~H"<Icons.icon_browser class={@class} />"

  defp device_meta_icon(%{item: "os"} = assigns),
    do: ~H"<Icons.icon_operating_system class={@class} />"

  defp device_meta_icon(%{item: "language"} = assigns),
    do: ~H"<Icons.icon_globe class={@class} />"

  defp device_meta_icon(%{item: "screen"} = assigns),
    do: ~H"<Icons.icon_tab_display class={@class} />"

  defp device_meta_icon(%{item: "timezone"} = assigns),
    do: ~H"<Icons.icon_clock class={@class} />"

  defp device_meta_icon(%{item: "color_depth"} = assigns),
    do: ~H"<Icons.icon_palette class={@class} />"

  defp device_meta_icon(%{item: "cores"} = assigns), do: ~H"<Icons.icon_server class={@class} />"
  defp device_meta_icon(%{item: "touch"} = assigns), do: ~H"<Icons.icon_devices class={@class} />"

  defp device_meta_icon(%{item: "connected_at"} = assigns),
    do: ~H"<Icons.icon_connect class={@class} />"

  defp device_meta_icon(%{item: "last_seen_at"} = assigns),
    do: ~H"<Icons.icon_btn_refresh class={@class} />"

  defp device_meta_icon(assigns), do: ~H"<Icons.icon_laptop class={@class} />"

  defp takeover_specs(session) do
    timezone = session_field(session, :timezone) || "Etc/UTC"

    [
      %{
        item: "browser",
        label: dgettext("connect", "Browser"),
        value: session_field(session, :browser)
      },
      %{item: "os", label: dgettext("connect", "OS"), value: session_field(session, :os)},
      %{
        item: "screen",
        label: dgettext("connect", "Screen"),
        value: session_field(session, :screen)
      },
      %{
        item: "timezone",
        label: dgettext("connect", "Timezone"),
        value: session_field(session, :timezone)
      },
      %{
        item: "cores",
        label: dgettext("connect", "CPU"),
        value: takeover_cores_label(session_field(session, :cores))
      },
      %{
        item: "color_depth",
        label: dgettext("connect", "Color"),
        value: takeover_color_depth_label(session_field(session, :color_depth))
      },
      %{
        item: "connected_at",
        label: dgettext("dialogs", "Connected"),
        value: format_takeover_dt(session_field(session, :connected_at), timezone)
      },
      %{
        item: "last_seen_at",
        label: dgettext("ui", "Last"),
        value: format_takeover_dt(session_field(session, :last_seen_at), timezone)
      }
    ]
    |> Enum.reject(&blank?(&1.value))
  end

  defp takeover_terminal_label(session) do
    case session_field(session, :label) do
      "Unremembered session" -> dgettext("connect", "Unremembered session")
      label when is_binary(label) and label != "" -> label
      _ -> dgettext("connect", "Unknown device")
    end
  end

  defp session_field(session, field) do
    case Map.fetch(session, field) do
      {:ok, value} -> value
      :error -> Map.get(session, Atom.to_string(field))
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp takeover_color_depth_label(bits) when is_integer(bits) and bits > 0 do
    dgettext("ui", "%{bits}-bit", bits: bits)
  end

  defp takeover_color_depth_label(_bits), do: nil

  defp takeover_cores_label(count) when is_integer(count) and count > 0 do
    dgettext("ui", "%{count} cores", count: count)
  end

  defp takeover_cores_label(_count), do: nil

  defp format_takeover_dt(nil, _timezone), do: nil

  defp format_takeover_dt(%DateTime{} = dt, timezone) do
    dt
    |> Timezone.shift(timezone)
    |> Calendar.strftime("%d/%m %H:%M")
  end

  defp format_takeover_dt(_dt, _timezone), do: nil

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
          <span id="connect-tray-clock" data-clock phx-hook="ClockHook" class="font-mono tabular-nums">
          </span>
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
      <input type="hidden" name="device_label" id="connect-device-label-input" value={@device_label} />
      <input type="hidden" name="timezone" id="connect-timezone-input" value="Etc/UTC" />
      <input type="hidden" name="client_info" id="connect-client-info-input" value="{}" />
    </form>
    """
  end
end
