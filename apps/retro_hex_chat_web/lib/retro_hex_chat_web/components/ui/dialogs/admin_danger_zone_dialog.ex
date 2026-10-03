defmodule RetroHexChatWeb.Components.UI.AdminDangerZoneDialog do
  @moduledoc """
  Admin Danger Zone window — the factory reset.

  Shows what a wipe would remove and what survives it, then requires the
  server's own name typed in before the button is even enabled. The server
  checks the same thing; the disabled button is the courtesy, not the guard.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :preview, :string, default: nil
  attr :result, :any, default: nil
  attr :confirm, :string, default: ""
  attr :server_name, :string, default: "RetroHexChat"
  attr :can_execute, :boolean, default: false
  attr :on_preview, :any, default: nil
  attr :on_change, :any, default: nil
  attr :on_execute, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_danger_zone_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_danger_zone_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-lg">
      <.dialog_header id={@id} title={dgettext("dialogs", "Danger Zone")} on_close={@on_cancel}>
        <:icon><Icons.icon_warning class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_danger_zone_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :preview, :string, default: nil
  attr :result, :any, default: nil
  attr :confirm, :string, default: ""
  attr :server_name, :string, default: "RetroHexChat"
  attr :can_execute, :boolean, default: false
  attr :on_preview, :any, default: nil
  attr :on_change, :any, default: nil
  attr :on_execute, :any, default: nil

  @spec admin_danger_zone_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_danger_zone_panel(assigns) do
    assigns =
      assign(
        assigns,
        :confirmation_matches?,
        assigns.can_execute and assigns.confirm == assigns.server_name
      )

    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-danger-zone-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <.dialog_banner heading={dgettext("dialogs", "What is left afterwards")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:checklist}
            title={dgettext("dialogs", "Preserved")}
            lines={preserved_lines()}
            label={dgettext("dialogs", "A miniature of the four lists the wipe keeps")}
          />
        </:art>
        <:glyph><Icons.icon_warning class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "This action deletes the conversations, the channels and the nicknames. Four lists are kept: the administrators, the bans, the settings and the audit log. Everything else is deleted permanently."
        )}
      </.dialog_banner>

      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <div class="shadow-retro-sunken bg-white p-retro-8 text-sm">
            <div class="font-bold text-destructive">
              {dgettext("dialogs", "This cannot be undone.")}
            </div>
            <div class="mt-retro-4">
              {dgettext(
                "dialogs",
                "Preserved: admin_roles, audit_logs, server_bans, server_settings"
              )}
            </div>
          </div>

          <pre
            id="admin-danger-zone-preview"
            class="shadow-retro-sunken bg-white min-h-[136px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
          ><%= @preview || "" %></pre>

          <form
            id="admin-danger-zone-form"
            phx-change={@on_change}
            phx-submit={@on_execute}
            phx-target={@target}
            class="space-y-retro-6"
          >
            <label for="admin-danger-zone-confirm" class="block text-xs font-bold">
              {dgettext("dialogs", "Type the server name to confirm: %{server_name}",
                server_name: @server_name
              )}
            </label>
            <input
              id="admin-danger-zone-confirm"
              name="confirm"
              type="text"
              value={@confirm}
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              autocomplete="off"
              disabled={not @can_execute}
            />

            <div class="flex flex-wrap justify-end gap-retro-4">
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click={@on_preview}
                phx-target={@target}
                disabled={not @can_execute}
              >
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh preview")}
              </.button>
              <.button
                type="submit"
                size="sm"
                variant="destructive"
                disabled={not @confirmation_matches?}
              >
                <:icon><Icons.icon_warning class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "NUKE EVERYTHING")}
              </.button>
            </div>
          </form>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end

  # Table names, not labels: these are what the wipe preserves, spelled the
  # way the database spells them.
  @spec preserved_lines() :: [map()]
  defp preserved_lines do
    Enum.map(
      ~w(admin_roles audit_logs server_bans server_settings),
      &%{text: &1, tone: :accent}
    )
  end
end
