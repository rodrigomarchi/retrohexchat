defmodule RetroHexChatWeb.Components.UI.BotFormDialog do
  @moduledoc """
  v2 Bot form dialogs: New Bot and Add Command.

  Uses v2 design system primitives (Dialog, Button, Input, Label, Checkbox).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  # ── New Bot Dialog ─────────────────────────────────────────

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, :any, default: nil

  @spec new_bot_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def new_bot_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-md">
      <.dialog_header id={@id} title={gettext("Create New Bot")}>
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form phx-submit="create_bot">
        <.dialog_body>
          <div class="space-y-retro-8">
            <div>
              <.label for="bot-name">{gettext("Name")}</.label>
              <.input id="bot-name" name="name" type="text" placeholder={gettext("MyBot")} required />
            </div>
            <div>
              <.label for="bot-nickname">{gettext("Nickname")}</.label>
              <.input id="bot-nickname" name="nickname" type="text" placeholder={gettext("MyBot")} />
            </div>
            <div>
              <.label for="bot-description">{gettext("Description")}</.label>
              <.input
                id="bot-description"
                name="description"
                type="text"
                placeholder={gettext("A helpful bot")}
              />
            </div>
            <div class="flex gap-retro-16">
              <div>
                <.label for="bot-prefix">{gettext("Command Prefix")}</.label>
                <.input id="bot-prefix" name="prefix" type="text" value="!" class="w-[60px]" />
              </div>
              <div>
                <.label for="bot-cooldown">{gettext("Cooldown (s)")}</.label>
                <.input id="bot-cooldown" name="cooldown" type="number" value="3" class="w-[80px]" />
              </div>
            </div>
            <fieldset class="shadow-retro-sunken p-retro-8">
              <legend class="text-xs font-bold px-retro-4">{gettext("Capabilities")}</legend>
              <div class="grid grid-cols-2 gap-retro-4">
                <.checkbox_item
                  id="cap-mention"
                  name="cap_mention"
                  label={gettext("Mention Response")}
                />
                <.checkbox_item id="cap-greeter" name="cap_greeter" label={gettext("Greeter")} />
                <.checkbox_item
                  id="cap-custom-commands"
                  name="cap_custom_commands"
                  label={gettext("Custom Commands")}
                />
                <.checkbox_item id="cap-help" name="cap_help" label={gettext("Help")} />
                <.checkbox_item id="cap-dice" name="cap_dice" label={gettext("Dice")} />
                <.checkbox_item
                  id="cap-moderation"
                  name="cap_moderation"
                  label={gettext("Moderation")}
                />
                <.checkbox_item id="cap-trivia" name="cap_trivia" label={gettext("Trivia")} />
                <.checkbox_item id="cap-scheduler" name="cap_scheduler" label={gettext("Scheduler")} />
                <.checkbox_item id="cap-rss" name="cap_rss" label={gettext("RSS")} />
              </div>
            </fieldset>
          </div>
        </.dialog_body>
        <.dialog_footer>
          <.button type="submit">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {gettext("Create")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {gettext("Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end

  # ── Add Command Dialog ─────────────────────────────────────

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bot_name, :string, default: ""
  attr :on_close, :any, default: nil

  @spec add_command_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def add_command_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-md">
      <.dialog_header id={@id} title={gettext("Add Command — %{bot}", bot: @bot_name)}>
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form phx-submit="bot_add_command">
        <input type="hidden" name="bot_name" value={@bot_name} />
        <.dialog_body>
          <div class="space-y-retro-8">
            <div>
              <.label for="cmd-trigger">{gettext("Trigger")}</.label>
              <.input
                id="cmd-trigger"
                name="trigger"
                type="text"
                placeholder={gettext("!hello")}
                required
              />
              <p class="text-xs text-muted-foreground mt-retro-2">
                {gettext("The command that triggers this response (e.g. !hello)")}
              </p>
            </div>
            <div>
              <.label for="cmd-response">{gettext("Response")}</.label>
              <.input
                id="cmd-response"
                name="response"
                type="text"
                placeholder={gettext("Hello, {nick}!")}
                required
              />
              <p class="text-xs text-muted-foreground mt-retro-2">
                {gettext("Use {nick} for the caller's name, {channel} for the channel")}
              </p>
            </div>
            <div>
              <.label for="cmd-description">{gettext("Description")}</.label>
              <.input
                id="cmd-description"
                name="description"
                type="text"
                placeholder={gettext("Greets the user")}
              />
            </div>
          </div>
        </.dialog_body>
        <.dialog_footer>
          <.button type="submit">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {gettext("Add")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {gettext("Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end

  # ── Private: checkbox helper ────────────────────────────────

  defp checkbox_item(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-4">
      <.checkbox id={@id} name={@name} />
      <.label for={@id} class="text-xs cursor-pointer">{@label}</.label>
    </div>
    """
  end
end
