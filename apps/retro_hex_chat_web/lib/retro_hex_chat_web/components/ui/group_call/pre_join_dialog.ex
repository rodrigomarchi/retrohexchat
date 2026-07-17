defmodule RetroHexChatWeb.Components.UI.GroupCall.PreJoinDialog do
  @moduledoc """
  Pre-join dialog for channel conferences.

  The dialog owns only presentation. ChatLive owns the pending channel/user state
  and the browser hook owns preview/device enumeration.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Components.UI.GroupCall.{DeviceSelect, MediaPreview}
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :prejoin, :map, default: nil
  attr :on_join, :any, default: "group_call_prejoin_join"
  attr :on_cancel, :any, default: "group_call_prejoin_cancel"

  @spec group_call_pre_join_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_pre_join_dialog(assigns) do
    assigns =
      assigns
      |> assign(:show, is_map(assigns.prejoin))
      |> assign(:media, media(assigns.prejoin))
      |> assign(:layout, layout(assigns.prejoin))
      |> assign(:devices, devices(assigns.prejoin))
      |> assign(:device_preferences, device_preferences(assigns.prejoin))
      |> assign(:channel_name, channel_name(assigns.prejoin))

    ~H"""
    <span data-testid="group-call-prejoin-dialog">
      <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="md:max-w-[760px]">
        <.dialog_header
          id={@id}
          title={dgettext("group_call", "Join Channel Conference")}
          on_close={@on_cancel}
        >
          <:icon><Icons.icon_protocol_conference_compact class="h-4 w-4" /></:icon>
        </.dialog_header>

        <.form
          :if={@show}
          id="group-call-prejoin-form"
          for={%{}}
          as={:group_call_prejoin}
          phx-submit={@on_join}
          class="contents"
          data-testid="group-call-prejoin-form"
        >
          <.dialog_body class="box-border w-full md:w-[720px]">
            <div class="grid min-w-0 gap-2 md:grid-cols-[260px_minmax(0,1fr)]">
              <MediaPreview.media_preview
                media={@media}
                prejoin={@prejoin}
                device_preferences={@device_preferences}
              />

              <section class="grid min-w-0 gap-2 text-xs">
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
                        <.toggle_row
                          name="group_call_prejoin[sidebar_open]"
                          checked={@layout.sidebar_open}
                          icon={:icon_tab_nicklist}
                          label={dgettext("group_call", "Show participants panel")}
                          testid="group-call-prejoin-sidebar"
                        />
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
          </.dialog_body>

          <.dialog_footer>
            <.button type="submit" data-testid="group-call-prejoin-join">
              <:icon><Icons.icon_btn_join class="h-4 w-4" /></:icon>
              {dgettext("group_call", "Join call")}
            </.button>
            <.button
              type="button"
              variant="outline"
              phx-click={@on_cancel}
              data-testid="group-call-prejoin-cancel"
            >
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("group_call", "Cancel")}
            </.button>
          </.dialog_footer>
        </.form>
      </.dialog>
    </span>
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
      sidebar_open: Map.get(layout, :sidebar_open, true),
      self_view: Map.get(layout, :self_view, :tile)
    }
  end

  defp layout(_prejoin), do: %{mode: :auto, sidebar_open: true, self_view: :tile}

  defp channel_name(%{channel_name: channel_name})
       when is_binary(channel_name) and channel_name != "",
       do: channel_name

  defp channel_name(_prejoin), do: dgettext("group_call", "conference")

  defp devices(%{devices: devices}) when is_map(devices) do
    Map.merge(%{"audioinput" => [], "videoinput" => [], "audiooutput" => []}, devices)
  end

  defp devices(_prejoin), do: %{"audioinput" => [], "videoinput" => [], "audiooutput" => []}

  defp device_preferences(%{device_preferences: preferences}) when is_map(preferences) do
    %{
      audio_input_id: Map.get(preferences, :audio_input_id),
      video_input_id: Map.get(preferences, :video_input_id),
      audio_output_id: Map.get(preferences, :audio_output_id)
    }
  end

  defp device_preferences(_prejoin) do
    %{audio_input_id: nil, video_input_id: nil, audio_output_id: nil}
  end

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
