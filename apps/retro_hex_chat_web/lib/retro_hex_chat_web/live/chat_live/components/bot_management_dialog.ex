defmodule RetroHexChatWeb.ChatLive.Components.BotManagementDialog do
  @moduledoc """
  Stateful island for the Bot Management mini-app (plans 49 + 50 + 51).

  Owns the full bot-dialog state — bot list/selection, the selected bot's
  channels/commands/events/stats, the active tab, the inline-edit field, and the
  visibility of all three dialogs (management + new-bot form + add-command form,
  the two child forms consolidated here rather than as separate parent dialogs).

  **Full extraction (no parent read-model).** Every `bot_events.ex` handler reads
  its inputs from params, never from `socket.assigns.bot_dialog_*`, so all 11
  assigns moved here cleanly. The handlers stay STRING adapters (the
  `bot_management_entry_points_feature_test` fires them by name and they need the
  privileged `Bots.*`/`Queries` work with the session) and reflect results via
  `send_update` (the events module's `put_bot/2`). Not Escape-managed → this
  component owns the three `show` flags. The child new-bot/add-command dialogs are
  plain `<.dialog>` (not `fixed inset-0` sub-forms), so there is no modal-in-modal
  clobber; their forms submit the existing string events to the parent.

  Admin permission arrives as the `is_admin` snapshot from `ChatContext`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.BotManagementDialog
  import RetroHexChatWeb.Components.UI.BotFormDialog

  @id "bot-management-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @owned_defaults %{
    show_bot: false,
    bots: [],
    selected: nil,
    channels: [],
    commands: [],
    events: [],
    stats: nil,
    tab: :general,
    editing_field: nil,
    show_new_bot: false,
    show_add_command: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(:is_admin, false)
     |> assign(@owned_defaults)}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.bot_management_dialog
        id={@id}
        show={@show_bot}
        bots={@bots}
        selected={@selected}
        channels={@channels}
        commands={@commands}
        events={@events}
        stats={@stats}
        active_tab={@tab}
        is_admin={@is_admin}
        editing_field={@editing_field}
        on_close="close_bot_dialog"
      />

      <.new_bot_dialog id="new-bot-dialog" show={@show_new_bot} on_close="close_new_bot_dialog" />

      <.add_command_dialog
        id="add-command-dialog"
        show={@show_add_command}
        bot_name={if @selected, do: @selected.name, else: ""}
        on_close="close_add_command_dialog"
      />
    </div>
    """
  end
end
