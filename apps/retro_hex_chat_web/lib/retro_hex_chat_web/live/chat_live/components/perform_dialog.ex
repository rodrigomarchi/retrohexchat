defmodule RetroHexChatWeb.ChatLive.Components.PerformDialog do
  @moduledoc """
  Stateful island for the Perform dialog — the two-tab mini-app that manages the
  auto-execute command list (perform on connect) and the auto-join channel list,
  each with its own add/edit/remove sub-form modal.

  Owns the ENTIRE dialog: the `show`/`active_tab` flags, both selections, all four
  sub-form `show_*` flags, every event, and the `PerformList`/`AutoJoinList`
  business logic that used to live in the `perform_autojoin_events` hook. Nothing
  about the dialog's own state lives in `ChatLive` anymore — the parent only routes
  the open trigger here via `send_update` and persists the resulting session.

  Every UI event targets this component (`phx-target={@target}` threaded through the
  design-system `perform_dialog/1`), so the four `fixed inset-0` add/edit sub-forms
  submit to the component that owns their DOM subtree — the component-id matches, so
  LiveView preserves the typed input across background re-renders (the modal-in-modal
  anti-pattern, §0a-anti, fixed at the root). The main dialog's Close/OK/Cancel and
  its own Escape/click-away fire `close_perform_dialog` on the parent LiveView, which
  reflects back via `send_update(close: true)`.

  The perform/autojoin lists live on the `session`, which is the central chat
  read-model (the connect flow auto-runs perform, the composer and every other
  dialog read it) — so it stays in the parent (§1d). The dialog runs the list
  mutations here and bubbles the new session up via
  `send(self(), {:perform_dialog_session, session, kind})`; the parent assigns it
  and fires the fire-and-forget persistence. Validation errors that belong to the
  chat surface bubble via `send(self(), {:perform_system_error, msg})`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.PerformDialog

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AutoJoinList, PerformList}

  @id "perform-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @closed %{
    show: false,
    active_tab: "commands",
    perform_selected: nil,
    autojoin_selected: nil,
    show_perform_add_dialog: false,
    show_perform_edit_dialog: false,
    show_autojoin_add_dialog: false,
    show_autojoin_edit_dialog: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(@closed)
     |> assign(session: nil)}
  end

  # ── Directives (driven by parent send_update) ────────────────────

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{open: tab}, socket) do
    {:ok, assign(socket, %{@closed | show: true, active_tab: tab || "commands"})}
  end

  def update(%{close: true}, socket), do: {:ok, assign(socket, @closed)}

  def update(%{toggle: true}, socket) do
    if socket.assigns.show do
      {:ok, assign(socket, @closed)}
    else
      {:ok, assign(socket, %{@closed | show: true})}
    end
  end

  # passthrough context (session)
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # ── Selection ────────────────────────────────────────────────────
  # (Tab switching is client-side CSS in the design-system tabs; the server only
  # sets the initial `active_tab` when the dialog is opened.)

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("perform_select", %{"position" => pos}, socket) do
    {:noreply, assign(socket, perform_selected: String.to_integer(pos))}
  end

  def handle_event("autojoin_select", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, autojoin_selected: channel)}
  end

  # ── Sub-form open/close ──────────────────────────────────────────

  def handle_event("perform_dialog_add", _params, socket) do
    {:noreply, assign(socket, show_perform_add_dialog: true)}
  end

  def handle_event("close_perform_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_perform_add_dialog: false)}
  end

  def handle_event("perform_dialog_edit", _params, socket) do
    if socket.assigns.perform_selected do
      {:noreply, assign(socket, show_perform_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_perform_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_perform_edit_dialog: false)}
  end

  def handle_event("autojoin_dialog_add", _params, socket) do
    {:noreply, assign(socket, show_autojoin_add_dialog: true)}
  end

  def handle_event("close_autojoin_add_dialog", _params, socket) do
    {:noreply, assign(socket, show_autojoin_add_dialog: false)}
  end

  def handle_event("autojoin_dialog_edit", _params, socket) do
    if socket.assigns.autojoin_selected do
      {:noreply, assign(socket, show_autojoin_edit_dialog: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_autojoin_edit_dialog", _params, socket) do
    {:noreply, assign(socket, show_autojoin_edit_dialog: false)}
  end

  # ── Perform list mutations ───────────────────────────────────────

  def handle_event("perform_dialog_add_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_perform_add_dialog: false)
         |> put_perform_session(new_session)}

      {:error, reason} ->
        {:noreply,
         bubble_error(
           socket,
           dgettext("chat", "Failed to add perform command: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("perform_dialog_edit_confirm", %{"command" => command}, socket) do
    session = socket.assigns.session
    position = socket.assigns.perform_selected

    if position do
      updated_list = PerformList.update_entry(session.perform_list, position, command)
      new_session = Session.set_perform_list(session, updated_list)

      {:noreply,
       socket
       |> assign(show_perform_edit_dialog: false)
       |> put_perform_session(new_session)}
    else
      {:noreply, assign(socket, show_perform_edit_dialog: false)}
    end
  end

  def handle_event("perform_dialog_remove", _params, socket) do
    position = socket.assigns.perform_selected
    session = socket.assigns.session

    with true <- position != nil,
         {:ok, updated_list} <- PerformList.remove_entry(session.perform_list, position) do
      {:noreply,
       socket
       |> assign(perform_selected: nil)
       |> put_perform_session(Session.set_perform_list(session, updated_list))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("perform_dialog_move_up", _params, socket) do
    {:noreply, move_perform(socket, -1)}
  end

  def handle_event("perform_dialog_move_down", _params, socket) do
    {:noreply, move_perform(socket, +1)}
  end

  def handle_event("perform_toggle_enabled", _params, socket) do
    session = socket.assigns.session
    current = PerformList.enabled?(session.perform_list)
    updated_list = PerformList.set_enabled(session.perform_list, !current)

    {:noreply, put_perform_session(socket, Session.set_perform_list(session, updated_list))}
  end

  # ── Autojoin list mutations ──────────────────────────────────────

  def handle_event("autojoin_dialog_add_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = blank_to_nil(params["key"])

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_autojoin_add_dialog: false)
         |> put_autojoin_session(new_session)}

      {:error, reason} ->
        {:noreply,
         bubble_error(
           socket,
           dgettext("chat", "Failed to add auto-join channel: %{reason}", reason: reason)
         )}
    end
  end

  def handle_event("autojoin_dialog_edit_confirm", %{"channel" => channel} = params, socket) do
    session = socket.assigns.session
    key = blank_to_nil(params["key"])

    case AutoJoinList.update_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        {:noreply,
         socket
         |> assign(show_autojoin_edit_dialog: false)
         |> put_autojoin_session(new_session)}

      {:error, _} ->
        {:noreply, assign(socket, show_autojoin_edit_dialog: false)}
    end
  end

  def handle_event("autojoin_dialog_remove", _params, socket) do
    channel = socket.assigns.autojoin_selected
    session = socket.assigns.session

    with true <- channel != nil,
         {:ok, updated_list} <- AutoJoinList.remove_entry(session.autojoin_list, channel) do
      {:noreply,
       socket
       |> assign(autojoin_selected: nil)
       |> put_autojoin_session(Session.set_autojoin_list(session, updated_list))}
    else
      _ -> {:noreply, socket}
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        perform_entries: PerformList.entries(assigns.session.perform_list),
        perform_enabled: PerformList.enabled?(assigns.session.perform_list),
        autojoin_entries: AutoJoinList.entries(assigns.session.autojoin_list)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.perform_dialog
        id={@id}
        target={@myself}
        show={@show}
        active_tab={@active_tab}
        perform_entries={@perform_entries}
        perform_selected={@perform_selected}
        perform_enabled={@perform_enabled}
        autojoin_entries={@autojoin_entries}
        autojoin_selected={@autojoin_selected}
        show_perform_add_dialog={@show_perform_add_dialog}
        show_perform_edit_dialog={@show_perform_edit_dialog}
        show_autojoin_add_dialog={@show_autojoin_add_dialog}
        show_autojoin_edit_dialog={@show_autojoin_edit_dialog}
        on_select="perform_select"
        on_add="perform_dialog_add"
        on_edit="perform_dialog_edit"
        on_remove="perform_dialog_remove"
        on_move_up="perform_dialog_move_up"
        on_move_down="perform_dialog_move_down"
        on_toggle_enabled="perform_toggle_enabled"
        on_autojoin_select="autojoin_select"
        on_autojoin_add="autojoin_dialog_add"
        on_autojoin_edit="autojoin_dialog_edit"
        on_autojoin_remove="autojoin_dialog_remove"
        on_ok="close_perform_dialog"
        on_cancel="close_perform_dialog"
      />
    </div>
    """
  end

  # ── Internal helpers ─────────────────────────────────────────────

  defp move_perform(socket, delta) do
    position = socket.assigns.perform_selected
    session = socket.assigns.session
    target = if position, do: position + delta, else: nil

    with true <- valid_move?(position, target, session, delta),
         {:ok, updated_list} <- PerformList.move_entry(session.perform_list, position, target) do
      socket
      |> assign(perform_selected: target)
      |> put_perform_session(Session.set_perform_list(session, updated_list))
    else
      _ -> socket
    end
  end

  defp valid_move?(nil, _target, _session, _delta), do: false
  defp valid_move?(position, _target, _session, -1), do: position > 0

  defp valid_move?(position, _target, session, +1),
    do: position < PerformList.count(session.perform_list) - 1

  # Optimistically reflect the new session locally (entries refresh this cycle)
  # while the parent assigns it as the canonical read-model and persists it.
  defp put_perform_session(socket, session) do
    send(self(), {:perform_dialog_session, session, :perform})
    assign(socket, session: session)
  end

  defp put_autojoin_session(socket, session) do
    send(self(), {:perform_dialog_session, session, :autojoin})
    assign(socket, session: session)
  end

  defp bubble_error(socket, message) do
    send(self(), {:perform_system_error, message})
    socket
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
