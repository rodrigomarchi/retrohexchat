defmodule RetroHexChatWeb.Components.UI.P2PConnectionDiagram do
  @moduledoc """
  Animated connection diagram showing the bilateral P2P link between peers.
  Renders browser-specific icons, peer whois info, and an animated
  connection line reflecting the current WebRTC/transfer/call state.
  """
  use RetroHexChatWeb.Component

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
          label={gettext("(you)")}
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
        <svg
          viewBox="0 0 24 24"
          class={"p2p-diagram__browser-svg p2p-diagram__browser-svg--#{@browser_name}"}
          aria-hidden="true"
        >
          <path d={browser_icon_path(@browser_name)} fill="currentColor" />
        </svg>
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
            <svg viewBox="0 0 24 24" class="p2p-diagram__whois-svg" aria-hidden="true">
              <path d={browser_icon_path(@browser_name)} fill="currentColor" />
            </svg>
          </.whois_row>
          <.whois_row :if={@info[:os]} value={@info[:os]}>
            <svg viewBox="0 0 24 24" class="p2p-diagram__whois-svg" aria-hidden="true">
              <path d={os_icon_path(extract_os_name(@info[:os]))} fill="currentColor" />
            </svg>
          </.whois_row>
          <.whois_row :if={@info[:screen]} value={@info[:screen]}>
            <span>🖥</span>
          </.whois_row>
          <.whois_row :if={@info[:language]} value={format_language(@info[:language])}>
            <span>🗣</span>
          </.whois_row>
          <.whois_row :if={@info[:timezone]} value={format_timezone(@info[:timezone])}>
            <span>🕐</span>
          </.whois_row>
          <.whois_row :if={@info[:cores]} value={gettext("%{count} cores", count: @info[:cores])}>
            <span>⚙</span>
          </.whois_row>
          <.whois_row :if={@info[:color_depth]} value={"#{@info[:color_depth]}-bit"}>
            <span>🎨</span>
          </.whois_row>
          <.whois_row :if={@info[:touch] == true} value={gettext("Touch")}>
            <span>👆</span>
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
      <span :if={@diagram_state[:icon]} class="p2p-diagram__badge-icon">{@diagram_state.icon}</span>
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

  # ── Browser icon paths (Simple Icons, viewBox 0 0 24 24) ──

  @chrome_path "M12 0C8.21 0 4.831 1.757 2.632 4.501l3.953 6.848A5.454 5.454 0 0 1 12 6.545h10.691A12 12 0 0 0 12 0zM1.931 5.47A11.943 11.943 0 0 0 0 12c0 6.012 4.42 10.991 10.189 11.864l3.953-6.847a5.45 5.45 0 0 1-6.865-2.29zm13.342 2.166a5.446 5.446 0 0 1 1.45 7.09l.002.001h-.002l-5.344 9.257c.206.01.413.016.621.016 6.627 0 12-5.373 12-12 0-1.54-.29-3.011-.818-4.364zM12 16.364a4.364 4.364 0 1 1 0-8.728 4.364 4.364 0 0 1 0 8.728Z"
  @firefox_path "M20.452 3.445a11.002 11.002 0 00-2.482-1.908C16.944.997 15.098.093 12.477.032c-.734-.017-1.457.03-2.174.144-.72.114-1.398.292-2.118.56-1.017.377-1.996.975-2.574 1.554.583-.349 1.476-.733 2.55-.992a10.083 10.083 0 013.729-.167c2.341.34 4.178 1.381 5.48 2.625a8.066 8.066 0 011.298 1.587c1.468 2.382 1.33 5.376.184 7.142-.85 1.312-2.67 2.544-4.37 2.53-.583-.023-1.438-.152-2.25-.566-2.629-1.343-3.021-4.688-1.118-6.306-.632-.136-1.82.13-2.646 1.363-.742 1.107-.7 2.816-.242 4.028a6.473 6.473 0 01-.59-1.895 7.695 7.695 0 01.416-3.845A8.212 8.212 0 019.45 5.399c.896-1.069 1.908-1.72 2.75-2.005-.54-.471-1.411-.738-2.421-.767C8.31 2.583 6.327 3.061 4.7 4.41a8.148 8.148 0 00-1.976 2.414c-.455.836-.691 1.659-.697 1.678.122-1.445.704-2.994 1.248-4.055-.79.413-1.827 1.668-2.41 3.042C.095 9.37-.2 11.608.14 13.989c.966 5.668 5.9 9.982 11.843 9.982C18.62 23.971 24 18.591 24 11.956a11.93 11.93 0 00-3.548-8.511z"
  @safari_path "M14.19 14.19L6 18l3.81-8.19L18 6m-6-4A10 10 0 0 0 2 12a10 10 0 0 0 10 10a10 10 0 0 0 10-10A10 10 0 0 0 12 2m0 8.9a1.1 1.1 0 0 0-1.1 1.1a1.1 1.1 0 0 0 1.1 1.1a1.1 1.1 0 0 0 1.1-1.1a1.1 1.1 0 0 0-1.1-1.1"
  @edge_path "M8.008 14.001A5 5 0 0 0 8 14.25C8 16.632 9.753 19 13 19c2.373 0 4.528-.655 6-1.553v3.35C17.211 21.564 15.112 22 13 22c-5.502 0-8-3.47-8-7.75c0-3.231 2.041-6 4.943-7.164C8.54 8.663 8 10.341 8 10.996L18 11c0-3.406-2.548-6-6-6c-5 0-8.001 3.988-9 5.999C3.29 6.237 7.01 2 12 2c5.2 0 9 4.03 9 9v3H8z"
  @opera_path "M8.051 5.238c-1.328 1.566-2.186 3.883-2.246 6.48v.564c.061 2.598.918 4.912 2.246 6.479 1.721 2.236 4.279 3.654 7.139 3.654 1.756 0 3.4-.537 4.807-1.471C17.879 22.846 15.074 24 12 24c-.192 0-.383-.004-.57-.014C5.064 23.689 0 18.436 0 12 0 5.371 5.373 0 12 0h.045c3.055.012 5.84 1.166 7.953 3.055-1.408-.93-3.051-1.471-4.81-1.471-2.858 0-5.417 1.42-7.14 3.654h.003zM24 12c0 3.556-1.545 6.748-4.002 8.945-3.078 1.5-5.946.451-6.896-.205 3.023-.664 5.307-4.32 5.307-8.74 0-4.422-2.283-8.075-5.307-8.74.949-.654 3.818-1.703 6.896-.205C22.455 5.25 24 8.445 24 12z"
  @globe_path "M16.36 14c.08-.66.14-1.32.14-2s-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2m-5.15 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 0 1-4.33 3.56M14.34 14H9.66c-.1-.66-.16-1.32-.16-2s.06-1.35.16-2h4.68c.09.65.16 1.32.16 2s-.07 1.34-.16 2M12 19.96c-.83-1.2-1.5-2.53-1.91-3.96h3.82c-.41 1.43-1.08 2.76-1.91 3.96M8 8H5.08A7.92 7.92 0 0 1 9.4 4.44C8.8 5.55 8.35 6.75 8 8m-2.92 8H8c.35 1.25.8 2.45 1.4 3.56A8 8 0 0 1 5.08 16m-.82-2C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2s.06 1.34.14 2M12 4.03c.83 1.2 1.5 2.54 1.91 3.97h-3.82c.41-1.43 1.08-2.77 1.91-3.97M18.92 8h-2.95a15.7 15.7 0 0 0-1.38-3.56c1.84.63 3.37 1.9 4.33 3.56M12 2C6.47 2 2 6.5 2 12a10 10 0 0 0 10 10a10 10 0 0 0 10-10A10 10 0 0 0 12 2"

  @spec browser_icon_path(String.t()) :: String.t()
  defp browser_icon_path("chrome"), do: @chrome_path
  defp browser_icon_path("firefox"), do: @firefox_path
  defp browser_icon_path("safari"), do: @safari_path
  defp browser_icon_path("edge"), do: @edge_path
  defp browser_icon_path("opera"), do: @opera_path
  defp browser_icon_path(_), do: @globe_path

  # ── OS icon paths (Simple Icons / MDI, viewBox 0 0 24 24) ──

  @windows_path "M0 0h11.377v11.372H0zm12.623 0H24v11.372H12.623zM0 12.623h11.377V24H0zm12.623 0H24V24H12.623"
  @apple_path "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"
  @android_path "M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85a.637.637 0 00-.83.22l-1.88 3.24a11.463 11.463 0 00-8.94 0L5.65 5.67a.643.643 0 00-.87-.2c-.28.18-.37.54-.22.83L6.4 9.48A10.78 10.78 0 002 18h20a10.78 10.78 0 00-4.4-8.52zM7 15.25a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5zm10 0a1.25 1.25 0 110-2.5 1.25 1.25 0 010 2.5z"
  @linux_path "M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a.424.424 0 00-.11.135c-.26.268-.45.6-.663.839-.199.199-.485.267-.797.4-.313.136-.658.269-.864.68-.09.189-.136.394-.132.602 0 .199.027.4.055.536.058.399.116.728.04.97-.249.68-.28 1.145-.106 1.484.174.334.535.47.94.601.81.2 1.91.135 2.774.6.926.466 1.866.67 2.616.47.526-.116.97-.464 1.208-.946.587-.003 1.23-.269 2.26-.334.699-.058 1.574.267 2.577.2a1.5 1.5 0 00.114.333c.391.778 1.113 1.132 1.884 1.071.771-.06 1.592-.536 2.257-1.306.631-.765 1.683-1.084 2.378-1.503.348-.199.629-.469.649-.853.023-.4-.2-.811-.714-1.376v-.097c-.17-.2-.25-.535-.338-.926-.085-.401-.182-.786-.492-1.046-.059-.054-.123-.067-.188-.135a.357.357 0 00-.19-.064c.431-1.278.264-2.55-.173-3.694-.533-1.41-1.465-2.638-2.175-3.483-.796-1.005-1.576-1.957-1.56-3.368.026-2.152.236-6.133-3.544-6.139z"

  @spec os_icon_path(String.t()) :: String.t()
  defp os_icon_path("windows"), do: @windows_path
  defp os_icon_path("macos"), do: @apple_path
  defp os_icon_path("ios"), do: @apple_path
  defp os_icon_path("android"), do: @android_path
  defp os_icon_path("linux"), do: @linux_path
  defp os_icon_path("chromeos"), do: @chrome_path
  defp os_icon_path(_), do: @globe_path

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

  @spec extract_os_name(String.t() | nil) :: String.t()
  defp extract_os_name(nil), do: "unknown"

  defp extract_os_name(os) when is_binary(os) do
    os |> String.downcase() |> detect_os_key()
  end

  defp detect_os_key(o) do
    cond do
      String.starts_with?(o, "windows") -> "windows"
      String.starts_with?(o, "macos") -> "macos"
      String.starts_with?(o, "ios") -> "ios"
      String.starts_with?(o, "android") -> "android"
      String.starts_with?(o, "chromeos") -> "chromeos"
      String.starts_with?(o, "linux") -> "linux"
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
          label: ft[:file_name] || gettext("File"),
          icon: "📄",
          sub_label:
            gettext("%{speed} — %{percent}%",
              speed: ft[:speed] || gettext("0 B/s"),
              percent: percent
            ),
          progress: percent,
          direction: direction,
          percent: percent,
          dots: 5,
          cycle_ms: 800
        }

      "verifying" ->
        %{id: "verifying", label: gettext("Verifying..."), icon: "🔍", sub_label: ft[:file_name]}

      _ ->
        nil
    end
  end

  defp derive_file_transfer_state(_), do: nil

  defp derive_call_state(%{call: call}) when is_map(call) do
    sub =
      gettext("%{duration} — %{quality}",
        duration: call[:duration] || "00:00:00",
        quality: call[:quality_label] || gettext("Starting")
      )

    case call[:type] do
      "video" ->
        %{
          id: "video-call",
          label: gettext("Video Call"),
          icon: "📹",
          sub_label: sub,
          direction: "bidi",
          dots: 5,
          cycle_ms: 1000
        }

      "audio" ->
        %{
          id: "audio-call",
          label: gettext("Audio Call"),
          icon: "🎤",
          sub_label: sub,
          direction: "bidi",
          dots: 4,
          cycle_ms: 1400
        }

      _ ->
        %{id: "call-init", label: gettext("Starting call..."), icon: "📞"}
    end
  end

  defp derive_call_state(_), do: nil

  defp derive_webrtc_state(%{webrtc_state: "Connected"}),
    do: %{id: "connected", label: gettext("Connected"), icon: "✓"}

  defp derive_webrtc_state(%{webrtc_state: "Connecting..."}),
    do: %{id: "connecting", label: gettext("Connecting..."), direction: "bidi"}

  defp derive_webrtc_state(%{webrtc_state: "Reconnecting...", retry_attempt: attempt}) do
    label =
      if attempt do
        gettext("Reconnecting (%{attempt}/3)", attempt: attempt)
      else
        gettext("Reconnecting")
      end

    %{id: "reconnecting", label: label, direction: "bidi"}
  end

  defp derive_webrtc_state(%{webrtc_state: "Connection failed"}),
    do: %{id: "failed", label: gettext("Failed"), icon: "✗"}

  defp derive_webrtc_state(_), do: nil

  defp derive_session_state(%{session_status: "connecting"}),
    do: %{id: "connecting", label: gettext("Connecting..."), direction: "bidi"}

  defp derive_session_state(%{session_status: status})
       when status in ~w(closed expired failed),
       do: %{id: "disconnected", label: gettext("Disconnected")}

  defp derive_session_state(%{peer_online: true}),
    do: %{id: "ready", label: gettext("Ready")}

  defp derive_session_state(_),
    do: %{id: "waiting", label: gettext("Waiting...")}

  @spec peer_status_label(map(), :local | :remote) :: String.t() | nil
  defp peer_status_label(%{id: "transferring", direction: "ltr"}, :local), do: gettext("Sending")

  defp peer_status_label(%{id: "transferring", direction: "rtl"}, :local),
    do: gettext("Receiving")

  defp peer_status_label(%{id: "transferring", direction: "ltr"}, :remote),
    do: gettext("Receiving")

  defp peer_status_label(%{id: "transferring", direction: "rtl"}, :remote), do: gettext("Sending")

  defp peer_status_label(%{id: id}, _side) when id in ["audio-call", "video-call"],
    do: gettext("In Call")

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
