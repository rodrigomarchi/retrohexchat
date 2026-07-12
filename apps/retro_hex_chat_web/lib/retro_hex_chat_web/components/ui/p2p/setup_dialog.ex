defmodule RetroHexChatWeb.Components.UI.P2P.SetupDialog do
  @moduledoc """
  Presentation-only setup dialog for accepting an in-chat P2P session.

  P2P is more than a call, so this setup chooses the initial media posture for
  the session without joining channel-style moderation semantics.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Components.UI.GroupCall.DeviceSelect
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :setup, :map, default: nil
  attr :on_accept, :any, default: "p2p_setup_accept"
  attr :on_cancel, :any, default: "p2p_setup_cancel"

  @spec p2p_setup_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_setup_dialog(assigns) do
    turn_configured = turn_configured?(assigns.setup)

    assigns =
      assigns
      |> assign(:show, is_map(assigns.setup))
      |> assign(:outgoing?, outgoing?(assigns.setup))
      |> assign(:peer, peer(assigns.setup))
      |> assign(:media_mode, media_mode(assigns.setup))
      |> assign(:media, media(assigns.setup))
      |> assign(:devices, devices(assigns.setup))
      |> assign(:device_preferences, device_preferences(assigns.setup))
      |> assign(:turn_configured, turn_configured)
      |> assign(:turn_only, turn_configured and turn_only?(assigns.setup))

    ~H"""
    <span data-testid="p2p-setup-dialog">
      <.dialog id={@id} show={@show} on_cancel={@on_cancel}>
        <.dialog_header
          id={@id}
          title={setup_title(@outgoing?)}
          on_close={@on_cancel}
        >
          <:icon><Icons.icon_p2p class="h-4 w-4" /></:icon>
        </.dialog_header>

        <.form
          :if={@show}
          id="p2p-setup-form"
          for={%{}}
          as={:p2p_setup}
          phx-submit={@on_accept}
          class="contents"
          data-testid="p2p-setup-form"
        >
          <.dialog_body class="w-full md:w-[560px]">
            <div class="grid gap-2 text-xs md:grid-cols-[220px_1fr]">
              <.setup_preview
                media={@media}
                setup={@setup}
                device_preferences={@device_preferences}
              />

              <section class="grid min-w-0 gap-2">
                <section class="grid gap-2 border border-border bg-canvas p-2 shadow-retro-sunken">
                  <div class="flex items-center gap-2">
                    <span class="flex h-9 w-9 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
                      <Icons.icon_status_user class="h-5 w-5" />
                    </span>
                    <div class="min-w-0">
                      <div class="font-bold">
                        {dgettext("p2p", "Connect with %{peer}", peer: @peer)}
                      </div>
                      <p class="text-muted-foreground">
                        {setup_description(@outgoing?)}
                      </p>
                    </div>
                  </div>
                </section>

                <section class="grid gap-2 border border-border bg-canvas p-2 shadow-retro-sunken">
                  <div class="flex items-center gap-1 font-bold">
                    <Icons.icon_devices class="h-3.5 w-3.5" />
                    {dgettext("p2p", "Initial media")}
                  </div>

                  <.toggle_row
                    name="p2p_setup[audio]"
                    checked={@media.audio}
                    icon={:icon_microphone}
                    label={dgettext("p2p", "Start with microphone")}
                    testid="p2p-setup-audio"
                  />
                  <.toggle_row
                    name="p2p_setup[video]"
                    checked={@media.video}
                    icon={:icon_camera}
                    label={dgettext("p2p", "Start with camera")}
                    testid="p2p-setup-video"
                  />
                  <div class="flex items-start gap-1 text-muted-foreground">
                    <Icons.icon_mute class="mt-[1px] h-3.5 w-3.5 shrink-0" />
                    {dgettext(
                      "p2p",
                      "Turn both off to join receive-only and start media later."
                    )}
                  </div>
                </section>

                <section class="grid gap-2 border border-border bg-canvas p-2 shadow-retro-sunken">
                  <DeviceSelect.device_select
                    name="p2p_setup[audio_input_id]"
                    value={@device_preferences.audio_input_id}
                    kind="audioinput"
                    devices={@devices["audioinput"]}
                    icon={:icon_microphone}
                    label={dgettext("p2p", "Microphone")}
                    testid="p2p-setup-audio-input"
                  />
                  <DeviceSelect.device_select
                    name="p2p_setup[video_input_id]"
                    value={@device_preferences.video_input_id}
                    kind="videoinput"
                    devices={@devices["videoinput"]}
                    icon={:icon_camera}
                    label={dgettext("p2p", "Camera")}
                    testid="p2p-setup-video-input"
                  />
                  <DeviceSelect.device_select
                    name="p2p_setup[audio_output_id]"
                    value={@device_preferences.audio_output_id}
                    kind="audiooutput"
                    devices={@devices["audiooutput"]}
                    icon={:icon_devices}
                    label={dgettext("p2p", "Speaker")}
                    testid="p2p-setup-audio-output"
                  />
                </section>

                <section class="grid gap-2 border border-border bg-canvas p-2 shadow-retro-sunken">
                  <label class="flex items-start gap-2">
                    <input type="hidden" name="p2p_setup[turn_only]" value="false" />
                    <input
                      type="checkbox"
                      name="p2p_setup[turn_only]"
                      value="true"
                      checked={@turn_only}
                      disabled={!@turn_configured}
                      class="retro-checkbox mt-0.5 shrink-0"
                      data-testid="p2p-setup-turn-only"
                    />
                    <span class="grid min-w-0 gap-0.5">
                      <span class="inline-flex items-center gap-1 font-bold">
                        <Icons.icon_privacy class="h-3.5 w-3.5" />
                        {dgettext("p2p", "Privacy relay")}
                      </span>
                      <span class="text-muted-foreground">
                        {privacy_copy(@turn_configured)}
                      </span>
                    </span>
                  </label>
                </section>
              </section>
            </div>
          </.dialog_body>

          <.dialog_footer>
            <.button type="submit" data-testid="p2p-setup-accept">
              <:icon><Icons.icon_btn_join class="h-4 w-4" /></:icon>
              {setup_submit_label(@outgoing?)}
            </.button>
            <.button
              type="button"
              variant="outline"
              phx-click={@on_cancel}
              data-testid="p2p-setup-cancel"
            >
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("p2p", "Cancel")}
            </.button>
          </.dialog_footer>
        </.form>
      </.dialog>
    </span>
    """
  end

  attr :media, :map, required: true
  attr :setup, :map, required: true
  attr :device_preferences, :map, required: true

  defp setup_preview(assigns) do
    ~H"""
    <section
      id="p2p-setup-preview"
      phx-hook="P2PSetupHook"
      data-prejoin-prefix="p2p-setup"
      data-form-name="p2p_setup"
      data-devices-event="p2p_setup_devices_listed"
      data-preferences-event="p2p_setup_preferences_loaded"
      data-storage-key="rhc:p2p:setup"
      data-preference-scope={preference_scope(@setup)}
      data-audio={to_string(@media.audio)}
      data-video={to_string(@media.video)}
      data-audio-input-id={device_preference(@device_preferences, :audio_input_id)}
      data-video-input-id={device_preference(@device_preferences, :video_input_id)}
      data-audio-output-id={device_preference(@device_preferences, :audio_output_id)}
      class="flex min-h-[170px] flex-col border border-border bg-canvas p-1 shadow-retro-sunken"
      data-testid="p2p-setup-preview"
    >
      <div class="mb-1 flex items-center justify-between gap-2 text-xs">
        <span class="inline-flex min-w-0 items-center gap-1 font-bold">
          <Icons.icon_camera class="h-3.5 w-3.5 shrink-0" />
          <span class="truncate">{dgettext("p2p", "Preview")}</span>
        </span>
        <span class="inline-flex items-center gap-1 text-muted-foreground" data-p2p-setup-device-state>
          <Icons.icon_devices class="h-3 w-3" />
          <span data-p2p-setup-device-state-text>{dgettext("p2p", "Checking devices")}</span>
        </span>
      </div>

      <div class="relative flex min-h-0 flex-1 items-center justify-center bg-black">
        <video
          data-p2p-setup-video
          autoplay
          muted
          playsinline
          class="h-full max-h-[150px] w-full object-contain"
          data-testid="p2p-setup-preview-video"
        >
        </video>
        <div
          class="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-canvas text-center text-xs text-muted-foreground"
          data-p2p-setup-empty
          data-testid="p2p-setup-preview-empty"
        >
          <Icons.icon_camera_off class="h-5 w-5" />
          <span data-p2p-setup-empty-text>{dgettext("p2p", "Camera preview is off")}</span>
        </div>
      </div>

      <div
        class="mt-1 hidden items-start gap-1 border border-warning bg-surface px-1 py-1 text-[10px] text-warning"
        data-p2p-setup-warning
        data-testid="p2p-setup-warning"
      >
        <Icons.icon_warning class="mt-[1px] h-3 w-3 shrink-0" />
        <span data-p2p-setup-warning-text></span>
        <button
          type="button"
          class="ml-auto inline-flex h-5 shrink-0 items-center gap-1 border border-border bg-surface px-1 text-[10px] font-bold shadow-retro-raised"
          data-p2p-setup-retry
          data-testid="p2p-setup-retry"
        >
          <Icons.icon_btn_refresh class="h-3 w-3" />
          {dgettext("p2p", "Retry")}
        </button>
      </div>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :checked, :boolean, required: true
  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :testid, :string, required: true

  defp toggle_row(assigns) do
    ~H"""
    <label class="flex items-center gap-2">
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        name={@name}
        value="true"
        checked={@checked}
        class="retro-checkbox shrink-0"
        data-testid={@testid}
      />
      <span class="inline-flex min-w-0 items-center gap-1">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </span>
    </label>
    """
  end

  @spec peer(map() | nil) :: String.t()
  defp peer(%{peer_nick: peer}) when is_binary(peer) and peer != "", do: peer
  defp peer(%{created_by: peer}) when is_binary(peer) and peer != "", do: peer
  defp peer(_setup), do: dgettext("p2p", "peer")

  @spec outgoing?(map() | nil) :: boolean()
  defp outgoing?(%{kind: :outgoing}), do: true
  defp outgoing?(_setup), do: false

  @spec setup_title(boolean()) :: String.t()
  defp setup_title(true), do: dgettext("p2p", "Prepare P2P Invite")
  defp setup_title(false), do: dgettext("p2p", "Start P2P Session")

  @spec setup_description(boolean()) :: String.t()
  defp setup_description(true) do
    dgettext(
      "p2p",
      "The invite is sent after this setup. These media defaults apply when your peer accepts."
    )
  end

  defp setup_description(false) do
    dgettext(
      "p2p",
      "The private message, files, games and statistics become available after you join."
    )
  end

  @spec setup_submit_label(boolean()) :: String.t()
  defp setup_submit_label(true), do: dgettext("p2p", "Send invite")
  defp setup_submit_label(false), do: dgettext("p2p", "Join session")

  @spec media_mode(map() | nil) :: String.t()
  defp media_mode(%{media_mode: mode}) when mode in ~w(video audio receive), do: mode
  defp media_mode(_setup), do: "video"

  @spec media(map() | nil) :: %{audio: boolean(), video: boolean()}
  defp media(%{media: %{audio: audio, video: video}}), do: %{audio: audio, video: video}
  defp media(%{media_mode: "audio"}), do: %{audio: true, video: false}
  defp media(%{media_mode: "receive"}), do: %{audio: false, video: false}
  defp media(_setup), do: %{audio: true, video: true}

  @spec devices(map() | nil) :: map()
  defp devices(%{devices: devices}) when is_map(devices) do
    Map.merge(%{"audioinput" => [], "videoinput" => [], "audiooutput" => []}, devices)
  end

  defp devices(_setup), do: %{"audioinput" => [], "videoinput" => [], "audiooutput" => []}

  @spec device_preferences(map() | nil) :: map()
  defp device_preferences(%{device_preferences: preferences}) when is_map(preferences) do
    %{
      audio_input_id: Map.get(preferences, :audio_input_id),
      video_input_id: Map.get(preferences, :video_input_id),
      audio_output_id: Map.get(preferences, :audio_output_id)
    }
  end

  defp device_preferences(_setup) do
    %{audio_input_id: nil, video_input_id: nil, audio_output_id: nil}
  end

  @spec turn_only?(map() | nil) :: boolean()
  defp turn_only?(%{turn_only: true}), do: true
  defp turn_only?(_setup), do: false

  @spec turn_configured?(map() | nil) :: boolean()
  defp turn_configured?(%{turn_configured: true}), do: true
  defp turn_configured?(_setup), do: false

  @spec preference_scope(map() | nil) :: String.t() | nil
  defp preference_scope(%{user_id: user_id}) when not is_nil(user_id), do: to_string(user_id)
  defp preference_scope(_setup), do: nil

  @spec device_preference(map(), atom()) :: String.t()
  defp device_preference(preferences, key), do: Map.get(preferences, key) || ""

  @spec privacy_copy(boolean()) :: String.t()
  defp privacy_copy(true) do
    dgettext("p2p", "Force WebRTC through the relay to hide peer IPs. Latency can increase.")
  end

  defp privacy_copy(false) do
    dgettext("p2p", "Relay privacy is unavailable until TURN is configured on this server.")
  end
end
