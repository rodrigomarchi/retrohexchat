defmodule RetroHexChatWeb.MediaDevices do
  @moduledoc """
  What the browser says about microphones, cameras and speakers.

  Two call flows ask the same question of the same API. A peer-to-peer call and
  a channel conference each open a dialog offering three lists to pick from —
  audio in, video in, audio out — and each is handed whatever
  `enumerateDevices()` returned, which is a shape nobody here controls: keys
  that may be strings or atoms, an `id` that may be a `deviceId`, a label the
  browser withholds until permission is granted.

  Every list is present even when empty, because the dialog renders three
  pickers whether or not the browser found anything to put in them, and a
  missing key would take the dialog down rather than show it empty.

  The fallback label is the caller's, not this module's: an unnamed device is
  copy the dialog around it owns, and each flow translates it in its own
  catalogue.
  """

  @kinds [audioinput: "audioinput", videoinput: "videoinput", audiooutput: "audiooutput"]
  @preference_keys [:audio_input_id, :video_input_id, :audio_output_id]

  @typedoc "One device as a picker shows it."
  @type device :: %{required(String.t()) => String.t()}

  @typedoc "The three lists, always all three."
  @type listing :: %{required(String.t()) => [device()]}

  @typedoc "Which device of each kind was chosen, if any."
  @type preferences :: %{
          audio_input_id: String.t() | nil,
          video_input_id: String.t() | nil,
          audio_output_id: String.t() | nil
        }

  @doc "The kinds a browser reports, in the order the dialogs offer them."
  @spec kinds() :: [String.t()]
  def kinds, do: Enum.map(@kinds, &elem(&1, 1))

  @doc "Three empty lists: what a dialog shows before the browser has answered."
  @spec none() :: listing()
  def none, do: Map.new(@kinds, fn {_name, kind} -> {kind, []} end)

  @doc """
  The browser's answer, as the pickers need it.

  Anything unrecognisable — a kind that is not a list, a payload that is not a
  map — comes back empty rather than raising, because this arrives from the
  client and a malformed one must not take the dialog with it.
  """
  @spec normalize(term(), String.t()) :: listing()
  def normalize(payload, unnamed) when is_map(payload) do
    Map.new(@kinds, fn {name, kind} -> {kind, devices_of(payload, name, unnamed)} end)
  end

  def normalize(_payload, _unnamed), do: none()

  @doc "The lists a dialog holds, with any kind it is missing filled in empty."
  @spec listing(term()) :: listing()
  def listing(%{devices: devices}) when is_map(devices), do: Map.merge(none(), devices)
  def listing(_source), do: none()

  @doc "Nothing chosen yet, which is what a person gets before they pick."
  @spec no_preference() :: preferences()
  def no_preference, do: Map.new(@preference_keys, &{&1, nil})

  @doc """
  Which device of each kind was chosen.

  Read from the top level or from a nested `device_preferences`, whichever the
  caller holds it under, so a stored preference and a form submission both go
  through the same reading.
  """
  @spec preferences(term()) :: preferences()
  def preferences(source) when is_map(source) do
    nested = key(source, :device_preferences)

    Map.new(@preference_keys, fn preference_key ->
      {preference_key, device_id(key(source, preference_key) || key(nested, preference_key))}
    end)
  end

  def preferences(_source), do: no_preference()

  @doc "A device id, or nothing — an empty one is nothing rather than a choice."
  @spec device_id(term()) :: String.t() | nil
  def device_id(nil), do: nil
  def device_id(""), do: nil
  def device_id(id) when is_binary(id), do: id
  def device_id(id), do: to_string(id)

  defp devices_of(payload, name, unnamed) do
    case key(payload, name) do
      devices when is_list(devices) -> Enum.map(devices, &device(&1, unnamed))
      _other -> []
    end
  end

  defp device(device, unnamed) do
    %{
      "id" => to_string(key(device, :id) || key(device, :deviceId) || ""),
      "label" => to_string(key(device, :label) || unnamed)
    }
  end

  defp key(source, name) when is_map(source) and is_atom(name) do
    case source do
      %{^name => value} -> value
      _other -> Map.get(source, Atom.to_string(name))
    end
  end

  defp key(_source, _name), do: nil
end
