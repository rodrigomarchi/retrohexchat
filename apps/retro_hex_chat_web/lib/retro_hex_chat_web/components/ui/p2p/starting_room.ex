defmodule RetroHexChatWeb.Components.UI.P2P.StartingRoom do
  @moduledoc """
  The room a P2P session starts from: who is here, what each of you is using,
  and the host's `[Start]`.

  A P2P session is an **event**, not a place — it begins when two people decide
  it does — so its antechamber is a starting room rather than an arrival hall:
  it has a host, it has `[Ready]`, and it has `[Start]`.

  That is not ceremony added on top of the old setup dialog. The rule already
  existed and was invisible: signalling may only begin once BOTH sides' WebRTC
  hooks have reported ready, because the first offer is dropped if the
  answerer is not listening yet. This screen is that rule with a name:

    * `[Ready]` — devices chosen *and* the WebRTC hook mounted;
    * `[Start]` — the host releases the first offer, and the creator is always
      the offerer;
    * "waiting for bob" — the state a person used to sit in without being told
      why.

  Everything below `[Ready]` is the device half of what used to be the chat's
  `p2p_setup_dialog`, moved here whole. The test ids of those fields did not
  change with the move: they name the field, not the dialog it used to sit in.

  **A match is the same room without that half**, because a game has no camera
  to choose: `game` replaces the device column with what the link named, and
  the roster, the line saying who is being waited on, `[Ready]` and `[Start]`
  are the parts both forms share. That is the whole of what generalising was
  worth here — a `variant` atom with two branches inside every section would
  have been a second screen wearing this one's name.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Components.UI.GroupCall.DeviceSelect
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.MediaDevices

  attr :id, :string, required: true
  attr :setup, :map, required: true, doc: "media posture, devices and route policy"
  attr :room, :map, required: true, doc: "who is here, who is ready, and who the host is"

  attr :game, :map,
    default: nil,
    doc: "the game a match was created for; nil for a plain session"

  attr :on_ready, :any, default: "p2p_room_ready"
  attr :on_start, :any, default: "p2p_room_start"
  attr :on_cancel, :any, default: "p2p_room_cancel"

  slot :footer, doc: "the way back and the share bar, which the host decides"

  @spec p2p_starting_room(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_starting_room(assigns) do
    turn_configured = turn_configured?(assigns.setup)

    assigns =
      assigns
      |> assign(:media, media(assigns.setup))
      |> assign(:devices, devices(assigns.setup))
      |> assign(:device_preferences, device_preferences(assigns.setup))
      |> assign(:turn_configured, turn_configured)
      |> assign(:turn_only, turn_configured and turn_only?(assigns.setup))
      |> assign(:occupants, occupants(assigns.room))

    ~H"""
    <%!-- A dialog promoted to a page: capped and centred, because a room for two
          people stretched across a maximised window is mostly empty window. --%>
    <div
      id={@id}
      class="flex h-full min-h-0 flex-col items-center overflow-auto p-1 text-xs"
      data-testid="p2p-starting-room"
    >
      <.form
        id={"#{@id}-form"}
        for={%{}}
        as={:p2p_setup}
        phx-submit={@on_ready}
        class="my-auto flex w-full max-w-[920px] flex-col gap-2"
        data-testid="p2p-setup-form"
      >
        <%!-- A match still submits the same form, and it says what a game has
              to say about media: nothing to send. Without these the submit
              would carry no `p2p_setup` at all and `[Ready]` would quietly do
              nothing — the fields are the answer, not decoration. --%>
        <input :if={@game} type="hidden" name="p2p_setup[audio]" value="false" />
        <input :if={@game} type="hidden" name="p2p_setup[video]" value="false" />
        <input
          :if={@game}
          type="hidden"
          name="p2p_setup[turn_only]"
          value={to_string(@turn_only)}
        />

        <div class="grid min-w-0 gap-2 md:grid-cols-[260px_minmax(0,1fr)]">
          <.match_subject :if={@game} game={@game} />
          <.room_preview
            :if={!@game}
            media={@media}
            setup={@setup}
            device_preferences={@device_preferences}
          />

          <section class="grid min-w-0 content-start gap-2">
            <.roster occupants={@occupants} room={@room} />

            <section
              :if={!@game}
              class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken"
            >
              <div class="flex items-center gap-1 font-bold">
                <Icons.icon_devices class="h-3.5 w-3.5" />
                {dgettext("p2p", "Media defaults")}
              </div>

              <div class="grid min-w-0 gap-2 sm:grid-cols-2">
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
              </div>
              <div class="flex items-start gap-1 text-muted-foreground">
                <Icons.icon_mute class="mt-[1px] h-3.5 w-3.5 shrink-0" />
                {dgettext(
                  "p2p",
                  "Turn both off to join receive-only and start media later."
                )}
              </div>
            </section>

            <section
              :if={!@game}
              class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken"
            >
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

            <details
              :if={!@game}
              class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken"
              data-testid="p2p-setup-advanced"
            >
              <summary class="flex cursor-pointer items-start justify-between gap-2 font-bold">
                <span class="inline-flex min-w-0 items-center gap-1">
                  <Icons.icon_protocol_p2p class="h-3.5 w-3.5 shrink-0" />
                  <span class="truncate">{dgettext("p2p", "Route and privacy")}</span>
                </span>
                <span class="shrink-0 text-[10px] font-normal text-muted-foreground">
                  {p2p_route_summary(@turn_configured, @turn_only)}
                </span>
              </summary>

              <div class="mt-2 grid min-w-0 gap-2 md:grid-cols-2">
                <div class="flex min-w-0 items-start gap-2">
                  <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
                    <Icons.icon_protocol_p2p class="h-5 w-5" />
                  </span>
                  <div class="min-w-0">
                    <div class="font-bold">{dgettext("p2p", "Direct P2P topology")}</div>
                    <p class="text-muted-foreground">
                      {protocol_description(@turn_only)}
                    </p>
                  </div>
                </div>

                <label class="flex min-w-0 items-start gap-2">
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
              </div>
            </details>
          </section>
        </div>

        <div class="flex shrink-0 flex-wrap items-center gap-2 border-t border-border pt-1">
          {render_slot(@footer)}
          <div class="ml-auto flex shrink-0 items-center gap-2">
            <%!-- P7: a room does not outlive the person waiting in it. Without
                  this the only way to stop waiting is to walk away and let the
                  deadline do it, which leaves the address working for the rest
                  of the quarter-hour. --%>
            <.button
              :if={@room.host? and not @room.started?}
              type="button"
              variant="outline"
              phx-click={@on_cancel}
              data-testid="p2p-room-cancel"
            >
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("p2p", "Cancel")}
            </.button>
            <.button
              type="submit"
              disabled={@room.ready?}
              data-testid="p2p-room-ready"
            >
              <:icon><Icons.icon_btn_join class="h-4 w-4" /></:icon>
              {ready_label(@room.ready?)}
            </.button>
            <%!-- Only the creator gets it, because only the creator can offer:
                  a second offerer is the one thing this negotiation has never
                  survived. --%>
            <.button
              :if={@room.host?}
              type="button"
              phx-click={@on_start}
              disabled={not @room.can_start?}
              data-testid="p2p-room-start"
            >
              <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
              {dgettext("p2p", "Start")}
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  attr :occupants, :list, required: true
  attr :room, :map, required: true

  defp roster(assigns) do
    ~H"""
    <section
      class="grid min-w-0 gap-1 border border-border bg-canvas p-2 shadow-retro-sunken"
      data-testid="p2p-room-roster"
    >
      <div class="flex items-center gap-1 font-bold">
        <Icons.icon_protocol_p2p_compact class="h-3.5 w-3.5" />
        {dgettext("p2p", "In the room")}
      </div>
      <ul class="grid min-w-0 gap-0.5">
        <li
          :for={occupant <- @occupants}
          class="flex min-w-0 items-center justify-between gap-2"
          data-testid={"p2p-room-occupant-#{occupant.slot}"}
        >
          <span class="inline-flex min-w-0 items-center gap-1">
            <Icons.icon_status_user class="h-3.5 w-3.5 shrink-0" />
            <span class="truncate">{occupant.nickname}</span>
            <span :if={occupant.host?} class="shrink-0 text-muted-foreground">
              ({dgettext("p2p", "host")})
            </span>
          </span>
          <span class="shrink-0 text-muted-foreground">{occupant.status}</span>
        </li>
      </ul>
      <p class="text-muted-foreground" data-testid="p2p-room-waiting">{waiting(@room)}</p>
    </section>
    """
  end

  attr :game, :map, required: true

  # A match puts the game where a session puts the camera, and for the same
  # reason: it is the answer to "what did I just walk into". Somebody who
  # followed a link pasted in a channel has seen nothing of this match but its
  # address, and there is no picker here — the link named the game, and
  # offering another one would be the room contradicting the way in.
  defp match_subject(assigns) do
    ~H"""
    <section
      class="grid min-w-0 content-start gap-2 self-start border border-border bg-canvas p-2 shadow-retro-sunken"
      data-testid="p2p-room-game"
    >
      <div class="flex min-w-0 items-center gap-2">
        <span class="shadow-retro-field bg-surface shrink-0 p-2">
          {apply(Icons, game_icon(@game), [%{class: "h-8 w-8"}])}
        </span>
        <span class="min-w-0">
          <span class="block truncate font-bold" data-testid="p2p-room-game-name">
            {@game.name}
          </span>
          <span :if={@game[:tagline]} class="block truncate text-muted-foreground">
            {@game.tagline}
          </span>
        </span>
      </div>
      <p :if={@game[:controls]} class="flex items-start gap-1 text-muted-foreground">
        <Icons.icon_btn_keyboard class="mt-[1px] h-3.5 w-3.5 shrink-0" />
        <span class="min-w-0">{@game.controls}</span>
      </p>
    </section>
    """
  end

  attr :media, :map, required: true
  attr :setup, :map, required: true
  attr :device_preferences, :map, required: true

  defp room_preview(assigns) do
    ~H"""
    <section
      id="p2p-setup-preview"
      phx-hook="P2PSetupHook"
      data-prejoin-prefix="p2p-setup"
      data-form-name="p2p_setup"
      data-devices-event="p2p_setup_devices_listed"
      data-preferences-event="p2p_setup_preferences_loaded"
      data-audio={to_string(@media.audio)}
      data-video={to_string(@media.video)}
      data-audio-input-id={device_preference(@device_preferences, :audio_input_id)}
      data-video-input-id={device_preference(@device_preferences, :video_input_id)}
      data-audio-output-id={device_preference(@device_preferences, :audio_output_id)}
      class="flex max-h-[240px] min-h-[170px] flex-col self-start border border-border bg-canvas p-1 shadow-retro-sunken"
      data-testid="p2p-setup-preview"
    >
      <div class="mb-1 flex items-center justify-between gap-2 text-xs">
        <span class="inline-flex min-w-0 items-center gap-1 font-bold">
          <Icons.icon_camera class="h-3.5 w-3.5 shrink-0" />
          <span class="truncate">{dgettext("p2p", "Preview")}</span>
        </span>
        <span
          id="p2p-setup-device-state"
          phx-update="ignore"
          class="inline-flex items-center gap-1 text-muted-foreground"
          data-p2p-setup-device-state
        >
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
          id="p2p-setup-empty"
          phx-update="ignore"
          class="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-canvas text-center text-xs text-muted-foreground"
          data-p2p-setup-empty
          data-testid="p2p-setup-preview-empty"
        >
          <Icons.icon_camera_off class="h-5 w-5" />
          <span data-p2p-setup-empty-text>{dgettext("p2p", "Camera preview is off")}</span>
        </div>
      </div>

      <div
        id="p2p-setup-warning-notice"
        phx-update="ignore"
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

  # Two seats, always both drawn: the empty half of a session is the half the
  # person is waiting on, and a roster that hid it would answer nothing.
  @spec occupants(map()) :: [map()]
  defp occupants(room) do
    [
      %{
        slot: "you",
        nickname: room.nickname,
        host?: room.host?,
        status: own_status(room)
      },
      %{
        slot: "peer",
        nickname: room.peer_nick || empty_seat_label(room),
        host?: not room.host?,
        status: peer_status(room)
      }
    ]
  end

  defp empty_seat_label(%{match?: true}), do: dgettext("p2p", "whoever joins")
  defp empty_seat_label(_room), do: dgettext("p2p", "peer")

  defp own_status(%{ready?: true}), do: dgettext("p2p", "ready")
  defp own_status(%{match?: true}), do: dgettext("p2p", "getting ready")
  defp own_status(_room), do: dgettext("p2p", "choosing devices")

  defp peer_status(%{peer_present?: false, match?: true}),
    do: dgettext("p2p", "seat open")

  defp peer_status(%{peer_present?: false}), do: dgettext("p2p", "invited")
  defp peer_status(%{peer_ready?: true}), do: dgettext("p2p", "ready")
  defp peer_status(%{match?: true}), do: dgettext("p2p", "getting ready")
  defp peer_status(_room), do: dgettext("p2p", "choosing devices")

  # The one sentence the old screen never said out loud.
  defp waiting(%{ready?: false, match?: true}),
    do: dgettext("p2p", "Press Ready when the game has your attention.")

  defp waiting(%{ready?: false}), do: dgettext("p2p", "Choose your devices, then press Ready.")

  # A match has nobody to wait *for* yet: the seat is open to whoever follows
  # the link, and naming a person there would be the screen inventing one.
  defp waiting(%{peer_present?: false, match?: true}),
    do: dgettext("p2p", "Share the link — the match starts when somebody takes the seat.")

  defp waiting(%{peer_present?: false, peer_nick: peer}),
    do: dgettext("p2p", "Waiting for %{peer} to accept the invite.", peer: peer_label(peer))

  defp waiting(%{peer_ready?: false, peer_nick: peer}),
    do: dgettext("p2p", "Waiting for %{peer} to be ready.", peer: peer_label(peer))

  defp waiting(%{host?: true}), do: dgettext("p2p", "Everyone is ready. Start when you like.")

  defp waiting(%{host_nick: host}),
    do: dgettext("p2p", "Waiting for %{peer} to start.", peer: peer_label(host))

  defp peer_label(peer) when is_binary(peer) and peer != "", do: peer
  defp peer_label(_peer), do: dgettext("p2p", "peer")

  defp game_icon(%{icon: icon}) when is_binary(icon) do
    name = :"icon_#{icon}"
    if function_exported?(Icons, name, 1), do: name, else: :icon_game_generic
  end

  defp game_icon(_game), do: :icon_game_generic

  defp ready_label(true), do: dgettext("p2p", "Ready")
  defp ready_label(false), do: dgettext("p2p", "I am ready")

  @spec protocol_description(boolean()) :: String.t()
  defp protocol_description(true) do
    dgettext(
      "p2p",
      "Your browser uses the relay path for this session, while the session still stays one-to-one."
    )
  end

  defp protocol_description(false) do
    dgettext(
      "p2p",
      "When the network allows it, packets travel browser-to-browser instead of through the conference server."
    )
  end

  @spec media(map() | nil) :: %{audio: boolean(), video: boolean()}
  defp media(%{media: %{audio: audio, video: video}}), do: %{audio: audio, video: video}
  defp media(%{media_mode: "audio"}), do: %{audio: true, video: false}
  defp media(%{media_mode: "receive"}), do: %{audio: false, video: false}
  defp media(_setup), do: %{audio: true, video: true}

  @spec devices(map() | nil) :: map()
  defp devices(source), do: MediaDevices.listing(source)

  @spec device_preferences(map() | nil) :: map()
  defp device_preferences(source), do: MediaDevices.preferences(source)

  @spec turn_only?(map() | nil) :: boolean()
  defp turn_only?(%{turn_only: true}), do: true
  defp turn_only?(_setup), do: false

  @spec turn_configured?(map() | nil) :: boolean()
  defp turn_configured?(%{turn_configured: true}), do: true
  defp turn_configured?(_setup), do: false

  @spec device_preference(map(), atom()) :: String.t()
  defp device_preference(preferences, key), do: Map.get(preferences, key) || ""

  @spec privacy_copy(boolean()) :: String.t()
  defp privacy_copy(true) do
    dgettext("p2p", "Force WebRTC through the relay to hide peer IPs. Latency can increase.")
  end

  defp privacy_copy(false) do
    dgettext("p2p", "Relay privacy is unavailable until TURN is configured on this server.")
  end

  @spec p2p_route_summary(boolean(), boolean()) :: String.t()
  defp p2p_route_summary(_turn_configured, true), do: dgettext("p2p", "Relay on")
  defp p2p_route_summary(false, _turn_only), do: dgettext("p2p", "Relay unavailable")
  defp p2p_route_summary(_turn_configured, _turn_only), do: dgettext("p2p", "Direct preferred")
end
