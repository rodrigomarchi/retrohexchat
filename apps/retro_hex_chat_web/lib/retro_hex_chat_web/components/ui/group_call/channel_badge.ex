defmodule RetroHexChatWeb.Components.UI.GroupCall.ChannelBadge do
  @moduledoc """
  Channel-level conference indicators.

  The conversation toolbar uses the icon entry with a popover. Tabs and the
  conversations sidebar use the compact glyph so all channel surfaces share the
  same summary derivation.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :channel, :string, required: true
  attr :active, :boolean, default: false
  attr :current, :boolean, default: false
  attr :identified, :boolean, default: true
  attr :summary, :map, default: nil
  attr :on_open, :any, default: "group_call_open"
  attr :class, :any, default: nil

  @spec group_call_channel_entry(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_channel_entry(assigns) do
    assigns = assign_summary(assigns)

    ~H"""
    <div class={classes(["flex h-6 items-center gap-px", @class])}>
      <button
        type="button"
        phx-click={@on_open}
        class={[
          "conversation-toolbar-button flex h-6 w-6 shrink-0 items-center justify-center p-0 shadow-retro-raised bg-surface text-xs",
          "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
          @current && "bg-canvas font-bold shadow-retro-sunken",
          active_state_class(@active, @state),
          !@identified && "opacity-60"
        ]}
        aria-label={dgettext("group_call", "Group Call")}
        title={open_title(@identified)}
        aria-pressed={to_string(@current)}
        disabled={!@identified}
        data-testid="group-call-open"
        data-channel={@channel}
        data-state={active_value(@active, Atom.to_string(@state))}
        data-participant-count={active_value(@active, @participant_count)}
        data-max-participants={active_value(@active, @max_participants)}
        data-started-at={active_value(@active, started_at_value(@started_at))}
      >
        <Icons.icon_protocol_conference_compact class="h-3.5 w-3.5 shrink-0" />
        <span
          :if={@active}
          class={[
            "absolute bottom-0.5 right-0.5 h-1.5 w-1.5 border border-border",
            @state in [:active, :full] && "animate-pulse",
            state_dot_class(@state)
          ]}
          aria-hidden="true"
        />
      </button>

      <details :if={@active} class="relative h-6">
        <summary
          class={[
            "conversation-toolbar-button flex h-6 w-6 cursor-pointer list-none items-center justify-center shadow-retro-raised bg-surface text-primary",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          ]}
          aria-label={dgettext("group_call", "Conference summary")}
          title={dgettext("group_call", "Conference summary")}
          data-testid="group-call-channel-popover-toggle"
        >
          <Icons.icon_btn_info class="h-3.5 w-3.5" />
        </summary>

        <div
          class="absolute right-0 top-full z-50 mt-1 w-72 border border-border bg-surface p-2 text-xs shadow-retro-raised"
          role="group"
          data-testid="group-call-channel-popover"
          data-channel={@channel}
        >
          <div class="flex items-start justify-between gap-2 border-b border-border pb-1">
            <div class="min-w-0">
              <div class="flex items-center gap-1 font-bold">
                <Icons.icon_protocol_conference_compact class="h-3.5 w-3.5 shrink-0" />
                <span class="truncate">{@channel}</span>
              </div>
              <div class="mt-0.5 flex items-center gap-1 text-[10px] text-muted-foreground">
                <Icons.icon_clock class="h-3 w-3 shrink-0" />
                <span>{@duration}</span>
              </div>
            </div>
            <span class={[
              "shadow-retro-sunken bg-white px-1 py-px text-[10px] font-bold",
              state_class(@state)
            ]}>
              {state_label(@state)}
            </span>
          </div>

          <div class="mt-2 grid grid-cols-2 gap-1 text-[11px]">
            <div class="shadow-retro-status bg-white px-1 py-px">
              <span class="font-bold">{dgettext("group_call", "Participants")}</span>
              <span class="float-right">{@participant_count}/{@max_participants || "?"}</span>
            </div>
            <div class="shadow-retro-status bg-white px-1 py-px">
              <span class="font-bold">{dgettext("group_call", "Speaker")}</span>
              <span class="float-right truncate max-w-[9ch]">{@speaker_name || "-"}</span>
            </div>
          </div>

          <div class="mt-2 shadow-retro-sunken bg-white p-1">
            <div class="mb-1 flex items-center gap-1 text-[10px] font-bold uppercase">
              <Icons.icon_status_user class="h-3 w-3" />
              <span>{dgettext("group_call", "In conference")}</span>
            </div>
            <div class="space-y-1">
              <div
                :for={participant <- @participants}
                class="flex min-w-0 items-center justify-between gap-1"
              >
                <span class="truncate">{participant.nickname}</span>
                <span class="flex shrink-0 items-center gap-px text-muted-foreground">
                  <Icons.icon_raise_hand :if={hand_raised?(participant)} class="h-3 w-3 text-warning" />
                  <Icons.icon_microphone :if={media_enabled?(participant, :audio)} class="h-3 w-3" />
                  <Icons.icon_camera :if={media_enabled?(participant, :video)} class="h-3 w-3" />
                  <Icons.icon_screen_share :if={media_enabled?(participant, :screen)} class="h-3 w-3" />
                </span>
              </div>
              <div :if={@participants == []} class="text-muted-foreground">
                {dgettext("group_call", "Waiting for participants")}
              </div>
            </div>
          </div>

          <button
            type="button"
            phx-click={@on_open}
            class="mt-2 flex h-6 w-full items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
            data-testid="group-call-channel-popover-action"
          >
            <Icons.icon_btn_play class="h-3.5 w-3.5" />
            <span>
              {if @current, do: dgettext("group_call", "Open"), else: dgettext("group_call", "Join")}
            </span>
          </button>
        </div>
      </details>
    </div>
    """
  end

  attr :channel, :string, required: true
  attr :summary, :map, default: nil
  attr :testid, :string, default: nil
  attr :class, :any, default: nil

  @spec group_call_channel_glyph(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_channel_glyph(assigns) do
    assigns = assign_summary(assigns)

    ~H"""
    <span
      class={
        classes([
          "inline-flex h-4 shrink-0 items-center justify-center gap-[1px] text-success",
          @class
        ])
      }
      title={@title}
      data-testid={@testid}
      data-channel={@channel}
      data-state={Atom.to_string(@state)}
      data-participant-count={@participant_count}
    >
      <Icons.icon_protocol_conference_compact class="h-3.5 w-3.5" />
      <span :if={@participant_count > 0} class="text-[9px] font-bold leading-none">
        {@participant_count}
      </span>
    </span>
    """
  end

  defp assign_summary(assigns) do
    summary = normalize_summary(assigns[:summary], assigns.channel)
    participants = Enum.take(summary.participants, 6)
    participant_count = participant_count(summary)
    max_participants = max_participants(summary)
    state = state(summary, participant_count, max_participants)
    started_at = started_at(summary)
    duration = duration_label(started_at)
    speaker_name = speaker_name(summary)

    assigns
    |> assign(:summary_data, summary)
    |> assign(:participants, participants)
    |> assign(:participant_count, participant_count)
    |> assign(:max_participants, max_participants)
    |> assign(:state, state)
    |> assign(:started_at, started_at)
    |> assign(:duration, duration)
    |> assign(:speaker_name, speaker_name)
    |> assign(
      :title,
      title(assigns.channel, state, participant_count, max_participants, duration)
    )
  end

  defp normalize_summary(nil, channel) do
    %{
      status: nil,
      room: %{channel_name: channel, status: "open", max_participants: nil, metadata: %{}},
      participants: [],
      pending_participants: [],
      server_stats: %{},
      participant_quality: %{}
    }
  end

  defp normalize_summary(summary, channel) when is_map(summary) do
    room = value(summary, :room) || %{}

    %{
      status: value(summary, :status),
      room: Map.put(room, :channel_name, value(room, :channel_name) || channel),
      participants: normalize_participants(value(summary, :participants)),
      pending_participants: normalize_participants(value(summary, :pending_participants)),
      server_stats: value(summary, :server_stats) || %{},
      participant_quality: value(summary, :participant_quality) || %{}
    }
  end

  defp normalize_participants(nil), do: []

  defp normalize_participants(participants) do
    participants
    |> Enum.map(fn participant ->
      %{
        id: value(participant, :id),
        nickname: value(participant, :nickname) || "?",
        status: value(participant, :status),
        media_state: value(participant, :media_state) || %{}
      }
    end)
    |> Enum.reject(&is_nil(&1.id))
  end

  defp participant_count(summary) do
    room_stats = value(summary.server_stats, :room) || %{}

    cond do
      is_integer(value(room_stats, :participant_count)) ->
        value(room_stats, :participant_count)

      summary.participants != [] ->
        length(summary.participants)

      true ->
        0
    end
  end

  defp max_participants(summary) do
    room_stats = value(summary.server_stats, :room) || %{}
    value(summary.room, :max_participants) || value(room_stats, :max_participants)
  end

  defp state(summary, participant_count, max_participants) do
    status = value(summary, :status) || value(summary.room, :status)

    cond do
      locked?(summary) -> :locked
      status in [:error, "error", :failed, "failed"] -> :degraded
      status in [:reconnecting, "reconnecting", :disconnected, "disconnected"] -> :degraded
      status in [:closing, "closing"] -> :ending
      is_integer(max_participants) and participant_count >= max_participants -> :full
      true -> :active
    end
  end

  defp started_at(summary) do
    value(summary.room, :activated_at) ||
      value(summary.room, :opened_at) ||
      value(summary.room, :inserted_at)
  end

  defp started_at_value(nil), do: nil
  defp started_at_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp started_at_value(value), do: to_string(value)

  defp duration_label(nil), do: dgettext("group_call", "0m")

  defp duration_label(%DateTime{} = started_at) do
    seconds =
      DateTime.utc_now()
      |> DateTime.diff(started_at, :second)
      |> max(0)

    minutes = div(seconds, 60)
    hours = div(minutes, 60)

    if hours > 0 do
      dgettext("group_call", "%{hours}h %{minutes}m", hours: hours, minutes: rem(minutes, 60))
    else
      dgettext("group_call", "%{minutes}m", minutes: minutes)
    end
  end

  defp duration_label(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> duration_label(datetime)
      _error -> dgettext("group_call", "0m")
    end
  end

  defp duration_label(_value), do: dgettext("group_call", "0m")

  defp speaker_name(summary) do
    quality = summary.participant_quality || %{}
    speaker_id = value(quality, :active_speaker_participant_id)

    case Enum.find(summary.participants, &(to_string(&1.id) == to_string(speaker_id))) do
      nil -> nil
      participant -> participant.nickname
    end
  end

  defp locked?(summary) do
    metadata = value(summary.room, :metadata) || %{}
    value(metadata, :locked) == true or value(metadata, :admission_locked) == true
  end

  defp media_enabled?(%{media_state: media}, key) when is_map(media) do
    case value(media, key) do
      nil -> false
      value -> value == true
    end
  end

  defp media_enabled?(_participant, _key), do: false

  defp hand_raised?(%{media_state: media}) when is_map(media),
    do: value(media, :hand_raised) == true

  defp hand_raised?(_participant), do: false

  defp open_title(true), do: dgettext("group_call", "Group Call")
  defp open_title(false), do: dgettext("group_call", "Identify with NickServ to use group calls")

  defp title(channel, state, participant_count, max_participants, duration) do
    dgettext(
      "group_call",
      "%{state} conference in %{channel}: %{count}/%{max} participants, %{duration}",
      state: state_label(state),
      channel: channel,
      count: participant_count,
      max: max_participants || "?",
      duration: duration
    )
  end

  defp state_label(:active), do: dgettext("group_call", "Live")
  defp state_label(:full), do: dgettext("group_call", "Full")
  defp state_label(:locked), do: dgettext("group_call", "Locked")
  defp state_label(:degraded), do: dgettext("group_call", "Degraded")
  defp state_label(:ending), do: dgettext("group_call", "Ending")

  defp state_class(:active), do: "border-success text-success"
  defp state_class(:full), do: "border-warning text-warning"
  defp state_class(:locked), do: "border-warning text-warning"
  defp state_class(:degraded), do: "border-destructive text-destructive"
  defp state_class(:ending), do: "border-muted text-muted-foreground"

  defp active_state_class(false, _state), do: nil
  defp active_state_class(true, state), do: ["relative border", state_class(state)]

  defp active_value(false, _value), do: nil
  defp active_value(true, value), do: value

  defp state_dot_class(:active), do: "bg-success"
  defp state_dot_class(:full), do: "bg-warning"
  defp state_dot_class(:locked), do: "bg-warning"
  defp state_dot_class(:degraded), do: "bg-destructive"
  defp state_dot_class(:ending), do: "bg-muted-foreground"

  defp value(nil, _key), do: nil

  defp value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end
end
