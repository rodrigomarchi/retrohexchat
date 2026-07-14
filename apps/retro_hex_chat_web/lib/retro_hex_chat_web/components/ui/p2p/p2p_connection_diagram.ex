defmodule RetroHexChatWeb.Components.UI.P2PConnectionDiagram do
  @moduledoc """
  Animated connection diagram showing the bilateral P2P link between peers.
  Renders browser-specific icons, peer whois info, and an animated
  connection line reflecting the current WebRTC/transfer/call state.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :session_status, :string, required: true
  attr :webrtc_state, :string, default: nil
  attr :retry_attempt, :integer, default: nil
  attr :file_transfer, :map, default: nil
  attr :call, :map, default: nil
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}

  @spec p2p_connection_diagram(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_connection_diagram(assigns) do
    state = derive_diagram_state(assigns)
    assigns = assign(assigns, :diagram_state, state)

    ~H"""
    <div
      id="p2p-diagram"
      class="p2p-diagram"
      phx-hook="P2PDiagramHook"
      data-state={@diagram_state.id}
      data-direction={@diagram_state[:direction] || "none"}
      data-percent={@diagram_state[:percent] || "0"}
      data-dots={@diagram_state[:dots] || "3"}
      data-cycle-ms={@diagram_state[:cycle_ms] || "1200"}
    >
      <div class="p2p-diagram__peers">
        <.peer_panel
          nick={@nickname}
          label={dgettext("p2p", "(you)")}
          online={true}
          status_label={peer_status_label(@diagram_state, :local)}
          info={@local_info}
          side="left"
        />

        <div class={"p2p-diagram__link p2p-diagram__link--#{@diagram_state.id}"}>
          <div class="p2p-diagram__line-container">
            <div class="p2p-diagram__line"></div>
            <div class="p2p-diagram__dots">
              <span class="p2p-diagram__dot"></span>
              <span class="p2p-diagram__dot"></span>
              <span class="p2p-diagram__dot"></span>
            </div>
          </div>
          <.center_badge diagram_state={@diagram_state} />
        </div>

        <.peer_panel
          nick={@peer_nick}
          online={@peer_online}
          status_label={peer_status_label(@diagram_state, :remote)}
          info={@peer_info}
          side="right"
        />
      </div>
    </div>
    """
  end

  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, required: true
  attr :session_status, :string, required: true
  attr :webrtc_state, :string, default: nil
  attr :retry_attempt, :integer, default: nil
  attr :file_transfer, :map, default: nil
  attr :call, :map, default: nil
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}

  @spec p2p_connection_strip(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_connection_strip(assigns) do
    state = derive_diagram_state(assigns)

    assigns =
      assigns
      |> assign(:diagram_state, state)
      |> assign(:local_browser_name, extract_browser_name(assigns.local_info[:browser]))
      |> assign(:peer_browser_name, extract_browser_name(assigns.peer_info[:browser]))

    ~H"""
    <div
      id="p2p-diagram-compact"
      class={"p2p-diagram-strip p2p-diagram-strip--#{@diagram_state.id}"}
      data-testid="p2p-diagram-compact"
      data-state={@diagram_state.id}
    >
      <.strip_peer
        nick={@nickname}
        label={dgettext("p2p", "you")}
        online={true}
        browser_name={@local_browser_name}
        status_label={peer_status_label(@diagram_state, :local)}
      />

      <div class="p2p-diagram-strip__route">
        <Icons.icon_p2p_route class="p2p-diagram-strip__svg" />
        <div class="p2p-diagram-strip__badge">
          <span class="p2p-diagram-strip__label">{@diagram_state.label}</span>
          <span :if={@diagram_state[:sub_label]} class="p2p-diagram-strip__sub">
            {@diagram_state.sub_label}
          </span>
        </div>
      </div>

      <.strip_peer
        nick={@peer_nick}
        online={@peer_online}
        browser_name={@peer_browser_name}
        status_label={peer_status_label(@diagram_state, :remote)}
      />
    </div>
    """
  end

  attr :nick, :string, required: true
  attr :label, :string, default: nil
  attr :online, :boolean, required: true
  attr :browser_name, :string, required: true
  attr :status_label, :string, default: nil

  defp strip_peer(assigns) do
    ~H"""
    <div class="p2p-diagram-strip__peer">
      <span class={[
        "p2p-diagram__status-dot",
        @online && "p2p-diagram__status-dot--online",
        !@online && "p2p-diagram__status-dot--offline"
      ]}>
      </span>
      <Icons.icon_browser class={"p2p-diagram-strip__browser p2p-diagram__browser-svg--#{@browser_name}"} />
      <span class="p2p-diagram-strip__nick">{@nick}</span>
      <span :if={@label} class="p2p-diagram-strip__you">({@label})</span>
      <span :if={@status_label} class="p2p-diagram-strip__peer-status">{@status_label}</span>
    </div>
    """
  end

  # --- Peer Panel ---

  attr :nick, :string, required: true
  attr :label, :string, default: nil
  attr :online, :boolean, required: true
  attr :status_label, :string, default: nil
  attr :info, :map, required: true
  attr :side, :string, required: true

  defp peer_panel(assigns) do
    browser_name = extract_browser_name(assigns.info[:browser])
    assigns = assign(assigns, :browser_name, browser_name)

    ~H"""
    <div class={"p2p-diagram__peer p2p-diagram__peer--#{@side}"}>
      <div class="p2p-diagram__browser-icon">
        <Icons.icon_browser class={"p2p-diagram__browser-svg p2p-diagram__browser-svg--#{@browser_name}"} />
      </div>
      <div class="p2p-diagram__peer-info">
        <div class="p2p-diagram__peer-header">
          <span class={[
            "p2p-diagram__status-dot",
            @online && "p2p-diagram__status-dot--online",
            !@online && "p2p-diagram__status-dot--offline"
          ]}>
          </span>
          <span class="p2p-diagram__nick">{@nick}</span>
          <span :if={@label} class="p2p-diagram__you-label">{@label}</span>
        </div>
        <span :if={@status_label} class="p2p-diagram__peer-status">{@status_label}</span>
        <div class="p2p-diagram__whois">
          <.whois_row :if={@info[:browser]} value={@info[:browser]}>
            <Icons.icon_browser class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:os]} value={@info[:os]}>
            <Icons.icon_operating_system class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:screen]} value={@info[:screen]}>
            <Icons.icon_laptop class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:language]} value={format_language(@info[:language])}>
            <Icons.icon_globe class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:timezone]} value={format_timezone(@info[:timezone])}>
            <Icons.icon_clock class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row
            :if={@info[:cores]}
            value={dgettext("p2p", "%{count} cores", count: @info[:cores])}
          >
            <Icons.icon_server class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:color_depth]} value={"#{@info[:color_depth]}-bit"}>
            <Icons.icon_palette class="p2p-diagram__whois-svg" />
          </.whois_row>
          <.whois_row :if={@info[:touch] == true} value={dgettext("p2p", "Touch")}>
            <Icons.icon_devices class="p2p-diagram__whois-svg" />
          </.whois_row>
        </div>
      </div>
    </div>
    """
  end

  # --- Whois Row ---

  attr :value, :string, required: true
  slot :inner_block, required: true

  defp whois_row(assigns) do
    ~H"""
    <div class="p2p-diagram__whois-row">
      <span class="p2p-diagram__whois-icon">
        {render_slot(@inner_block)}
      </span>
      <span class="p2p-diagram__whois-value">{@value}</span>
    </div>
    """
  end

  # --- Center Badge ---

  attr :diagram_state, :map, required: true

  defp center_badge(assigns) do
    ~H"""
    <div class={"p2p-diagram__badge p2p-diagram__badge--#{@diagram_state.id}"}>
      <span :if={@diagram_state[:icon]} class="p2p-diagram__badge-icon">
        <.inline_icon name={@diagram_state.icon} class="h-4 w-4" />
      </span>
      <span class="p2p-diagram__badge-text">{@diagram_state.label}</span>
      <div :if={@diagram_state[:sub_label]} class="p2p-diagram__badge-sub">
        {@diagram_state.sub_label}
      </div>
      <div :if={@diagram_state[:progress]} class="p2p-diagram__badge-progress">
        <div class="p2p-diagram__badge-bar">
          <div class="p2p-diagram__badge-bar-fill" style={"--progress: #{@diagram_state.progress}%"}>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp inline_icon(assigns) do
    ~H"""
    {apply(Icons, @name, [%{class: @class}])}
    """
  end

  # ── Name extraction ──

  @spec extract_browser_name(String.t() | nil) :: String.t()
  defp extract_browser_name(nil), do: "unknown"

  defp extract_browser_name(browser) when is_binary(browser) do
    browser |> String.downcase() |> detect_browser_key()
  end

  defp detect_browser_key(b) do
    cond do
      String.starts_with?(b, "chrome") -> "chrome"
      String.starts_with?(b, "firefox") -> "firefox"
      String.starts_with?(b, "safari") -> "safari"
      String.starts_with?(b, "edge") -> "edge"
      String.starts_with?(b, "opera") -> "opera"
      true -> "unknown"
    end
  end

  # ── State Derivation ──

  @spec derive_diagram_state(map()) :: map()
  defp derive_diagram_state(assigns) do
    derive_file_transfer_state(assigns) ||
      derive_call_state(assigns) ||
      derive_webrtc_state(assigns) ||
      derive_session_state(assigns)
  end

  defp derive_file_transfer_state(%{file_transfer: ft, nickname: nick})
       when is_map(ft) do
    case ft[:status] do
      status when status in ["transferring", "resuming"] ->
        direction = if ft[:sender_nick] == nick, do: "ltr", else: "rtl"
        percent = ft[:percent] || 0

        %{
          id: "transferring",
          label: ft[:file_name] || dgettext("p2p", "File"),
          icon: :icon_file_send,
          sub_label:
            dgettext("p2p", "%{speed} — %{percent}%",
              speed: ft[:speed] || dgettext("p2p", "0 B/s"),
              percent: percent
            ),
          progress: percent,
          direction: direction,
          percent: percent,
          dots: 5,
          cycle_ms: 800
        }

      "verifying" ->
        %{
          id: "verifying",
          label: dgettext("p2p", "Verifying..."),
          icon: :icon_btn_search,
          sub_label: ft[:file_name]
        }

      _ ->
        nil
    end
  end

  defp derive_file_transfer_state(_), do: nil

  defp derive_call_state(%{call: call}) when is_map(call) do
    sub =
      dgettext("p2p", "%{duration} — %{quality}",
        duration: call[:duration] || "00:00:00",
        quality: call[:quality_label] || dgettext("p2p", "Starting")
      )

    case call[:type] do
      "video" ->
        %{
          id: "video-call",
          label: dgettext("p2p", "Video Call"),
          icon: :icon_camera,
          sub_label: sub,
          direction: "bidi",
          dots: 5,
          cycle_ms: 1000
        }

      "audio" ->
        %{
          id: "audio-call",
          label: dgettext("p2p", "Audio Call"),
          icon: :icon_microphone,
          sub_label: sub,
          direction: "bidi",
          dots: 4,
          cycle_ms: 1400
        }

      _ ->
        %{
          id: "call-init",
          label: dgettext("p2p", "Starting call..."),
          icon: :icon_protocol_p2p_compact
        }
    end
  end

  defp derive_call_state(_), do: nil

  defp derive_webrtc_state(%{webrtc_state: "Connected"}),
    do: %{id: "connected", label: dgettext("p2p", "Connected"), icon: :icon_checkmark}

  defp derive_webrtc_state(%{webrtc_state: "Connecting..."}),
    do: %{id: "connecting", label: dgettext("p2p", "Connecting..."), direction: "bidi"}

  defp derive_webrtc_state(%{webrtc_state: "Reconnecting...", retry_attempt: attempt}) do
    label =
      if attempt do
        dgettext("p2p", "Reconnecting (%{attempt}/3)", attempt: attempt)
      else
        dgettext("p2p", "Reconnecting")
      end

    %{id: "reconnecting", label: label, direction: "bidi"}
  end

  defp derive_webrtc_state(%{webrtc_state: "Connection failed"}),
    do: %{id: "failed", label: dgettext("p2p", "Failed"), icon: :icon_close}

  defp derive_webrtc_state(_), do: nil

  defp derive_session_state(%{session_status: "connecting"}),
    do: %{id: "connecting", label: dgettext("p2p", "Connecting..."), direction: "bidi"}

  defp derive_session_state(%{session_status: status})
       when status in ~w(closed expired failed),
       do: %{id: "disconnected", label: dgettext("p2p", "Disconnected")}

  defp derive_session_state(%{peer_online: true}),
    do: %{id: "ready", label: dgettext("p2p", "Ready")}

  defp derive_session_state(_),
    do: %{id: "waiting", label: dgettext("p2p", "Waiting...")}

  @spec peer_status_label(map(), :local | :remote) :: String.t() | nil
  defp peer_status_label(%{id: "transferring", direction: "ltr"}, :local),
    do: dgettext("p2p", "Sending")

  defp peer_status_label(%{id: "transferring", direction: "rtl"}, :local),
    do: dgettext("p2p", "Receiving")

  defp peer_status_label(%{id: "transferring", direction: "ltr"}, :remote),
    do: dgettext("p2p", "Receiving")

  defp peer_status_label(%{id: "transferring", direction: "rtl"}, :remote),
    do: dgettext("p2p", "Sending")

  defp peer_status_label(%{id: id}, _side) when id in ["audio-call", "video-call"],
    do: dgettext("p2p", "In Call")

  defp peer_status_label(_state, _side), do: nil

  @spec format_language(String.t()) :: String.t()
  defp format_language(lang) when is_binary(lang) do
    case String.split(lang, "-") do
      [code, region] -> "#{String.upcase(code)}-#{String.upcase(region)}"
      [code] -> String.upcase(code)
      _ -> lang
    end
  end

  defp format_language(_), do: ""

  @spec format_timezone(String.t()) :: String.t()
  defp format_timezone(tz) when is_binary(tz) do
    tz |> String.replace("_", " ") |> String.split("/") |> List.last()
  end

  defp format_timezone(_), do: ""
end
