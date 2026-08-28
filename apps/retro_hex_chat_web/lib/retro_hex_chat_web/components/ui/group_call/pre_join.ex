defmodule RetroHexChatWeb.Components.UI.GroupCall.PreJoin do
  @moduledoc """
  The antechamber of a channel conference: the screen you land on before you
  are inside.

  It is a room you arrive at, not an event that starts — there is no host and
  no `[Start]`, because any member of a channel opens a call and anyone joins
  whenever they like. What it adds over a bare device picker is the roster:
  walking into a room without knowing who is already in it is the one thing a
  door should never do.

  It owns only presentation. The surface hosting it owns the pending channel
  and the roster, and the browser hook owns the preview and device
  enumeration.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Components.UI.GroupCall.DeviceSelect
  alias RetroHexChatWeb.Components.UI.GroupCall.MediaPreview
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.MediaDevices

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :prejoin, :map, default: nil
  attr :participants, :list, default: []
  attr :on_join, :any, default: "group_call_prejoin_join"
  attr :on_cancel, :any, default: nil

  slot :actions,
    doc: "Extra footer controls — the way back, which differs between hosts"

  @spec group_call_pre_join_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_pre_join_panel(assigns) do
    assigns =
      assigns
      |> assign(:media, media(assigns.prejoin))
      |> assign(:layout, layout(assigns.prejoin))
      |> assign(:devices, devices(assigns.prejoin))
      |> assign(:device_preferences, device_preferences(assigns.prejoin))
      |> assign(:channel_name, channel_name(assigns.prejoin))

    ~H"""
    <div
      id={@id}
      class={classes(["flex h-full min-h-0 flex-col bg-surface", @class])}
      data-testid="group-call-prejoin"
    >
      <.form
        :if={@prejoin}
        id="group-call-prejoin-form"
        for={%{}}
        as={:group_call_prejoin}
        phx-submit={@on_join}
        class="flex min-h-0 flex-1 flex-col"
        data-testid="group-call-prejoin-form"
      >
        <div class="min-h-0 flex-1 overflow-y-auto p-2">
          <div class="grid min-w-0 gap-2 md:grid-cols-[260px_minmax(0,1fr)]">
            <div class="grid min-w-0 content-start gap-2">
              <MediaPreview.media_preview
                media={@media}
                prejoin={@prejoin}
                device_preferences={@device_preferences}
              />

              <.inside_now participants={@participants} />
            </div>

            <section class="grid min-w-0 content-start gap-2 text-xs">
              <div class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken">
                <div class="flex items-start gap-2">
                  <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-surface shadow-retro-sunken">
                    <Icons.icon_protocol_conference_compact class="h-4 w-4" />
                  </span>
                  <div class="min-w-0">
                    <div class="font-bold">
                      {dgettext("group_call", "Join %{channel}", channel: @channel_name)}
                    </div>
                    <p class="text-muted-foreground">
                      {dgettext(
                        "group_call",
                        "Choose how you enter the room. You can change media and layout after joining."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <div class="min-w-0 border border-border bg-canvas p-2 shadow-retro-sunken">
                <div class="mb-2 flex items-center gap-1 font-bold">
                  <Icons.icon_devices class="h-3.5 w-3.5" />
                  {dgettext("group_call", "Media defaults")}
                </div>

                <div class="grid gap-2 sm:grid-cols-2">
                  <.toggle_row
                    name="group_call_prejoin[audio]"
                    checked={@media.audio}
                    icon={:icon_microphone}
                    label={dgettext("group_call", "Join with microphone")}
                    testid="group-call-prejoin-audio"
                  />
                  <.toggle_row
                    name="group_call_prejoin[video]"
                    checked={@media.video}
                    icon={:icon_camera}
                    label={dgettext("group_call", "Join with camera")}
                    testid="group-call-prejoin-video-toggle"
                  />
                </div>
              </div>

              <div
                class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken"
                data-testid="group-call-prejoin-devices"
              >
                <DeviceSelect.device_select
                  name="group_call_prejoin[audio_input_id]"
                  value={@device_preferences.audio_input_id}
                  kind="audioinput"
                  devices={@devices["audioinput"]}
                  icon={:icon_microphone}
                  label={dgettext("group_call", "Microphone")}
                  testid="group-call-prejoin-audio-input"
                />
                <DeviceSelect.device_select
                  name="group_call_prejoin[video_input_id]"
                  value={@device_preferences.video_input_id}
                  kind="videoinput"
                  devices={@devices["videoinput"]}
                  icon={:icon_camera}
                  label={dgettext("group_call", "Camera")}
                  testid="group-call-prejoin-video-input"
                />
                <DeviceSelect.device_select
                  name="group_call_prejoin[audio_output_id]"
                  value={@device_preferences.audio_output_id}
                  kind="audiooutput"
                  devices={@devices["audiooutput"]}
                  icon={:icon_devices}
                  label={dgettext("group_call", "Speaker")}
                  testid="group-call-prejoin-audio-output"
                />
              </div>

              <details
                class="grid min-w-0 gap-2 border border-border bg-canvas p-2 shadow-retro-sunken"
                data-testid="group-call-prejoin-advanced"
              >
                <summary class="flex cursor-pointer items-start justify-between gap-2 font-bold">
                  <span class="inline-flex min-w-0 items-center gap-1">
                    <Icons.icon_layout_maximize class="h-3.5 w-3.5 shrink-0" />
                    <span class="truncate">{dgettext("group_call", "Layout and route")}</span>
                  </span>
                  <span class="shrink-0 text-[10px] font-normal text-muted-foreground">
                    {conference_layout_summary(@layout)}
                  </span>
                </summary>

                <div class="mt-2 grid min-w-0 gap-2">
                  <div class="min-w-0 border border-border bg-surface p-2 shadow-retro-sunken">
                    <div class="mb-2 flex items-center gap-1 font-bold">
                      <Icons.icon_layout_maximize class="h-3.5 w-3.5" />
                      {dgettext("group_call", "Layout defaults")}
                    </div>

                    <div class="grid min-w-0 gap-2">
                      <div class="grid min-w-0 grid-cols-2 gap-2">
                        <.simple_select
                          name="group_call_prejoin[layout_mode]"
                          value={Atom.to_string(@layout.mode)}
                          icon={:icon_layout_maximize}
                          label={dgettext("group_call", "Layout")}
                          options={[
                            {"auto", dgettext("group_call", "Auto")},
                            {"grid", dgettext("group_call", "Grid")},
                            {"focus", dgettext("group_call", "Focus")}
                          ]}
                          testid="group-call-prejoin-layout"
                        />
                        <.simple_select
                          name="group_call_prejoin[self_view]"
                          value={Atom.to_string(@layout.self_view)}
                          icon={:icon_pip}
                          label={dgettext("group_call", "Self view")}
                          options={[
                            {"tile", dgettext("group_call", "Tile")},
                            {"pip", dgettext("group_call", "PiP")},
                            {"hidden", dgettext("group_call", "Hidden")}
                          ]}
                          testid="group-call-prejoin-self-view"
                        />
                      </div>
                    </div>
                  </div>

                  <div class="flex min-w-0 items-start gap-2 border border-border bg-surface p-2 shadow-retro-sunken">
                    <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-canvas shadow-retro-sunken">
                      <Icons.icon_protocol_conference class="h-5 w-5" />
                    </span>
                    <div class="min-w-0">
                      <div class="font-bold">{dgettext("group_call", "Conference route")}</div>
                      <p class="text-muted-foreground">
                        {dgettext(
                          "group_call",
                          "Each browser sends media to the room server; the server routes streams to the other participants."
                        )}
                      </p>
                    </div>
                  </div>
                </div>
              </details>
            </section>
          </div>
        </div>

        <div class="flex shrink-0 flex-wrap items-center justify-end gap-2 border-t border-border bg-surface p-2">
          {render_slot(@actions)}
          <.button
            :if={@on_cancel}
            type="button"
            variant="outline"
            phx-click={@on_cancel}
            data-testid="group-call-prejoin-cancel"
          >
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("group_call", "Cancel")}
          </.button>
          <.button type="submit" data-testid="group-call-prejoin-join">
            <:icon><Icons.icon_btn_join class="h-4 w-4" /></:icon>
            {dgettext("group_call", "Join call")}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :participants, :list, required: true

  # The roster is what makes this a door rather than a settings screen. An
  # empty room says so in words: a blank list reads as "still loading".
  defp inside_now(assigns) do
    ~H"""
    <div
      class="grid min-w-0 gap-1 border border-border bg-canvas p-2 text-xs shadow-retro-sunken"
      data-testid="group-call-prejoin-roster"
    >
      <div class="flex items-center gap-1 font-bold">
        <Icons.icon_tab_nicklist class="h-3.5 w-3.5 shrink-0" />
        <span class="truncate">{dgettext("group_call", "Already inside")}</span>
      </div>

      <p :if={@participants == []} class="text-muted-foreground">
        {dgettext("group_call", "Nobody yet — you would be the first.")}
      </p>

      <ul :if={@participants != []} class="grid min-w-0 gap-0.5">
        <li
          :for={participant <- @participants}
          class="flex min-w-0 items-center gap-1"
          data-testid="group-call-prejoin-roster-entry"
        >
          <Icons.icon_protocol_conference_compact class="h-3 w-3 shrink-0" />
          <span class="truncate">{participant}</span>
        </li>
      </ul>
    </div>
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

  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :testid, :string, required: true

  defp simple_select(assigns) do
    ~H"""
    <label class="grid min-w-0 gap-1">
      <span class="inline-flex min-w-0 items-center gap-1 font-bold">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </span>
      <select
        name={@name}
        class="h-7 w-full min-w-0 bg-white px-1 text-xs shadow-retro-sunken focus:outline focus:outline-1 focus:outline-foreground"
        data-testid={@testid}
      >
        <option :for={{value, label} <- @options} value={value} selected={value == @value}>
          {label}
        </option>
      </select>
    </label>
    """
  end

  defp media(%{media: %{audio: audio, video: video}}), do: %{audio: audio, video: video}
  defp media(_prejoin), do: %{audio: true, video: true}

  defp layout(%{layout: layout}) when is_map(layout) do
    %{
      mode: Map.get(layout, :mode, :auto),
      self_view: Map.get(layout, :self_view, :tile)
    }
  end

  defp layout(_prejoin), do: %{mode: :auto, self_view: :tile}

  defp channel_name(%{channel_name: channel_name})
       when is_binary(channel_name) and channel_name != "",
       do: channel_name

  defp channel_name(_prejoin), do: dgettext("group_call", "conference")

  defp devices(source), do: MediaDevices.listing(source)

  defp device_preferences(source), do: MediaDevices.preferences(source)

  @spec conference_layout_summary(map()) :: String.t()
  defp conference_layout_summary(%{mode: mode, self_view: self_view}) do
    dgettext("group_call", "%{layout} / %{self}",
      layout: conference_layout_label(mode),
      self: conference_self_view_label(self_view)
    )
  end

  defp conference_layout_label(:grid), do: dgettext("group_call", "Grid")
  defp conference_layout_label(:focus), do: dgettext("group_call", "Focus")
  defp conference_layout_label(_mode), do: dgettext("group_call", "Auto")

  defp conference_self_view_label(:pip), do: dgettext("group_call", "PiP")
  defp conference_self_view_label(:hidden), do: dgettext("group_call", "Hidden")
  defp conference_self_view_label(_self_view), do: dgettext("group_call", "Tile")
end
