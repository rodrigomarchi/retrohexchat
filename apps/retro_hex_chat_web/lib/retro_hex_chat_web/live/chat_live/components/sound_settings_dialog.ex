defmodule RetroHexChatWeb.ChatLive.Components.SoundSettingsDialog do
  @moduledoc """
  Stateful LiveComponent for Sound Settings — a draft-with-preview dialog.
  The parent keeps `show_sound_settings_dialog` (Escape map) and passes it as
  `visible`; the component owns the editable `draft` (a `SoundSettings` struct).

  Flash toggle and preview are component-local (`@myself`) — preview pushes
  `play_sound` straight to the client. The sound-dropdown change must be an event
  STRING (the design-system `select_item` does `JS.push(on_sound_change, value:)`,
  which only accepts a string), so it bubbles to the parent, which forwards the raw
  params back via `send_update` ({:change, params}) — the component applies the
  change to its own draft. Apply/OK must commit the draft into the parent's
  `session` (so future event sounds use it) + persist; since the draft is a struct
  the component hands it up via `send(self(), {:commit_sound_settings, ...})` and
  `SettingsDialogsEvents.handle_info/2` performs the commit (and, for OK, the
  close). Cancel bubbles `close_sound_settings_dialog` to the parent.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.SoundSettingsDialog

  alias RetroHexChat.Chat.SoundSettings

  @id "sound-settings-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: {:ok, assign(socket, id: @id, visible: false, draft: nil)}

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open, settings}}, socket), do: {:ok, assign(socket, draft: settings)}
  def update(%{action: :close}, socket), do: {:ok, assign(socket, draft: nil)}

  def update(%{action: {:change, params}}, socket) do
    {:ok,
     assign(socket, draft: apply_change(socket.assigns.draft || SoundSettings.new(), params))}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, visible: Map.get(assigns, :visible, socket.assigns.visible))}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("sound_flash_toggle", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    draft = socket.assigns.draft

    {:noreply,
     assign(socket,
       draft: SoundSettings.set_flash(draft, event, not SoundSettings.get_flash(draft, event))
     )}
  end

  def handle_event("sound_preview", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    sound = SoundSettings.get_sound(socket.assigns.draft, event)

    if sound == "none" do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "play_sound", %{type: sound})}
    end
  end

  def handle_event("sound_settings_apply", _params, socket) do
    send(self(), {:commit_sound_settings, socket.assigns.draft, :apply})
    {:noreply, socket}
  end

  def handle_event("sound_settings_ok", _params, socket) do
    send(self(), {:commit_sound_settings, socket.assigns.draft, :ok})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.sound_settings_dialog
        id={@id}
        show={@visible}
        settings={@draft || %{}}
        on_ok={JS.push("sound_settings_ok", target: @myself)}
        on_cancel="close_sound_settings_dialog"
        on_apply={JS.push("sound_settings_apply", target: @myself)}
        on_sound_change="sound_settings_change"
        on_flash_toggle={JS.push("sound_flash_toggle", target: @myself)}
        on_preview={JS.push("sound_preview", target: @myself)}
      />
    </div>
    """
  end

  # Applies either a single dropdown pick (%{"event", "sound"}) or a bulk form
  # change (%{"event_<type>" => sound}) to the draft. Called from `update/2` because
  # the change event must be a string (see moduledoc) and so arrives via the parent.
  @spec apply_change(term(), map()) :: term()
  defp apply_change(draft, %{"event" => event_str, "sound" => sound_name}) do
    SoundSettings.set_sound(draft, String.to_existing_atom(event_str), sound_name)
  end

  defp apply_change(draft, params) do
    Enum.reduce(SoundSettings.event_types(), draft, fn event, acc ->
      case Map.get(params, "event_#{event}") do
        nil -> acc
        sound_name -> SoundSettings.set_sound(acc, event, sound_name)
      end
    end)
  end
end
