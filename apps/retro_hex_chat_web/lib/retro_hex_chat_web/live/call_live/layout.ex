defmodule RetroHexChatWeb.CallLive.Layout do
  @moduledoc """
  How a channel conference is laid out on this page: the mode (auto, grid,
  focus, speaker), who is focused and pinned, where the self view sits, and the
  payload the browser draws its tiles from. Pure functions of the call map
  `CallLive.Events` keeps in its assigns.
  """

  alias RetroHexChatWeb.App.GroupCallShape
  alias RetroHexChatWeb.Components.UI.NickFlag

  @layout_modes ~w(auto grid focus speaker)
  @self_view_cycle [:tile, :pip, :hidden]

  @doc "The layout modes by name, in the order the cycle visits them."
  @spec layout_modes() :: [String.t()]
  def layout_modes, do: @layout_modes

  @doc "A layout mode from an atom or its name; anything else is `:auto`."
  @spec layout_mode(term()) :: :auto | :grid | :focus | :speaker
  def layout_mode(mode) when mode in [:auto, :grid, :focus, :speaker], do: mode

  def layout_mode(mode) when is_binary(mode) and mode in @layout_modes,
    do: String.to_existing_atom(mode)

  def layout_mode(_mode), do: :auto

  @doc "A self-view placement from an atom or its name; anything else is `:tile`."
  @spec self_view_mode(term()) :: :tile | :pip | :hidden
  def self_view_mode(mode) when mode in [:tile, :pip, :hidden], do: mode

  def self_view_mode(mode) when is_binary(mode) and mode in ~w(tile pip hidden),
    do: String.to_existing_atom(mode)

  def self_view_mode(_mode), do: :tile

  @doc "The layout a call starts in."
  @spec default_layout() :: map()
  def default_layout do
    %{
      mode: :auto,
      focused_participant_id: nil,
      self_view: :tile,
      console_section: :call,
      mini: false,
      pinned_participant_ids: []
    }
  end

  @doc "The call's layout with every key present and normalized."
  @spec layout(map()) :: map()
  def layout(%{layout: layout}) when is_map(layout) do
    default_layout()
    |> Map.merge(layout)
    |> Map.update!(:console_section, &GroupCallShape.normalize_console_section/1)
    |> Map.update!(:pinned_participant_ids, &GroupCallShape.normalize_pinned_participant_ids/1)
  end

  def layout(_call), do: default_layout()

  @doc "Picks whom to focus when the mode needs someone: the active speaker, else the first remote with video."
  @spec maybe_focus_for_mode(map(), map()) :: map()
  def maybe_focus_for_mode(%{mode: :speaker} = layout, call) do
    %{
      layout
      | focused_participant_id:
          active_speaker_participant_id(call) || default_focus_participant_id(call)
    }
  end

  def maybe_focus_for_mode(%{mode: mode, focused_participant_id: nil} = layout, call)
      when mode == :focus do
    %{layout | focused_participant_id: default_focus_participant_id(call)}
  end

  def maybe_focus_for_mode(layout, _call), do: layout

  @doc "Whom to focus by default: the first remote participant with video, else the first participant."
  @spec default_focus_participant_id(map()) :: integer() | nil
  def default_focus_participant_id(call) do
    remote =
      call.participants
      |> Enum.reject(&(&1.id == call.participant_id))
      |> Enum.find(&GroupCallShape.participant_media?(&1, :video))

    (remote || List.first(call.participants) || %{})[:id]
  end

  defp active_speaker_participant_id(%{
         participant_quality: %{active_speaker_participant_id: id}
       }),
       do: id

  defp active_speaker_participant_id(_call), do: nil

  @doc "In speaker mode, moves the focus to whoever is speaking now."
  @spec maybe_sync_speaker_focus(map()) :: map()
  def maybe_sync_speaker_focus(%{layout: %{mode: :speaker}} = call) do
    case active_speaker_participant_id(call) do
      participant_id when is_integer(participant_id) ->
        %{call | layout: %{layout(call) | focused_participant_id: participant_id}}

      _missing ->
        call
    end
  end

  def maybe_sync_speaker_focus(call), do: call

  @doc "Pins or unpins a participant; at most four stay pinned."
  @spec toggle_participant_id([integer()] | term(), integer()) :: [integer()]
  def toggle_participant_id(participant_ids, participant_id) do
    participant_ids = GroupCallShape.normalize_pinned_participant_ids(participant_ids)

    if participant_id in participant_ids do
      Enum.reject(participant_ids, &(&1 == participant_id))
    else
      (participant_ids ++ [participant_id])
      |> Enum.uniq()
      |> Enum.take(4)
    end
  end

  @doc "Unpins a participant who left."
  @spec remove_pinned_participant(map(), integer()) :: map()
  def remove_pinned_participant(layout, participant_id) do
    Map.put(
      layout,
      :pinned_participant_ids,
      layout
      |> Map.get(:pinned_participant_ids, [])
      |> GroupCallShape.normalize_pinned_participant_ids()
      |> Enum.reject(&(&1 == participant_id))
    )
  end

  @doc "The mode name after `current`, cycling; an unknown one starts the cycle over."
  @spec next_layout_mode(String.t()) :: String.t()
  def next_layout_mode(current) do
    current_index = Enum.find_index(@layout_modes, &(&1 == current)) || 0
    Enum.at(@layout_modes, rem(current_index + 1, length(@layout_modes)))
  end

  @doc "The self-view placement after `current`, cycling."
  @spec next_self_view(atom()) :: :tile | :pip | :hidden
  def next_self_view(current) do
    current_index = Enum.find_index(@self_view_cycle, &(&1 == current)) || 0
    Enum.at(@self_view_cycle, rem(current_index + 1, length(@self_view_cycle)))
  end

  @doc "The participant after `current_id`, cycling; nil for nobody."
  @spec next_participant_id([integer()], integer() | nil) :: integer() | nil
  def next_participant_id([], _current_id), do: nil

  def next_participant_id(participant_ids, current_id) do
    current_index = Enum.find_index(participant_ids, &(&1 == current_id))
    next_index = rem((current_index || -1) + 1, length(participant_ids))
    Enum.at(participant_ids, next_index)
  end

  @doc "What the browser draws its tiles from: the layout, the participants with their flags, and the tracks."
  @spec group_call_layout_payload(map()) :: map()
  def group_call_layout_payload(call) do
    layout = layout(call)

    %{
      mode: Atom.to_string(layout.mode),
      focused_participant_id: layout.focused_participant_id,
      self_view: Atom.to_string(layout.self_view),
      mini: Map.get(layout, :mini, false),
      pinned_participant_ids: layout.pinned_participant_ids,
      self_participant_id: call.participant_id,
      participants:
        Enum.map(call.participants || [], fn participant ->
          participant
          |> GroupCallShape.participant_payload()
          |> Map.put(:flag, participant_flag(call, participant))
        end),
      tracks: Enum.map(call.tracks || [], &GroupCallShape.track_payload/1)
    }
  end

  # What a JS-drawn name tile needs to draw the flag beside it: the tile is
  # built in the browser, so it gets the sprite reference rather than a locale
  # it would have to map to an icon itself.
  defp participant_flag(call, %{nickname: nickname}) do
    call
    |> Map.get(:nick_locales)
    |> Kernel.||(%{})
    |> Map.get(nickname)
    |> NickFlag.payload()
  end

  @doc "A screen share that starts takes the focus."
  @spec maybe_focus_screen_share(map(), integer() | nil, boolean()) :: map()
  def maybe_focus_screen_share(call, participant_id, true) when is_integer(participant_id) do
    %{call | layout: %{layout(call) | mode: :focus, focused_participant_id: participant_id}}
  end

  def maybe_focus_screen_share(call, _participant_id, _active?), do: call
end
