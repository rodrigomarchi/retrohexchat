defmodule RetroHexChatWeb.Components.UI.AdminMotdDialog do
  @moduledoc """
  Admin MOTD window — the server's message of the day.

  Shows what is set now above the editor, so an admin can see what they are
  replacing. Server operators can read the window but not edit it.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :content, :string, default: nil
  attr :result, :any, default: nil
  attr :editable, :boolean, default: false
  attr :on_set, :any, default: nil
  attr :on_clear, :any, default: nil
  attr :on_refresh, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_motd_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_motd_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-2xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "MOTD")} on_close={@on_cancel}>
        <:icon><Icons.icon_notepad class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_motd_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :content, :string, default: nil
  attr :result, :any, default: nil
  attr :editable, :boolean, default: false
  attr :on_set, :any, default: nil
  attr :on_clear, :any, default: nil
  attr :on_refresh, :any, default: nil

  @spec admin_motd_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_motd_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-motd-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <div>
            <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Current MOTD")}</div>
            <div
              id="admin-motd-current"
              class="shadow-retro-sunken bg-white min-h-[82px] max-h-[120px] overflow-y-auto p-retro-8 text-sm whitespace-pre-wrap"
            >
              <%= if present?(@content) do %>
                {@content}
              <% else %>
                <span class="text-muted-foreground">
                  {dgettext("dialogs", "No MOTD has been set.")}
                </span>
              <% end %>
            </div>
          </div>

          <form
            id="admin-motd-form"
            phx-submit={@on_set}
            phx-target={@target}
            class="space-y-retro-4"
          >
            <label for="admin-motd-input" class="block text-xs font-bold">
              {dgettext("dialogs", "New MOTD")}
            </label>
            <textarea
              id="admin-motd-input"
              name="motd"
              class="w-full shadow-retro-sunken bg-white px-retro-6 py-retro-4 text-sm resize-y min-h-[70px]"
              disabled={not @editable}
              autocomplete="off"
            >{@content || ""}</textarea>

            <div class="flex flex-wrap justify-end gap-retro-4">
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click={@on_refresh}
                phx-target={@target}
              >
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh")}
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click={@on_clear}
                phx-target={@target}
                disabled={not @editable}
              >
                <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Clear MOTD")}
              </.button>
              <.button type="submit" size="sm" disabled={not @editable}>
                <:icon><Icons.icon_btn_save class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Set MOTD")}
              </.button>
            </div>
          </form>

          <div
            :if={@result}
            class={[
              "shadow-retro-sunken bg-black font-mono text-xs p-retro-6",
              if(Map.get(@result, :status) == :error, do: "text-red-400", else: "text-green-400")
            ]}
            data-testid="admin-motd-result"
          >
            {Map.get(@result, :message, "")}
          </div>
        </div>
      </div>
    </div>
    """
  end
end
