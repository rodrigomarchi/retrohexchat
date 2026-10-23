defmodule RetroHexChatWeb.ChatLive.Components.AdminDangerZoneDialog do
  @moduledoc """
  Stateful island for the Admin Danger Zone window.

  Owns the wipe preview, the typed confirmation and the outcome strip. Mounted
  inside a server-managed window: presence in the DOM means open, so closing
  unmounts the island and the half-typed confirmation goes with it.

  The confirmation is checked twice on purpose. The disabled button compares
  against the server name loaded with the preview; the handler re-reads it at
  execution time. If the server was renamed in between, the handler is the one
  that decides — a stale button must never be what authorizes a wipe.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminDangerZoneDialog

  alias RetroHexChat.Admin
  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  @fallback_server_name "RetroHexChat"

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "admin-danger-zone-dialog",
    initial: %{
      preview: nil,
      result: nil,
      confirm: "",
      server_name: @fallback_server_name,
      loaded?: false
    },
    load: &assign_preview(&1, nil)

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_danger_zone_preview", _params, socket) do
    AdminOps.guarded(socket, fn -> {:noreply, assign_preview(socket, nil)} end)
  end

  def handle_event("admin_danger_zone_change", %{"confirm" => confirm}, socket) do
    AdminOps.guarded(socket, fn -> {:noreply, assign(socket, confirm: confirm)} end)
  end

  def handle_event("admin_danger_zone_execute", %{"confirm" => confirm}, socket) do
    AdminOps.guarded(socket, fn ->
      if confirm == Admin.server_name() do
        result = AdminOps.dispatch(socket, "admin", ["nuke", "--confirm"])

        {:noreply,
         assign(socket,
           preview: AdminOps.result_message(result),
           result: AdminOps.result_entry(result),
           confirm: ""
         )}
      else
        {:noreply,
         assign(socket,
           confirm: confirm,
           result: %{
             status: :error,
             message: dgettext("chat", "Type the server name to confirm.")
           }
         )}
      end
    end)
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, can_execute: ChatContext.admin_only?(assigns.session))

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_danger_zone_panel
        id={@id}
        target={@myself}
        preview={@preview}
        result={@result}
        confirm={@confirm}
        server_name={@server_name}
        can_execute={@can_execute}
        on_preview="admin_danger_zone_preview"
        on_change="admin_danger_zone_change"
        on_execute="admin_danger_zone_execute"
      />
    </div>
    """
  end

  defp assign_preview(socket, result) do
    preview = AdminOps.dispatch(socket, "admin", ["nuke"])

    assign(socket,
      preview: AdminOps.result_message(preview),
      result: result || AdminOps.first_error_entry([preview]),
      confirm: "",
      server_name: Admin.server_name()
    )
  end
end
