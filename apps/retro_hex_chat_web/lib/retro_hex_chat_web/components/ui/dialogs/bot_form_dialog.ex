defmodule RetroHexChatWeb.Components.UI.BotFormDialog do
  @moduledoc """
  Bot form dialogs: New Bot and Add Command.

  Uses app design system primitives (Dialog, Button, Input, Label, Checkbox).

  Both lead with a banner, because neither form explains itself from its fields:
  a prefix and a cooldown say nothing about what a bot *is*, and a trigger with
  a response says nothing about who can call it. New Bot pictures the capability
  list with nothing ticked — a bot starts able to do nothing — and Add Command
  pictures the turns this bot already answers, so a second one reads as another
  of the same thing rather than as a setting.

  The nine capability checkboxes come from one list rather than nine copied
  blocks, so the picture and the form cannot drift apart.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  # ── New Bot Dialog ─────────────────────────────────────────

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, :any, default: nil

  @spec new_bot_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def new_bot_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} scope={:window} class="bm-form-dialog max-w-md">
      <.dialog_header id={@id} title={dgettext("dialogs", "Create New Bot")}>
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form phx-submit="create_bot" class="bm-form flex min-h-0 flex-1 flex-col">
        <.dialog_body class="bm-form-body">
          <div class="space-y-retro-8">
            <.dialog_banner heading={dgettext("dialogs", "A new bot can do nothing yet")}>
              <:art>
                <Diagrams.diagram_dialog_preview
                  kind={:checklist}
                  title={dgettext("dialogs", "Capabilities")}
                  lines={capability_lines()}
                  label={
                    dgettext(
                      "dialogs",
                      "A miniature of the list of capabilities. Nothing is selected yet."
                    )
                  }
                />
              </:art>
              <:glyph><Icons.icon_btn_bot_management class="h-8 w-8" /></:glyph>
              {dgettext(
                "dialogs",
                "People reach the bot by its name and its prefix. Each capability below is one more thing the bot can do. No capability is active until you select it. A bot with no capability does not answer."
              )}
            </.dialog_banner>

            <div>
              <.label for="bot-name">{dgettext("dialogs", "Name")}</.label>
              <.input
                id="bot-name"
                name="name"
                type="text"
                placeholder={dgettext("dialogs", "MyBot")}
                required
              />
            </div>
            <div>
              <.label for="bot-nickname">{dgettext("dialogs", "Nickname")}</.label>
              <.input
                id="bot-nickname"
                name="nickname"
                type="text"
                placeholder={dgettext("dialogs", "MyBot")}
              />
            </div>
            <div>
              <.label for="bot-description">{dgettext("dialogs", "Description")}</.label>
              <.input
                id="bot-description"
                name="description"
                type="text"
                placeholder={dgettext("dialogs", "A helpful bot")}
              />
            </div>
            <div class="bm-short-grid flex gap-retro-16">
              <div>
                <.label for="bot-prefix">{dgettext("dialogs", "Command Prefix")}</.label>
                <.input id="bot-prefix" name="prefix" type="text" value="!" class="w-[60px]" />
              </div>
              <div>
                <.label for="bot-cooldown">{dgettext("dialogs", "Cooldown (s)")}</.label>
                <.input id="bot-cooldown" name="cooldown" type="number" value="3" class="w-[80px]" />
              </div>
            </div>
            <fieldset class="shadow-retro-sunken p-retro-8">
              <legend class="text-xs font-bold px-retro-4">
                {dgettext("dialogs", "Capabilities")}
              </legend>
              <div class="bm-checkbox-grid grid grid-cols-2 gap-retro-4">
                <.checkbox_item
                  :for={capability <- capability_fields()}
                  id={capability.id}
                  name={capability.name}
                  label={capability.label}
                />
              </div>
            </fieldset>
          </div>
        </.dialog_body>
        <.dialog_footer class="bm-form-footer">
          <.button type="submit" class="bm-action-button">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Create")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close} class="bm-action-button">
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Cancel")}
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
  attr :prefix, :string, default: "!"

  attr :commands, :list,
    default: [],
    doc: "The bot's existing custom commands, so the banner draws a real turn"

  attr :on_close, :any, default: nil

  @spec add_command_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def add_command_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} scope={:window} class="bm-form-dialog max-w-md">
      <.dialog_header id={@id} title={dgettext("dialogs", "Add Command — %{bot}", bot: @bot_name)}>
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form phx-submit="bot_add_command" class="bm-form flex min-h-0 flex-1 flex-col">
        <input type="hidden" name="bot_name" value={@bot_name} />
        <.dialog_body class="bm-form-body">
          <div class="space-y-retro-8">
            <.dialog_banner heading={dgettext("dialogs", "The same answer, every time")}>
              <:art>
                <Diagrams.diagram_dialog_preview
                  kind={:query}
                  title={@bot_name}
                  lines={command_lines(@commands, @prefix, @bot_name)}
                  label={
                    dgettext(
                      "dialogs",
                      "A miniature of a command and the bot's answer to it"
                    )
                  }
                />
              </:art>
              <:glyph><Icons.icon_tab_commands class="h-8 w-8" /></:glyph>
              {dgettext(
                "dialogs",
                "Anyone in a channel where the bot is present can use this command, and everyone in that channel sees the answer. The bot always replies with the same line, so the text in the Response field is the text the channel will read."
              )}
            </.dialog_banner>

            <div>
              <.label for="cmd-trigger">{dgettext("dialogs", "Trigger")}</.label>
              <.input
                id="cmd-trigger"
                name="trigger"
                type="text"
                placeholder={dgettext("dialogs", "!hello")}
                required
              />
              <p class="text-xs text-muted-foreground mt-retro-2">
                {dgettext("dialogs", "The command that triggers this response (e.g. !hello)")}
              </p>
            </div>
            <div>
              <.label for="cmd-response">{dgettext("dialogs", "Response")}</.label>
              <.input
                id="cmd-response"
                name="response"
                type="text"
                placeholder={dgettext("dialogs", "Hello, {nick}!")}
                required
              />
              <p class="text-xs text-muted-foreground mt-retro-2">
                {dgettext("dialogs", "Use {nick} for the caller's name, {channel} for the channel")}
              </p>
            </div>
            <div>
              <.label for="cmd-description">{dgettext("dialogs", "Description")}</.label>
              <.input
                id="cmd-description"
                name="description"
                type="text"
                placeholder={dgettext("dialogs", "Greets the user")}
              />
            </div>
          </div>
        </.dialog_body>
        <.dialog_footer class="bm-form-footer">
          <.button type="submit" class="bm-action-button">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close} class="bm-action-button">
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end

  # ── Add Channel Dialog ─────────────────────────────────────

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bot_name, :string, default: ""
  attr :on_close, :any, default: nil

  @spec add_channel_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def add_channel_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      scope={:window}
      on_cancel={@on_close}
      class="bm-form-dialog md:max-w-sm"
    >
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Add Channel — %{bot}", bot: @bot_name)}
        on_close={@on_close}
      >
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form phx-submit="bot_add_channel" class="bm-form flex min-h-0 flex-1 flex-col">
        <input type="hidden" name="bot_name" value={@bot_name} />
        <.dialog_body class="bm-form-body">
          <.label for="bot-add-channel">{dgettext("dialogs", "Channel")}</.label>
          <.input
            id="bot-add-channel"
            name="channel"
            type="text"
            placeholder="#channel"
            autocomplete="off"
            required
            data-testid="bot-add-channel-input"
          />
        </.dialog_body>
        <.dialog_footer class="bm-form-footer">
          <.button type="submit" class="bm-action-button" data-testid="bot-add-channel-submit">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close} class="bm-action-button">
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end

  # ── Add RSS Feed Dialog ────────────────────────────────────

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bot_name, :string, default: ""
  attr :on_close, :any, default: nil

  @spec add_feed_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def add_feed_dialog(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      scope={:window}
      on_cancel={@on_close}
      class="bm-form-dialog md:max-w-sm"
    >
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Add Feed — %{bot}", bot: @bot_name)}
        on_close={@on_close}
      >
        <:icon><Icons.icon_btn_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <form
        id="rss-add-feed-form"
        phx-submit="bot_rss_add_feed"
        class="bm-form flex min-h-0 flex-1 flex-col"
      >
        <input type="hidden" name="bot_name" value={@bot_name} />
        <.dialog_body class="bm-form-body">
          <div class="space-y-retro-8">
            <div>
              <.label for="rss-feed-url">{dgettext("dialogs", "Feed URL")}</.label>
              <.input
                id="rss-feed-url"
                name="url"
                type="url"
                placeholder="https://example.com/feed.xml"
                autocomplete="off"
                required
                data-testid="rss-feed-url"
              />
            </div>
            <div>
              <.label for="rss-feed-channel">{dgettext("dialogs", "Channel")}</.label>
              <.input
                id="rss-feed-channel"
                name="channel"
                type="text"
                placeholder="#news"
                autocomplete="off"
                required
                data-testid="rss-feed-channel"
              />
            </div>
          </div>
        </.dialog_body>
        <.dialog_footer class="bm-form-footer">
          <.button type="submit" class="bm-action-button" data-testid="rss-add-feed">
            <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Add")}
          </.button>
          <.button type="button" variant="outline" phx-click={@on_close} class="bm-action-button">
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end

  # ── Private: the capability list ────────────────────────────

  # The nine capabilities, in the order the form has always shown them. One
  # list, read twice: once by the checkboxes, once by the banner's picture.
  @spec capability_fields() :: [%{id: String.t(), name: String.t(), label: String.t()}]
  defp capability_fields do
    [
      %{id: "cap-mention", name: "cap_mention", label: dgettext("dialogs", "Mention Response")},
      %{id: "cap-greeter", name: "cap_greeter", label: dgettext("dialogs", "Greeter")},
      %{
        id: "cap-custom-commands",
        name: "cap_custom_commands",
        label: dgettext("dialogs", "Custom Commands")
      },
      %{id: "cap-help", name: "cap_help", label: dgettext("dialogs", "Help")},
      %{id: "cap-dice", name: "cap_dice", label: dgettext("dialogs", "Dice")},
      %{id: "cap-moderation", name: "cap_moderation", label: dgettext("dialogs", "Moderation")},
      %{id: "cap-trivia", name: "cap_trivia", label: dgettext("dialogs", "Trivia")},
      %{id: "cap-scheduler", name: "cap_scheduler", label: dgettext("dialogs", "Scheduler")},
      %{id: "cap-rss", name: "cap_rss", label: dgettext("dialogs", "RSS")}
    ]
  end

  # Nothing is ticked, because nothing is: a capability is off until the
  # checkbox beside it is on.
  @spec capability_lines() :: [map()]
  defp capability_lines do
    Enum.map(capability_fields(), &%{text: &1.label, tone: :normal})
  end

  # The turn this bot already answers, so a second command reads as another of
  # the same thing. A bot with none draws an empty well, which is the truth.
  @spec command_lines(list(), String.t(), String.t()) :: [map()]
  defp command_lines([], _prefix, _bot_name), do: []

  defp command_lines([command | _rest], prefix, bot_name) do
    [
      %{text: prefix <> bot_name <> " " <> Map.get(command, :trigger, ""), tone: :accent},
      %{text: Map.get(command, :response) || "", tone: :normal}
    ]
  end

  # ── Private: checkbox helper ────────────────────────────────

  defp checkbox_item(assigns) do
    ~H"""
    <div class="bm-checkbox-item flex items-center gap-retro-4">
      <.checkbox id={@id} name={@name} />
      <.label for={@id} class="text-xs cursor-pointer">{@label}</.label>
    </div>
    """
  end
end
