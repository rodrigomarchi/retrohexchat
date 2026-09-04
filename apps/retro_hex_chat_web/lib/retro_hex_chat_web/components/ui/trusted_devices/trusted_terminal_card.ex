defmodule RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard do
  @moduledoc """
  Shared trusted-terminal card used anywhere a remembered device identity is shown.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Card
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Switch

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Timezone

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
      |> assign(:primary_specs, primary_specs(assigns.entry))
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
          <span class="inline-flex h-12 w-12 shrink-0 items-center justify-center bg-canvas shadow-retro-sunken">
            <Icons.icon_laptop class="h-8 w-8" />
          </span>

          <div class="min-w-0">
            <div class="mb-retro-4 flex min-w-0 flex-wrap items-center gap-retro-3">
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
            <div class="mt-retro-3 flex min-w-0 flex-wrap items-center gap-retro-3">
              <span :if={@nickname != ""} class="inline-flex min-w-0 items-center gap-retro-3">
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

          <div :if={@show_auto_login_toggle} class="flex items-center gap-retro-4">
            <.switch
              id={@auto_login_id}
              value={@auto_login}
              on_toggle={@on_auto_login_toggle}
              target={@auto_login_target}
              event_value={
                %{
                  nickname: @nickname,
                  device_id: @device_id,
                  enabled: not @auto_login
                }
              }
              testid={@auto_login_testid}
            />
            <.label for={@auto_login_id} class="text-[11px]">
              {dgettext("ui", "Auto-login")}
            </.label>
          </div>
        </div>
      </div>

      <div
        :if={@primary_specs != []}
        class="mt-3 flex flex-wrap gap-retro-3 border-t border-border pt-2"
      >
        <.terminal_spec_badge :for={spec <- @primary_specs} spec={spec} />
      </div>

      <div
        :if={@trust_specs != []}
        class="mt-3 grid gap-retro-3 border-t border-border pt-2 sm:grid-cols-3"
      >
        <.terminal_fact :for={fact <- @trust_specs} fact={fact} />
      </div>

      <div
        :if={@show_audit_metadata and @audit_specs != []}
        class="mt-3 grid gap-retro-3 border-t border-border pt-2 sm:grid-cols-2 lg:grid-cols-3"
      >
        <.terminal_fact :for={fact <- @audit_specs} fact={fact} />
      </div>

      <div :if={@management != []} class="mt-3 border-t border-border pt-2">
        {render_slot(@management, @card_context)}
      </div>
    </.card>
    """
  end

  attr :spec, :map, required: true

  defp terminal_spec_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class="max-w-full">
      <:icon><.trusted_terminal_icon icon={@spec.icon} class="h-3 w-3" /></:icon>
      <span class="truncate">{@spec.value}</span>
    </.badge>
    """
  end

  attr :fact, :map, required: true

  defp terminal_fact(assigns) do
    ~H"""
    <span class="inline-flex min-w-0 items-center gap-retro-3 bg-white px-1 py-px shadow-retro-status">
      <.trusted_terminal_icon icon={@fact.icon} class="h-3.5 w-3.5 shrink-0" />
      <span class="shrink-0 font-bold">{@fact.label}:</span>
      <span class="min-w-0 truncate text-muted-foreground">{@fact.value}</span>
    </span>
    """
  end

  attr :icon, :atom, required: true
  attr :class, :string, default: nil

  defp trusted_terminal_icon(%{icon: :browser} = assigns),
    do: ~H"<Icons.icon_browser class={@class} />"

  defp trusted_terminal_icon(%{icon: :os} = assigns),
    do: ~H"<Icons.icon_operating_system class={@class} />"

  defp trusted_terminal_icon(%{icon: :display} = assigns),
    do: ~H"<Icons.icon_tab_display class={@class} />"

  defp trusted_terminal_icon(%{icon: :timezone} = assigns),
    do: ~H"<Icons.icon_globe class={@class} />"

  defp trusted_terminal_icon(%{icon: :type} = assigns),
    do: ~H"<Icons.icon_devices class={@class} />"

  defp trusted_terminal_icon(%{icon: :language} = assigns),
    do: ~H"<Icons.icon_globe class={@class} />"

  defp trusted_terminal_icon(%{icon: :color_depth} = assigns),
    do: ~H"<Icons.icon_palette class={@class} />"

  defp trusted_terminal_icon(%{icon: :cores} = assigns),
    do: ~H"<Icons.icon_database class={@class} />"

  defp trusted_terminal_icon(%{icon: :grant} = assigns),
    do: ~H"<Icons.icon_shield class={@class} />"

  defp trusted_terminal_icon(%{icon: :connect} = assigns),
    do: ~H"<Icons.icon_connect class={@class} />"

  defp trusted_terminal_icon(%{icon: :expires} = assigns),
    do: ~H"<Icons.icon_warning class={@class} />"

  defp trusted_terminal_icon(%{icon: :touch} = assigns),
    do: ~H"<Icons.icon_call_devices class={@class} />"

  defp trusted_terminal_icon(%{icon: :first_seen} = assigns),
    do: ~H"<Icons.icon_clock class={@class} />"

  defp trusted_terminal_icon(%{icon: :last_seen} = assigns),
    do: ~H"<Icons.icon_btn_refresh class={@class} />"

  defp trusted_terminal_icon(%{icon: :active} = assigns),
    do: ~H"<Icons.icon_status_signal class={@class} />"

  defp trusted_terminal_icon(%{icon: :id} = assigns),
    do: ~H"<Icons.icon_tag class={@class} />"

  defp trusted_terminal_icon(%{icon: :fingerprint} = assigns),
    do: ~H"<Icons.icon_tag class={@class} />"

  defp trusted_terminal_icon(assigns), do: ~H"<Icons.icon_tag class={@class} />"

  defp primary_specs(entry) do
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
    |> Enum.reject(&(blank?(&1.value) or &1.value == "unknown"))
  end

  defp trust_specs(entry, timezone) do
    [
      %{
        icon: :connect,
        label: dgettext("ui", "Used"),
        value: format_dt(entry_field(entry, :last_used_at), timezone)
      },
      %{
        icon: :grant,
        label: dgettext("ui", "Remembered"),
        value: format_dt(entry_field(entry, :granted_at), timezone)
      },
      %{
        icon: :expires,
        label: dgettext("ui", "Expires"),
        value: format_dt(entry_field(entry, :expires_at), timezone)
      }
    ]
  end

  defp audit_specs(entry, timezone) do
    [
      %{
        icon: :first_seen,
        label: dgettext("ui", "First"),
        value: format_dt(entry_field(entry, :first_seen_at), timezone)
      },
      %{
        icon: :last_seen,
        label: dgettext("ui", "Last"),
        value: format_dt(entry_field(entry, :last_seen_at), timezone)
      },
      %{
        icon: :active,
        label: dgettext("ui", "Active"),
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
    |> Enum.reject(&blank?(&1.value))
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

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

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

  defp short_fingerprint(nil), do: nil
  defp short_fingerprint(""), do: nil

  defp short_fingerprint(value) when is_binary(value) do
    String.slice(value, 0, 12)
  end

  defp short_fingerprint(_value), do: nil

  defp format_dt(nil, _timezone), do: dgettext("ui", "Never")

  defp format_dt(%DateTime{} = dt, timezone) do
    dt
    |> Timezone.shift(timezone)
    |> Calendar.strftime("%d/%m %H:%M")
  end

  defp format_dt(_dt, _timezone), do: dgettext("ui", "Unknown")
end
