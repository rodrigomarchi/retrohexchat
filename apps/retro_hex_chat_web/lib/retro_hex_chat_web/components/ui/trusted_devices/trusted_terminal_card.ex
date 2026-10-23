defmodule RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard do
  @moduledoc """
  Shared trusted-terminal card used anywhere a remembered device identity is shown.

  A terminal, a live session and a security event are described with the same
  facts — the browser, the screen, when it was last seen — so the pieces they
  are drawn from are public here: `terminal_spec/1` for a device fact as a
  badge, `terminal_fact/1` for a labelled one, `terminal_icon/1` for the
  picture each fact wears, and `device_specs/1` for the device facts a record
  carries. A fact read in two windows is then drawn, worded and pictured once.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Card
  import RetroHexChatWeb.Components.UI.IconWell
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Switch

  alias RetroHexChat.Text
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.Icons

  attr :entry, :map, required: true
  attr :nickname, :string, default: nil
  attr :current, :boolean, default: false
  attr :trusted, :boolean, default: true
  attr :show_auto_login_toggle, :boolean, default: true
  attr :on_auto_login_toggle, :any, default: nil
  attr :auto_login_target, :any, default: nil
  attr :auto_login_testid, :string, default: nil
  attr :show_audit_metadata, :boolean, default: false
  attr :timezone, :string, default: nil
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :actions
  slot :management

  @spec trusted_terminal_card(map()) :: Phoenix.LiveView.Rendered.t()
  def trusted_terminal_card(assigns) do
    assigns =
      assigns
      |> assign(:nickname, assigns.nickname || entry_field(assigns.entry, :nickname) || "")
      |> assign(:terminal_label, terminal_label(assigns.entry))
      |> assign(:device_id, device_id(assigns.entry))
      |> assign(:auto_login, entry_field(assigns.entry, :auto_login) == true)
      |> assign(:auto_login_id, auto_login_id(assigns.entry, assigns.nickname))
      |> assign(:auto_login_testid, auto_login_testid(assigns))
      |> assign(:primary_specs, device_specs(assigns.entry))
      |> assign(:trust_specs, trust_specs(assigns.entry, display_timezone(assigns)))
      |> assign(:audit_specs, audit_specs(assigns.entry, display_timezone(assigns)))
      |> assign(:card_context, card_context(assigns))
      |> assign(:testid, assigns.testid || default_testid(assigns))

    ~H"""
    <.card
      class={classes(["bg-white p-3 text-xs", @class])}
      data-testid={@testid}
      data-trusted-terminal-card
      {@rest}
    >
      <div class="flex min-w-0 items-start justify-between gap-retro-8">
        <div class="flex min-w-0 items-start gap-retro-8">
          <.icon_well size="lg">
            <Icons.icon_laptop class="h-8 w-8" />
          </.icon_well>

          <div class="min-w-0">
            <div class="mb-retro-4 flex min-w-0 flex-wrap items-center gap-retro-4">
              <.badge :if={@current} variant="success">
                <:icon><Icons.icon_checkmark class="h-3 w-3" /></:icon>
                {dgettext("ui", "This device")}
              </.badge>
              <.badge :if={@trusted} variant="success">
                <:icon><Icons.icon_shield class="h-3 w-3" /></:icon>
                {dgettext("ui", "Trusted")}
              </.badge>
              <.badge :if={@auto_login} variant="default">
                <:icon><Icons.icon_connect class="h-3 w-3" /></:icon>
                {dgettext("ui", "Auto-login")}
              </.badge>
            </div>

            <span class="block truncate text-base font-bold leading-tight">
              {@terminal_label}
            </span>
            <div class="mt-retro-4 flex min-w-0 flex-wrap items-center gap-retro-4">
              <span :if={@nickname != ""} class="inline-flex min-w-0 items-center gap-retro-4">
                <Icons.icon_status_user class="h-4 w-4 shrink-0" />
                <span class="truncate text-sm font-bold">{@nickname}</span>
              </span>
              <.badge :if={@nickname != ""} variant="outline">
                <:icon><Icons.icon_shield class="h-3 w-3" /></:icon>
                NickServ
              </.badge>
            </div>
          </div>
        </div>

        <div
          :if={@actions != [] or @show_auto_login_toggle}
          class="flex shrink-0 flex-col items-end gap-retro-4"
        >
          {render_slot(@actions, @card_context)}

          <.auto_login_switch
            :if={@show_auto_login_toggle}
            id={@auto_login_id}
            testid={@auto_login_testid}
            enabled={@auto_login}
            nickname={@nickname}
            device_id={@device_id}
            on_toggle={@on_auto_login_toggle}
            target={@auto_login_target}
          />
        </div>
      </div>

      <div
        :if={@primary_specs != []}
        class="mt-3 flex flex-wrap gap-retro-4 border-t border-border pt-2"
      >
        <.terminal_spec :for={spec <- @primary_specs} spec={spec} />
      </div>

      <div
        :if={@trust_specs != []}
        class="mt-3 grid gap-retro-4 border-t border-border pt-2 sm:grid-cols-3"
      >
        <.terminal_fact :for={fact <- @trust_specs} fact={fact} />
      </div>

      <div
        :if={@show_audit_metadata and @audit_specs != []}
        class="mt-3 grid gap-retro-4 border-t border-border pt-2 sm:grid-cols-2 lg:grid-cols-3"
      >
        <.terminal_fact :for={fact <- @audit_specs} fact={fact} />
      </div>

      <div :if={@management != []} class="mt-3 border-t border-border pt-2">
        {render_slot(@management, @card_context)}
      </div>
    </.card>
    """
  end

  attr :id, :string, required: true
  attr :testid, :string, required: true
  attr :enabled, :boolean, required: true
  attr :nickname, :string, required: true
  attr :device_id, :any, default: nil
  attr :on_toggle, :any, default: nil
  attr :target, :any, default: nil
  attr :disabled, :boolean, default: false

  @doc """
  Whether a remembered nickname signs in by itself on this terminal: the
  switch sends `on_toggle` with the nickname, the device and the state it
  asks for.
  """
  @spec auto_login_switch(map()) :: Phoenix.LiveView.Rendered.t()
  def auto_login_switch(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-4">
      <.switch
        id={@id}
        value={@enabled}
        on_toggle={@on_toggle}
        target={@target}
        event_value={%{nickname: @nickname, device_id: @device_id, enabled: not @enabled}}
        testid={@testid}
        disabled={@disabled}
      />
      <.label for={@id} class="text-[11px]">{dgettext("ui", "Auto-login")}</.label>
    </div>
    """
  end

  attr :spec, :map, required: true, doc: "`%{icon: atom, value: String.t()}`"

  @doc "A device fact as a badge: its picture and its value."
  @spec terminal_spec(map()) :: Phoenix.LiveView.Rendered.t()
  def terminal_spec(assigns) do
    ~H"""
    <.badge variant="secondary" class="max-w-full">
      <:icon><.terminal_icon icon={@spec.icon} class="h-3 w-3" /></:icon>
      <span class="truncate">{@spec.value}</span>
    </.badge>
    """
  end

  attr :fact, :map, required: true, doc: "`%{icon: atom, label: String.t(), value: String.t()}`"

  @doc "A labelled fact: its picture, what it is, and its value."
  @spec terminal_fact(map()) :: Phoenix.LiveView.Rendered.t()
  def terminal_fact(assigns) do
    ~H"""
    <span class="inline-flex min-w-0 items-center gap-retro-4 border border-border bg-white px-1 py-px">
      <.terminal_icon icon={@fact.icon} class="h-3.5 w-3.5 shrink-0" />
      <span class="shrink-0 font-bold">{@fact.label}:</span>
      <span class="min-w-0 truncate text-muted-foreground">{@fact.value}</span>
    </span>
    """
  end

  attr :icon, :atom, required: true
  attr :class, :string, default: nil

  @doc "The picture a terminal's fact wears, by the fact it is."
  @spec terminal_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def terminal_icon(%{icon: :browser} = assigns),
    do: ~H"<Icons.icon_browser class={@class} />"

  def terminal_icon(%{icon: :os} = assigns),
    do: ~H"<Icons.icon_operating_system class={@class} />"

  def terminal_icon(%{icon: :display} = assigns),
    do: ~H"<Icons.icon_tab_display class={@class} />"

  def terminal_icon(%{icon: :timezone} = assigns),
    do: ~H"<Icons.icon_globe class={@class} />"

  def terminal_icon(%{icon: :type} = assigns),
    do: ~H"<Icons.icon_devices class={@class} />"

  def terminal_icon(%{icon: :language} = assigns),
    do: ~H"<Icons.icon_globe class={@class} />"

  def terminal_icon(%{icon: :color_depth} = assigns),
    do: ~H"<Icons.icon_palette class={@class} />"

  def terminal_icon(%{icon: :cores} = assigns),
    do: ~H"<Icons.icon_database class={@class} />"

  def terminal_icon(%{icon: :grant} = assigns),
    do: ~H"<Icons.icon_shield class={@class} />"

  def terminal_icon(%{icon: :connect} = assigns),
    do: ~H"<Icons.icon_connect class={@class} />"

  def terminal_icon(%{icon: :expires} = assigns),
    do: ~H"<Icons.icon_warning class={@class} />"

  def terminal_icon(%{icon: :touch} = assigns),
    do: ~H"<Icons.icon_call_devices class={@class} />"

  def terminal_icon(%{icon: :first_seen} = assigns),
    do: ~H"<Icons.icon_clock class={@class} />"

  def terminal_icon(%{icon: :last_seen} = assigns),
    do: ~H"<Icons.icon_btn_refresh class={@class} />"

  def terminal_icon(%{icon: :active} = assigns),
    do: ~H"<Icons.icon_status_signal class={@class} />"

  def terminal_icon(%{icon: :id} = assigns),
    do: ~H"<Icons.icon_tag class={@class} />"

  def terminal_icon(%{icon: :fingerprint} = assigns),
    do: ~H"<Icons.icon_tag class={@class} />"

  def terminal_icon(%{icon: :actor} = assigns),
    do: ~H"<Icons.icon_status_user class={@class} />"

  def terminal_icon(%{icon: :terminal} = assigns),
    do: ~H"<Icons.icon_laptop class={@class} />"

  def terminal_icon(assigns), do: ~H"<Icons.icon_tag class={@class} />"

  @doc """
  The device facts `entry` carries — browser, system, kind, screen, language,
  time zone, colour depth, cores, touch — leaving out the ones it does not
  know. A terminal and a session both carry them.
  """
  @spec device_specs(map()) :: [%{icon: atom(), value: String.t()}]
  def device_specs(entry) do
    [
      %{icon: :browser, value: entry_field(entry, :browser)},
      %{icon: :os, value: entry_field(entry, :os)},
      %{icon: :type, value: device_type_label(entry_field(entry, :device_type))},
      %{icon: :display, value: entry_field(entry, :screen)},
      %{icon: :language, value: entry_field(entry, :language)},
      %{icon: :timezone, value: entry_field(entry, :timezone)},
      %{icon: :color_depth, value: color_depth_label(entry_field(entry, :color_depth))},
      %{icon: :cores, value: cores_label(entry_field(entry, :cores))},
      %{icon: :touch, value: touch_label(entry_field(entry, :touch))}
    ]
    |> Enum.reject(&(Text.blank?(&1.value) or &1.value == "unknown"))
  end

  defp trust_specs(entry, timezone) do
    [
      %{
        icon: :connect,
        label: dgettext("ui", "Last login"),
        value: format_dt(entry_field(entry, :last_used_at), timezone)
      },
      %{
        icon: :grant,
        label: dgettext("ui", "Trusted since"),
        value: format_dt(entry_field(entry, :granted_at), timezone)
      },
      %{
        icon: :expires,
        label: dgettext("ui", "Trust expires"),
        value: format_dt(entry_field(entry, :expires_at), timezone)
      }
    ]
  end

  defp audit_specs(entry, timezone) do
    [
      %{
        icon: :first_seen,
        label: dgettext("ui", "First visit"),
        value: format_dt(entry_field(entry, :first_seen_at), timezone)
      },
      %{
        icon: :last_seen,
        label: dgettext("ui", "Last activity"),
        value: format_dt(entry_field(entry, :last_seen_at), timezone)
      },
      %{
        icon: :active,
        label: dgettext("ui", "Active sessions"),
        value: active_sessions_label(entry_field(entry, :active_sessions))
      },
      %{
        icon: :id,
        label: dgettext("ui", "Terminal ID"),
        value: terminal_id_label(device_id(entry))
      },
      %{
        icon: :fingerprint,
        label: dgettext("ui", "UA"),
        value: short_fingerprint(entry_field(entry, :user_agent_hash))
      },
      %{
        icon: :fingerprint,
        label: dgettext("ui", "IP"),
        value: short_fingerprint(entry_field(entry, :last_ip_hash))
      }
    ]
    |> Enum.reject(&Text.blank?(&1.value))
  end

  defp terminal_label(entry) do
    case entry_field(entry, :label) do
      label when is_binary(label) and label != "" -> label
      _ -> dgettext("ui", "Trusted terminal")
    end
  end

  defp device_id(entry) do
    entry_field(entry, :device_id) || entry_field(entry, :id)
  end

  defp entry_field(entry, field) do
    case Map.fetch(entry, field) do
      {:ok, value} -> value
      :error -> Map.get(entry, Atom.to_string(field))
    end
  end

  defp auto_login_id(entry, nickname) do
    device = device_id(entry) || "unknown"

    nick_or_grant =
      entry_field(entry, :registered_nick_id) || nickname || entry_field(entry, :nickname) ||
        "nick"

    "trusted-auto-login-#{device}-#{nick_or_grant}"
  end

  defp auto_login_testid(%{auto_login_testid: testid}) when is_binary(testid), do: testid

  defp auto_login_testid(%{nickname: nickname}) when is_binary(nickname) and nickname != "" do
    "trusted-auto-login-#{nickname}"
  end

  defp auto_login_testid(%{entry: entry}) do
    "trusted-device-auto-login-#{device_id(entry) || "unknown"}"
  end

  defp default_testid(%{entry: entry, nickname: nickname}) do
    cond do
      is_integer(device_id(entry)) -> "trusted-terminal-#{device_id(entry)}"
      is_binary(nickname) and nickname != "" -> "trusted-terminal-#{nickname}"
      true -> "trusted-terminal"
    end
  end

  defp display_timezone(%{timezone: timezone}) when is_binary(timezone) and timezone != "",
    do: timezone

  defp display_timezone(%{entry: entry}) do
    case entry_field(entry, :timezone) do
      timezone when is_binary(timezone) and timezone != "" -> timezone
      _ -> "Etc/UTC"
    end
  end

  defp card_context(assigns) do
    %{
      entry: assigns.entry,
      nickname: assigns.nickname || entry_field(assigns.entry, :nickname) || "",
      terminal_label: terminal_label(assigns.entry),
      device_id: device_id(assigns.entry),
      current: assigns.current,
      auto_login: entry_field(assigns.entry, :auto_login) == true
    }
  end

  defp device_type_label("desktop"), do: dgettext("ui", "Desktop")
  defp device_type_label("touch"), do: dgettext("ui", "Touch")
  defp device_type_label("unknown"), do: nil
  defp device_type_label(nil), do: nil
  defp device_type_label(type), do: type

  defp color_depth_label(bits) when is_integer(bits) and bits > 0 do
    dgettext("ui", "%{bits}-bit", bits: bits)
  end

  defp color_depth_label(_bits), do: nil

  defp cores_label(count) when is_integer(count) and count > 0 do
    dgettext("ui", "%{count} cores", count: count)
  end

  defp cores_label(_count), do: nil

  defp touch_label(true), do: dgettext("ui", "Touch")
  defp touch_label(false), do: dgettext("ui", "No touch")
  defp touch_label(_value), do: nil

  defp active_sessions_label(count) when is_integer(count), do: Integer.to_string(count)
  defp active_sessions_label(_count), do: nil

  defp terminal_id_label(id) when is_integer(id), do: "##{id}"
  defp terminal_id_label(_id), do: nil

  @doc "The first characters of a hash or reference: enough to tell two apart."
  @spec short_fingerprint(term()) :: String.t() | nil
  def short_fingerprint(nil), do: nil
  def short_fingerprint(""), do: nil

  def short_fingerprint(value) when is_binary(value) do
    String.slice(value, 0, 12)
  end

  def short_fingerprint(_value), do: nil

  @doc "When something happened, in `timezone`; \"Never\" when it has not."
  @spec format_dt(DateTime.t() | nil | term(), String.t()) :: String.t()
  def format_dt(nil, _timezone), do: dgettext("ui", "Never")

  def format_dt(%DateTime{} = dt, timezone),
    do: ChatHelpers.format_time(dt, :dd_mm_hh_mm, timezone)

  def format_dt(_dt, _timezone), do: dgettext("ui", "Unknown")
end
