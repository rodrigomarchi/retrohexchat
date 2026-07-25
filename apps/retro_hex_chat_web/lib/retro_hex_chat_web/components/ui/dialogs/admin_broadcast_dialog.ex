defmodule RetroHexChatWeb.Components.UI.AdminBroadcastDialog do
  @moduledoc """
  Admin Broadcast window — send a message to the whole server.

  Two reaches, gated separately: wallops goes to users who opted in with +w and
  is open to server operators; announce goes to everyone and is admin-only.
  Write-only — there is nothing to read back.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :result, :any, default: nil
  attr :can_wallops, :boolean, default: false
  attr :can_announce, :boolean, default: false
  attr :on_send, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_broadcast_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_broadcast_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-lg">
      <.dialog_header id={@id} title={dgettext("dialogs", "Broadcast")} on_close={@on_cancel}>
        <:icon><Icons.icon_megaphone class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_broadcast_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :result, :any, default: nil
  attr :can_wallops, :boolean, default: false
  attr :can_announce, :boolean, default: false
  attr :on_send, :any, default: nil

  @spec admin_broadcast_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_broadcast_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-broadcast-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <form
            id="admin-broadcast-form"
            phx-submit={@on_send}
            phx-target={@target}
            class="space-y-retro-8"
          >
            <fieldset class="flex flex-wrap gap-retro-6">
              <label class="inline-flex items-center gap-retro-4 text-sm">
                <input
                  type="radio"
                  name="broadcast_type"
                  value="wallops"
                  checked
                  disabled={not @can_wallops}
                />
                <span class="font-bold">{dgettext("dialogs", "Wallops")}</span>
              </label>
              <label class="inline-flex items-center gap-retro-4 text-sm">
                <input
                  type="radio"
                  name="broadcast_type"
                  value="announce"
                  disabled={not @can_announce}
                />
                <span class="font-bold">{dgettext("dialogs", "Announce")}</span>
              </label>
            </fieldset>

            <div>
              <label for="admin-broadcast-message" class="block text-xs font-bold mb-retro-4">
                {dgettext("dialogs", "Message")}
              </label>
              <textarea
                id="admin-broadcast-message"
                name="message"
                class="w-full shadow-retro-sunken bg-white px-retro-6 py-retro-4 text-sm resize-y min-h-[116px]"
                autocomplete="off"
              ></textarea>
            </div>

            <div class="flex justify-end">
              <.button type="submit" size="sm" disabled={not (@can_wallops or @can_announce)}>
                <:icon><Icons.icon_megaphone class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Send broadcast")}
              </.button>
            </div>
          </form>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end
end
