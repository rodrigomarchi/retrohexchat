defmodule RetroHexChatWeb.Components.UI.ConnectFormPanel do
  @moduledoc """
  Visual body of the sign-in window: the step forms, the remembered nicknames,
  the remember-terminal choice and the hidden session POST form.

  One column at every width: the same content reads in a narrow window on a
  desktop and fills a phone, so nothing in it depends on room to the side.
  What a terminal is — browser, system, screen — belongs to Trusted Terminals
  in the Start menu; here a remembered nickname is only the way back in. Every
  event is addressed through `target` so the owning LiveComponent receives it
  directly.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.IconWell
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label

  import RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard,
    only: [auto_login_switch: 1]

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Services.NickExpiry
  alias RetroHexChatWeb.Components.UI.VisitorGreetingCard
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  attr :step, :atom, required: true, values: [:nickname, :password, :register]
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :auth_token, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :manual_login, :boolean, default: false
  attr :trusted_device_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""
  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true
  attr :return_to, :string, default: nil
  attr :live, :boolean, default: true, doc: "whether the window's LiveView has joined"
  attr :target, :any, default: nil

  @spec connect_form_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def connect_form_panel(assigns) do
    ~H"""
    <.connect_step
      step={@step}
      nickname={@nickname}
      nickname_error={@nickname_error}
      password={@password}
      password_confirm={@password_confirm}
      password_error={@password_error}
      remembered_nicks={@remembered_nicks}
      manual_login={@manual_login}
      remember_device={@remember_device}
      device_label={@device_label}
      csrf_token={@csrf_token}
      chat_session_path={@chat_session_path}
      return_to={@return_to}
      live={@live}
      target={@target}
    />

    <.connect_session_form
      csrf_token={@csrf_token}
      chat_session_path={@chat_session_path}
      nickname={@nickname}
      auth_token={@auth_token}
      trusted_device_login={@trusted_device_login}
      remember_device={@remember_device}
      device_label={@device_label}
      return_to={@return_to}
    />
    """
  end

  attr :step, :atom, required: true
  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil
  attr :remembered_nicks, :list, default: []
  attr :manual_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""
  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true
  attr :return_to, :string, default: nil
  attr :live, :boolean, default: true
  attr :target, :any, default: nil

  defp connect_step(%{step: :nickname} = assigns) do
    ~H"""
    <.remembered_nicknames
      :if={@remembered_nicks != [] and not @manual_login}
      remembered_nicks={@remembered_nicks}
      error={@nickname_error}
      csrf_token={@csrf_token}
      chat_session_path={@chat_session_path}
      return_to={@return_to}
      live={@live}
      target={@target}
    />

    <.nickname_form
      :if={@remembered_nicks == [] or @manual_login}
      nickname={@nickname}
      nickname_error={@nickname_error}
      show_trusted_back={@remembered_nicks != []}
      target={@target}
    />
    """
  end

  defp connect_step(%{step: :password} = assigns) do
    ~H"""
    <form phx-submit="authenticate" phx-target={@target} autocomplete="off" class="space-y-retro-8">
      <.step_header
        icon={:icon_lock}
        title={@nickname}
        subtitle={
          dgettext(
            "connect",
            "The nickname %{nickname} is registered. Please enter your password to continue.",
            nickname: @nickname
          )
        }
      />

      <.password_field
        id="password"
        label={dgettext("connect", "Password")}
        value={@password}
        placeholder={dgettext("connect", "Enter your password...")}
        autofocus
      />
      <.field_error message={@password_error} />

      <.remember_terminal_fields remember_device={@remember_device} device_label={@device_label} />

      <.step_actions target={@target}>
        <.button type="submit" data-testid="auth-btn">
          <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
          {dgettext("connect", "Connect")}
        </.button>
      </.step_actions>
    </form>
    """
  end

  defp connect_step(assigns) do
    ~H"""
    <form phx-submit="register" phx-target={@target} autocomplete="off" class="space-y-retro-8">
      <.step_header
        icon={:icon_star}
        title={@nickname}
        subtitle={
          dgettext(
            "connect",
            "The nickname %{nickname} is available! Choose a password to register it.",
            nickname: @nickname
          )
        }
      />

      <.password_field
        id="reg-password"
        label={dgettext("connect", "Password")}
        value={@password}
        placeholder={dgettext("connect", "Choose a password (min. 5 characters)...")}
        autofocus
      />
      <.password_field
        id="reg-password-confirm"
        name="password_confirm"
        label={dgettext("connect", "Confirm password")}
        value={@password_confirm}
        placeholder={dgettext("connect", "Repeat your password...")}
      />
      <.field_error message={@password_error} />

      <.remember_terminal_fields remember_device={@remember_device} device_label={@device_label} />

      <p class="text-xs text-muted-foreground" data-testid="nick-expiry-notice">
        {dgettext("connect", "Nicknames unused for %{window} are automatically released.",
          window: TimeFormatter.days(NickExpiry.configured_expiration_days())
        )}
      </p>

      <.step_actions target={@target}>
        <.button type="submit" data-testid="register-btn">
          <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
          {dgettext("connect", "Register & Connect")}
        </.button>
      </.step_actions>
    </form>
    """
  end

  attr :remembered_nicks, :list, required: true
  attr :error, :string, default: nil
  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true
  attr :return_to, :string, default: nil
  attr :live, :boolean, default: true
  attr :target, :any, default: nil

  # One row per nickname this browser remembers: the name, the way in and
  # whether it signs in by itself. Every row is this terminal, so nothing in
  # it describes the terminal.
  #
  # Log in is a plain POST of the row's own form: the terminal's cookie is the
  # proof, so there is nothing to ask the LiveView first, and the click works
  # from the first paint, before the window has joined. The switch has nobody to
  # tell until then, and waits disabled.
  defp remembered_nicknames(assigns) do
    ~H"""
    <div class="space-y-retro-8">
      <.step_header icon={:icon_devices} title={dgettext("ui", "Trusted Terminals")} />

      <ul class="bg-white shadow-retro-field" data-testid="remembered-nicks">
        <li
          :for={entry <- @remembered_nicks}
          class="flex items-center gap-retro-6 border-b border-border p-retro-6 last:border-b-0"
          data-testid={"remembered-nick-#{entry.nickname}"}
        >
          <Icons.icon_status_user class="h-4 w-4 shrink-0" />
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-bold">{entry.nickname}</p>
            <.auto_login_switch
              id={"trusted-auto-login-#{entry.nickname}"}
              testid={"trusted-auto-login-#{entry.nickname}"}
              enabled={entry.auto_login == true}
              nickname={entry.nickname}
              device_id={entry.device_id}
              on_toggle="trusted_auto_login_toggle"
              target={@target}
              disabled={not @live}
            />
          </div>
          <form action={@chat_session_path} method="post" class="shrink-0">
            <input type="hidden" name="_csrf_token" value={@csrf_token} />
            <input type="hidden" name="nickname" value={entry.nickname} />
            <input type="hidden" name="trusted_device_login" value="true" />
            <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
            <.button type="submit" size="sm" data-testid={"remembered-nick-login-#{entry.nickname}"}>
              <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
              {dgettext("connect", "Log in")}
            </.button>
          </form>
        </li>
      </ul>

      <.field_error message={@error} />

      <button
        type="button"
        class="text-xs underline"
        phx-click="manual_login"
        phx-target={@target}
        data-testid="manual-login-btn"
      >
        {dgettext("connect", "Log in with another nickname")}
      </button>
    </div>
    """
  end

  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil
  attr :show_trusted_back, :boolean, default: false
  attr :target, :any, default: nil

  # The first step asks only for a name: whether it is new or taken decides
  # the next one, so the same field signs in and creates an account. The rules
  # read as one line, which a wrong name turns into what is wrong with it.
  defp nickname_form(assigns) do
    ~H"""
    <form phx-submit="connect" phx-target={@target} class="space-y-retro-6">
      <.step_header
        icon={:icon_status_user}
        for="nickname"
        title={dgettext("connect", "Log in or create an account")}
        subtitle={dgettext("chat", "An account only needs a nickname and a password.")}
      />
      <div class="relative">
        <Icons.icon_status_user class="pointer-events-none absolute top-1/2 left-2 h-4 w-4 -translate-y-1/2" />
        <.input
          type="text"
          id="nickname"
          name="nickname"
          value={@nickname}
          maxlength="16"
          autocomplete="off"
          required
          aria-describedby="nickname-hint"
          class="pl-8"
          placeholder={dgettext("connect", "Enter your nickname...")}
          phx-mounted={JS.focus()}
        />
      </div>
      <p
        :if={is_nil(@nickname_error)}
        id="nickname-hint"
        class="text-xs text-muted-foreground"
        data-testid="nickname-hint"
      >
        {dgettext("connect", "Use 1 to 16 characters. Start with A–Z. No spaces.")}
      </p>
      <.field_error id="nickname-hint" message={@nickname_error} testid="nickname-error" />

      <.account_features />

      <div class="flex items-center justify-between gap-retro-6 pt-retro-4">
        <button
          :if={@show_trusted_back}
          type="button"
          class="text-xs underline"
          phx-click="trusted_choices"
          phx-target={@target}
          data-testid="trusted-choices-btn"
        >
          {dgettext("connect", "Back to the list")}
        </button>
        <.link
          :if={not @show_trusted_back}
          href={PublicPages.localized_path("/chat/help/feature-sessions")}
          target="_blank"
          rel="noopener"
          class="text-xs underline"
          data-testid="connect-sessions-help"
        >
          {dgettext("connect", "How sessions work")}
        </.link>
        <.button type="submit" data-testid="connect-btn">
          <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
          {dgettext("connect", "Continue")}
        </.button>
      </div>
    </form>
    """
  end

  attr :icon, :atom, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :for, :string, default: nil, doc: "the field the title labels, when it is one"

  # What each step is about, in one glance: a big icon, a title, a line.
  defp step_header(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-8" data-testid="connect-step-header">
      <.icon_well size="lg">{apply(Icons, @icon, [%{class: "h-8 w-8"}])}</.icon_well>
      <div class="min-w-0 space-y-retro-2">
        <.label :if={@for} for={@for} class="block text-sm font-bold">{@title}</.label>
        <p :if={!@for} class="truncate text-sm font-bold">{@title}</p>
        <p :if={@subtitle} class="text-xs text-muted-foreground">{@subtitle}</p>
      </div>
    </div>
    """
  end

  # What an account opens, as a row of icons, each opening its help topic in a
  # new tab — the sign-in window stays where it was.
  defp account_features(assigns) do
    assigns = assign(assigns, :features, VisitorGreetingCard.account_features())

    ~H"""
    <ul
      class="grid grid-cols-5 gap-retro-2 border-t border-border pt-retro-6"
      data-testid="connect-account-features"
    >
      <li :for={feature <- @features}>
        <.link
          href={feature.path}
          target="_blank"
          rel="noopener"
          title={feature.text}
          class="flex flex-col items-center gap-retro-2 p-retro-2 text-center text-[11px] leading-tight hover:bg-white hover:shadow-retro-field"
        >
          {apply(Icons, feature.icon, [%{class: "h-8 w-8"}])}
          <span>{feature.name}</span>
        </.link>
      </li>
    </ul>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, default: "password"
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :placeholder, :string, required: true
  attr :autofocus, :boolean, default: false

  # Typed as text and masked by CSS, so no password manager offers to keep a
  # NickServ password it would then fill into the nickname field.
  defp password_field(assigns) do
    ~H"""
    <div class="space-y-retro-4">
      <.label for={@id}>{@label}</.label>
      <.input
        type="text"
        class="input-masked"
        id={@id}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        autocomplete="off"
        required
        data-1p-ignore
        data-lpignore="true"
        data-bwignore="true"
        phx-mounted={@autofocus && JS.focus()}
      />
    </div>
    """
  end

  attr :message, :string, default: nil
  attr :id, :string, default: nil
  attr :testid, :string, default: nil

  defp field_error(assigns) do
    ~H"""
    <p
      :if={@message}
      id={@id}
      class="flex items-start gap-retro-4 text-xs text-destructive"
      role="alert"
      data-testid={@testid}
    >
      <Icons.icon_reject class="mt-px h-3 w-3 shrink-0" />
      <span>{@message}</span>
    </p>
    """
  end

  attr :target, :any, default: nil
  slot :inner_block, required: true

  defp step_actions(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-retro-6 pt-retro-4">
      <.button
        type="button"
        variant="outline"
        phx-click="back"
        phx-target={@target}
        data-testid="back-btn"
      >
        <:icon><Icons.icon_btn_prev class="h-4 w-4" /></:icon>
        {dgettext("connect", "Back")}
      </.button>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""

  # The label is filled in by the browser (`connect_form.js`) and only shown
  # once the terminal is to be remembered, as the one thing worth changing.
  defp remember_terminal_fields(assigns) do
    ~H"""
    <div class="space-y-retro-4 text-xs">
      <label class="flex items-center gap-retro-4">
        <.checkbox
          id="remember-device"
          name="remember_device"
          value={@remember_device}
          data-device-remember-toggle
          data-testid="remember-device"
        />
        <span class="font-bold">{dgettext("connect", "Remember this terminal")}</span>
      </label>
      <div
        hidden={not @remember_device}
        data-device-remember-panel
        data-testid="remember-device-panel"
        class="flex min-w-0 items-center gap-retro-4 pl-6"
      >
        <label for="device-label" class="shrink-0 text-muted-foreground">
          {dgettext("connect", "Terminal label:")}
        </label>
        <.input
          id="device-label"
          name="device_label"
          value={@device_label}
          maxlength="100"
          placeholder="Mac Firefox"
          class="h-6 min-w-0 text-xs"
          data-device-label-input
          data-testid="device-label"
        />
      </div>
    </div>
    """
  end

  attr :csrf_token, :string, required: true
  attr :chat_session_path, :string, required: true
  attr :nickname, :string, required: true
  attr :auth_token, :string, default: nil
  attr :trusted_device_login, :boolean, default: false
  attr :remember_device, :boolean, default: false
  attr :device_label, :string, default: ""
  attr :return_to, :string, default: nil

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
      <%!-- Carries a shared link across the connect it forced. Sanitised
            server-side by `App.ReturnTo` — this field is client-controlled. --%>
      <input :if={@return_to} type="hidden" name="return_to" value={@return_to} />
    </form>
    """
  end
end
