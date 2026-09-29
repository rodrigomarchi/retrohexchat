defmodule RetroHexChatWeb.Components.UI.AutojoinDialog do
  @moduledoc """
  Win98-style Auto-Join dialog component for the showcase design system.

  Manages the list of channels joined automatically on connect, each with an
  optional channel key. Supports add, edit (key only — the channel name is the
  identity) and remove.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc """
  Renders a framed Win98-style Auto-Join dialog. Used by the showcase; the
  desktop window mounts `autojoin_panel/1` instead.

  ## Examples

      <.autojoin_dialog
        id="autojoin"
        show={true}
        entries={[%{channel_name: "#lobby", channel_key: nil}]}
      />
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :show, :boolean, default: false
  attr :entries, :list, default: []
  attr :selected, :string, default: nil
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_ok, :any, default: nil
  attr :on_cancel, :any, default: nil

  @spec autojoin_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def autojoin_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      lock={@show_add_dialog || @show_edit_dialog}
      on_cancel={@on_cancel}
    >
      <.dialog_header id={@id} title={dgettext("dialogs", "Auto-Join")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_autojoin /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.autojoin_panel
          id={@id}
          target={@target}
          entries={@entries}
          selected={@selected}
          show_add_dialog={@show_add_dialog}
          show_edit_dialog={@show_edit_dialog}
          on_add={@on_add}
          on_edit={@on_edit}
          on_remove={@on_remove}
          sub_scope={:viewport}
        />
      </.dialog_body>
      <.dialog_footer>
        <.button phx-click={@on_ok}>
          <:icon><Icons.icon_checkmark /></:icon>
          {dgettext("dialogs", "OK")}
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close /></:icon>
          {dgettext("dialogs", "Cancel")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  @doc """
  Renders the Auto-Join content (channel list + the add/edit sub-form modals)
  without any frame — compose it inside a dialog or a desktop window body.
  `sub_scope` decides where the sub-form modals anchor.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :entries, :list, default: []
  attr :selected, :string, default: nil
  attr :show_add_dialog, :boolean, default: false
  attr :show_edit_dialog, :boolean, default: false
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :on_close, :any, default: nil
  attr :sub_scope, :atom, default: :window, values: [:viewport, :window]

  @spec autojoin_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def autojoin_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="autojoin-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="aj-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <div class="aj-entry-list min-h-0 flex-1 overflow-y-auto">
            <div :if={@entries == []} class="aj-empty-state text-center text-muted-foreground">
              {dgettext("dialogs", "No auto-join channels. Click Add to create one.")}
            </div>

            <.action_list
              :if={@entries != []}
              id={"#{@id}-entries"}
              label={dgettext("dialogs", "Auto-Join")}
            >
              <.action_row
                :for={entry <- @entries}
                on_activate={@on_edit}
                value={%{"channel" => entry.channel_name}}
                target={@target}
                current={@selected == entry.channel_name}
                data-testid="autojoin-row"
                data-channel={entry.channel_name}
              >
                <:title>{entry.channel_name}</:title>
                <:meta>
                  {dgettext("dialogs", "Key")}: {if entry.channel_key,
                    do: "***",
                    else: dgettext("dialogs", "none")}
                </:meta>
                <:action
                  event={@on_remove}
                  value={%{"channel" => entry.channel_name}}
                  label={dgettext("dialogs", "Remove %{channel}", channel: entry.channel_name)}
                  variant="destructive"
                  testid={"autojoin-remove-#{entry.channel_name}"}
                >
                  <Icons.icon_btn_remove class="w-4 h-4" />
                </:action>
              </.action_row>
            </.action_list>
          </div>

          <div class="aj-action-row flex gap-1">
            <.button size="sm" phx-click={@on_add} phx-target={@target} class="aj-action-button">
              <:icon><Icons.icon_btn_add /></:icon>
              {dgettext("dialogs", "Add")}
            </.button>
          </div>

          <div :if={@on_close} class="aj-dialog-footer flex justify-end">
            <.button
              type="button"
              size="sm"
              phx-click={@on_close}
              phx-target={@target}
              class="aj-action-button"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>

        <%!-- Add Sub-Dialog --%>
        <.add_sub_form :if={@show_add_dialog} target={@target} scope={@sub_scope} />
        <%!-- Edit Sub-Dialog --%>
        <.edit_sub_form
          :if={@show_edit_dialog}
          target={@target}
          entries={@entries}
          selected={@selected}
          scope={@sub_scope}
        />
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ─────────────────────────────────────────

  attr :target, :any, default: nil

  attr :scope, :atom, default: :window

  defp add_sub_form(assigns) do
    ~H"""
    <.dialog
      id="autojoin-add-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_autojoin_add", target: @target)}
      class="md:max-w-xs"
    >
      <.dialog_header
        id="autojoin-add-modal"
        title={dgettext("dialogs", "Add Auto-Join Channel")}
        on_close={JS.push("close_autojoin_add", target: @target)}
      >
        <:icon><Icons.icon_dialog_autojoin /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="autojoin_add_confirm"
          phx-target={@target}
          data-testid="autojoin-add-dialog"
          class="aj-sub-form"
        >
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-channel-input">
              {dgettext("dialogs", "Channel")}:
            </label>
            <.input
              type="text"
              id="autojoin-channel-input"
              name="channel"
              maxlength="50"
              placeholder="#channel"
              required
              autofocus
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-key-input">
              {dgettext("dialogs", "Key")}:
            </label>
            <.input
              type="text"
              id="autojoin-key-input"
              name="key"
              maxlength="50"
              placeholder={dgettext("dialogs", "Leave empty if no key")}
              class="w-full"
            />
          </div>
          <div class="aj-form-actions flex justify-end gap-1">
            <.button type="submit" size="sm" class="aj-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_autojoin_add"
              phx-target={@target}
              class="aj-action-button"
            >
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :entries, :list, required: true
  attr :selected, :string, default: nil

  attr :scope, :atom, default: :window

  defp edit_sub_form(assigns) do
    entry = Enum.find(assigns.entries, fn e -> e.channel_name == assigns.selected end)

    assigns =
      assign(assigns,
        edit_channel: if(entry, do: entry.channel_name, else: ""),
        edit_key: if(entry, do: entry.channel_key, else: "")
      )

    ~H"""
    <.dialog
      id="autojoin-edit-modal"
      show
      scope={@scope}
      on_cancel={JS.push("close_autojoin_edit", target: @target)}
      class="md:max-w-xs"
    >
      <.dialog_header
        id="autojoin-edit-modal"
        title={dgettext("dialogs", "Edit Auto-Join Channel")}
        on_close={JS.push("close_autojoin_edit", target: @target)}
      >
        <:icon><Icons.icon_dialog_autojoin /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form
          phx-submit="autojoin_edit_confirm"
          phx-target={@target}
          data-testid="autojoin-edit-dialog"
          class="aj-sub-form"
        >
          <input type="hidden" name="channel" value={@edit_channel} />
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-edit-channel">
              {dgettext("dialogs", "Channel")}:
            </label>
            <.input
              type="text"
              id="autojoin-edit-channel"
              name="channel"
              value={@edit_channel}
              disabled
              class="w-full"
            />
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="autojoin-edit-key">
              {dgettext("dialogs", "Key")}:
            </label>
            <.input
              type="text"
              id="autojoin-edit-key"
              name="key"
              maxlength="50"
              value={@edit_key}
              autofocus
              class="w-full"
            />
          </div>
          <div class="aj-form-actions flex justify-end gap-1">
            <.button type="submit" size="sm" class="aj-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="close_autojoin_edit"
              phx-target={@target}
              class="aj-action-button"
            >
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Private Helpers ───────────────────────────────────
end
