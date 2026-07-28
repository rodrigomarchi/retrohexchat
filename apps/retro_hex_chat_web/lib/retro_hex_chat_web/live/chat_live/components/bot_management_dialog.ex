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

  alias RetroHexChat.Bots.Queries
  alias RetroHexChatWeb.PaginatedList

  @id "bot-management-dialog"
  @events_page_size 50

  @spec id() :: String.t()
  def id, do: @id

  @owned_defaults %{
    show_bot: false,
    bots: [],
    selected: nil,
    channels: [],
    commands: [],
    stats: nil,
    tab: :general,
    show_new_bot: false,
    show_add_command: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    # A managed window mounts fresh on open, so the bot list is loaded here — it
    # rides the mount's own render (the main diff), which is always DOM-safe.
    # Delivering it via a post-mount send_update races the mount patch client-side
    # (see AGENT-GUIDE §7 / the REVERSED gotcha).
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(:is_admin, false)
     |> assign(@owned_defaults)
     |> assign(:bots, Queries.list_bots())
     |> PaginatedList.init(:events, page_size: @events_page_size)}
  end

  @doc """
  Fetches the next page of the selected bot's event log.

  The island owns this: the parent hook loads the first page when a bot is
  selected and hands it over, but paging deeper never leaves the component.
  """
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("load_more", _params, %{assigns: %{selected: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    bot_id = socket.assigns.selected.id

    {:noreply, PaginatedList.load(socket, :events, &Queries.list_event_logs(bot_id, &1))}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{events: %RetroHexChat.Page{} = page} = assigns, socket) do
    {:ok,
     socket
     |> assign(Map.delete(assigns, :events))
     |> PaginatedList.reset(:events, page)}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.bot_management_dialog
        id={@id}
        windowed
        show={@show_bot}
        bots={@bots}
        selected={@selected}
        channels={@channels}
        commands={@commands}
        events={@streams.events}
        events_state={@paginated.events}
        events_target={@myself}
        stats={@stats}
        is_admin={@is_admin}
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
