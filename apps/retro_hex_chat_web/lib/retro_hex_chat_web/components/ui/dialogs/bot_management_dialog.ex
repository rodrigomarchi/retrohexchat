defmodule RetroHexChatWeb.Components.UI.BotManagementDialog do
  @moduledoc """
  v2 Bot Management dialog with split-view layout.

  Lists bots on the left, details/tabs on the right. Uses v2 design system
  primitives (Dialog, Tabs, Button).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Separator

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bots, :list, default: []
  attr :selected, :any, default: nil
  attr :channels, :list, default: []
  attr :commands, :list, default: []
  attr :events, :list, default: []
  attr :stats, :any, default: nil
  attr :active_tab, :atom, default: :general
  attr :is_admin, :boolean, default: false
  attr :editing_field, :any, default: nil
  attr :capabilities, :list, default: [], doc: "Available capability names for the selected bot"
  attr :on_close, :any, default: nil

  @spec bot_management_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def bot_management_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-2xl">
      <.dialog_header id={@id} title="Bot Management">
        <:icon><Icons.icon_dialog_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body class="min-h-[400px]">
        <div class="flex flex-col md:flex-row gap-retro-8 md:h-[360px]">
          <%!-- Left panel: bot list --%>
          <div class="w-full md:w-[180px] md:shrink-0 flex flex-col">
            <div class="text-xs font-bold mb-retro-4 flex items-center gap-retro-4">
              <Icons.icon_btn_bot_management class="w-[14px] h-[14px]" /> Bots
            </div>
            <div class="flex-1 shadow-retro-sunken bg-white overflow-y-auto p-retro-2">
              <ul class="list-none m-0 p-0" data-testid="bot-list">
                <li
                  :for={bot <- @bots}
                  class={[
                    "px-retro-4 py-retro-2 text-sm cursor-pointer select-none truncate",
                    if(@selected && @selected.name == bot.name,
                      do: "bg-selection-bg text-selection-fg",
                      else: "hover:bg-selection-bg/30"
                    )
                  ]}
                  phx-click="bot_select"
                  phx-value-name={bot.name}
                  data-testid={"bot-item-#{bot.name}"}
                >
                  {bot.name}
                </li>
              </ul>
            </div>
            <div :if={@is_admin} class="flex gap-retro-4 mt-retro-4">
              <.button type="button" size="sm" phx-click="open_new_bot_dialog">
                <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
                New
              </.button>
              <.button
                type="button"
                size="sm"
                variant="destructive"
                disabled={@selected == nil}
                phx-click="bot_delete"
                phx-value-name={@selected && @selected.name}
              >
                <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
                Delete
              </.button>
            </div>
          </div>

          <%!-- Right panel: details --%>
          <div class="flex-1 min-w-0">
            <div
              :if={@selected == nil}
              class="flex items-center justify-center h-full text-muted-foreground text-sm"
            >
              Select a bot to view details
            </div>
            <div :if={@selected != nil} class="h-full flex flex-col">
              <.tabs id="bot-tabs" default="general" class="flex-1">
                <.tabs_list class="gap-0">
                  <.tabs_trigger
                    builder={%{id: "bot-tabs", default: "general"}}
                    value="general"
                    phx-click="bot_dialog_tab"
                    phx-value-tab="general"
                  >
                    <:icon><Icons.icon_tab_general class="w-[16px] h-[16px]" /></:icon>
                    General
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={%{id: "bot-tabs", default: "general"}}
                    value="capabilities"
                    phx-click="bot_dialog_tab"
                    phx-value-tab="capabilities"
                  >
                    <:icon><Icons.icon_tab_control class="w-[16px] h-[16px]" /></:icon>
                    Capabilities
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={%{id: "bot-tabs", default: "general"}}
                    value="channels"
                    phx-click="bot_dialog_tab"
                    phx-value-tab="channels"
                  >
                    <:icon><Icons.icon_tab_channel class="w-[16px] h-[16px]" /></:icon>
                    Channels
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={%{id: "bot-tabs", default: "general"}}
                    value="commands"
                    phx-click="bot_dialog_tab"
                    phx-value-tab="commands"
                  >
                    <:icon><Icons.icon_tab_commands class="w-[16px] h-[16px]" /></:icon>
                    Commands
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={%{id: "bot-tabs", default: "general"}}
                    value="events"
                    phx-click="bot_dialog_tab"
                    phx-value-tab="events"
                  >
                    <:icon><Icons.icon_clock class="w-[16px] h-[16px]" /></:icon>
                    Events
                  </.tabs_trigger>
                </.tabs_list>

                <%!-- General tab --%>
                <.tabs_content value="general">
                  <div class="space-y-retro-8 p-retro-4 text-sm">
                    <div class="flex items-center gap-retro-8">
                      <span class="font-bold w-[80px]">Name:</span>
                      <span>{@selected.name}</span>
                    </div>
                    <div class="flex items-center gap-retro-8">
                      <span class="font-bold w-[80px]">Nickname:</span>
                      <span>{Map.get(@selected, :nickname, @selected.name)}</span>
                    </div>
                    <div class="flex items-center gap-retro-8">
                      <span class="font-bold w-[80px]">Prefix:</span>
                      <span class="font-mono">{Map.get(@selected, :prefix, "!")}</span>
                    </div>
                    <div class="flex items-center gap-retro-8">
                      <span class="font-bold w-[80px]">Status:</span>
                      <span class={
                        if Map.get(@selected, :enabled, true),
                          do: "text-green-700",
                          else: "text-red-700"
                      }>
                        {if Map.get(@selected, :enabled, true), do: "Enabled", else: "Disabled"}
                      </span>
                    </div>
                    <.separator />
                    <div class="font-bold text-xs">Capabilities</div>
                    <div class="flex flex-wrap gap-retro-4">
                      <span
                        :for={cap <- capability_names(@selected)}
                        class="bg-surface shadow-retro-raised px-retro-8 py-retro-2 text-xs"
                      >
                        {cap_display_name(cap)}
                      </span>
                      <span
                        :if={capability_names(@selected) == []}
                        class="text-muted-foreground text-xs"
                      >
                        No capabilities configured
                      </span>
                    </div>
                    <div :if={@stats} class="mt-retro-4">
                      <.separator />
                      <div class="font-bold text-xs mb-retro-4">Statistics</div>
                      <div class="grid grid-cols-2 gap-retro-4 text-xs">
                        <span>Messages:</span>
                        <span>{Map.get(@stats, :messages, 0)}</span>
                        <span>Commands:</span>
                        <span>{Map.get(@stats, :commands, 0)}</span>
                        <span>Uptime:</span>
                        <span>{Map.get(@stats, :uptime, "N/A")}</span>
                      </div>
                    </div>
                  </div>
                </.tabs_content>

                <%!-- Capabilities tab --%>
                <.tabs_content value="capabilities">
                  <.capabilities_tab
                    selected={@selected}
                    is_admin={@is_admin}
                  />
                </.tabs_content>

                <%!-- Channels tab --%>
                <.tabs_content value="channels">
                  <div class="p-retro-4">
                    <div
                      :if={@channels == []}
                      class="text-center text-muted-foreground text-sm py-retro-16"
                    >
                      No channels assigned
                    </div>
                    <div
                      :if={@channels != []}
                      class="shadow-retro-sunken bg-white overflow-y-auto max-h-[200px]"
                    >
                      <table class="w-full text-xs">
                        <thead>
                          <tr class="bg-surface">
                            <th class="text-left px-retro-4 py-retro-2 font-bold">Channel</th>
                            <th class="text-left px-retro-4 py-retro-2 font-bold">Status</th>
                            <th
                              :if={@is_admin}
                              class="text-right px-retro-4 py-retro-2 font-bold w-[60px]"
                            >
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={ch <- @channels} class="border-t border-separator">
                            <td class="px-retro-4 py-retro-2">{Map.get(ch, :name, ch)}</td>
                            <td class="px-retro-4 py-retro-2">
                              {if is_map(ch), do: Map.get(ch, :status, "joined"), else: "joined"}
                            </td>
                            <td :if={@is_admin} class="px-retro-4 py-retro-2 text-right">
                              <button
                                type="button"
                                class="text-red-700 hover:underline text-xs"
                                phx-click="bot_remove_channel"
                                phx-value-channel={Map.get(ch, :name, ch)}
                                phx-value-bot_name={@selected.name}
                              >
                                Remove
                              </button>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                    <form
                      :if={@is_admin}
                      phx-submit="bot_add_channel"
                      class="flex gap-retro-4 mt-retro-4"
                    >
                      <input type="hidden" name="bot_name" value={@selected && @selected.name} />
                      <input
                        type="text"
                        name="channel"
                        placeholder="#channel"
                        class="flex-1 text-sm shadow-retro-sunken bg-white px-retro-4 py-retro-2"
                        autocomplete="off"
                      />
                      <.button type="submit" size="sm">
                        <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
                        Add
                      </.button>
                    </form>
                  </div>
                </.tabs_content>

                <%!-- Commands tab --%>
                <.tabs_content value="commands">
                  <div class="p-retro-4">
                    <div
                      :if={@commands == []}
                      class="text-center text-muted-foreground text-sm py-retro-16"
                    >
                      No custom commands
                    </div>
                    <div
                      :if={@commands != []}
                      class="shadow-retro-sunken bg-white overflow-y-auto max-h-[200px]"
                    >
                      <table class="w-full text-xs">
                        <thead>
                          <tr class="bg-surface">
                            <th class="text-left px-retro-4 py-retro-2 font-bold">Trigger</th>
                            <th class="text-left px-retro-4 py-retro-2 font-bold">Response</th>
                            <th
                              :if={@is_admin}
                              class="text-right px-retro-4 py-retro-2 font-bold w-[60px]"
                            >
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr :for={cmd <- @commands} class="border-t border-separator">
                            <td class="px-retro-4 py-retro-2 font-mono">
                              {Map.get(cmd, :trigger, "")}
                            </td>
                            <td class="px-retro-4 py-retro-2 truncate max-w-[200px]">
                              {Map.get(cmd, :response, "")}
                            </td>
                            <td :if={@is_admin} class="px-retro-4 py-retro-2 text-right">
                              <button
                                type="button"
                                class="text-red-700 hover:underline text-xs"
                                phx-click="bot_remove_command"
                                phx-value-trigger={Map.get(cmd, :trigger, "")}
                                phx-value-bot_name={@selected.name}
                              >
                                Remove
                              </button>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                    <div :if={@is_admin} class="flex gap-retro-4 mt-retro-4">
                      <.button type="button" size="sm" phx-click="open_add_command_dialog">
                        <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
                        Add
                      </.button>
                    </div>
                  </div>
                </.tabs_content>

                <%!-- Events tab --%>
                <.tabs_content value="events">
                  <div class="p-retro-4">
                    <div
                      :if={@events == []}
                      class="text-center text-muted-foreground text-sm py-retro-16"
                    >
                      No recent events
                    </div>
                    <div
                      :if={@events != []}
                      class="shadow-retro-sunken bg-white overflow-y-auto max-h-[240px] p-retro-2"
                    >
                      <div
                        :for={event <- @events}
                        class="text-xs py-retro-2 border-b border-separator last:border-0"
                      >
                        <span class="text-muted-foreground mr-retro-4">
                          {Map.get(event, :timestamp, "")}
                        </span>
                        <span>{Map.get(event, :message, "")}</span>
                      </div>
                    </div>
                  </div>
                </.tabs_content>
              </.tabs>
            </div>
          </div>
        </div>
      </.dialog_body>
      <.dialog_footer>
        <.button type="button" phx-click={@on_close}>
          <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  # ── Capabilities Tab ─────────────────────────────────────

  attr :selected, :any, required: true
  attr :is_admin, :boolean, default: false

  @spec capabilities_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp capabilities_tab(assigns) do
    caps = (assigns.selected && Map.get(assigns.selected, :capabilities)) || %{}
    cap_names = Map.keys(caps)
    assigns = assign(assigns, caps: caps, cap_names: cap_names)

    ~H"""
    <div class="p-retro-4">
      <div
        :if={@cap_names == []}
        class="text-center text-muted-foreground text-sm py-retro-16"
      >
        No configurable capabilities enabled.
      </div>
      <div :if={@cap_names != []} class="space-y-retro-8">
        <fieldset
          :for={cap_name <- @cap_names}
          class="shadow-retro-field p-retro-8"
        >
          <legend class="text-xs font-bold px-1">{cap_display_name(cap_name)}</legend>
          <.cap_toggle_row
            enabled={Map.get(@caps[cap_name] || %{}, "enabled", true)}
            cap_name={cap_name}
            bot_name={@selected.name}
            is_admin={@is_admin}
          />
          <div
            :for={{key, val} <- cap_config_fields(@caps[cap_name])}
            class="flex items-center gap-retro-4 text-xs mt-retro-2"
          >
            <span class="font-bold w-[100px]">{key}:</span>
            <span>{inspect_cap_value(val)}</span>
          </div>
        </fieldset>
      </div>
    </div>
    """
  end

  attr :enabled, :boolean, required: true
  attr :cap_name, :string, required: true
  attr :bot_name, :string, required: true
  attr :is_admin, :boolean, default: false

  @spec cap_toggle_row(map()) :: Phoenix.LiveView.Rendered.t()
  defp cap_toggle_row(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-4 text-xs">
      <span class="font-bold w-[100px]">Status:</span>
      <span class={if @enabled, do: "text-green-700", else: "text-red-700"}>
        {if @enabled, do: "Enabled", else: "Disabled"}
      </span>
      <button
        :if={@is_admin}
        type="button"
        class="text-xs underline ml-retro-4"
        phx-click="bot_toggle_capability"
        phx-value-capability={@cap_name}
        phx-value-bot_name={@bot_name}
        data-testid={"toggle-cap-#{@cap_name}"}
      >
        {if @enabled, do: "Disable", else: "Enable"}
      </button>
    </div>
    """
  end

  @spec cap_display_name(String.t()) :: String.t()
  defp cap_display_name("dice"), do: "Dice"
  defp cap_display_name("moderation"), do: "Moderation"
  defp cap_display_name("trivia"), do: "Trivia"
  defp cap_display_name("scheduler"), do: "Scheduler"
  defp cap_display_name("rss"), do: "RSS"
  defp cap_display_name("greeter"), do: "Greeter"
  defp cap_display_name("mention"), do: "Mention"
  defp cap_display_name(other), do: String.capitalize(other)

  defp capability_names(selected) do
    case Map.get(selected, :capabilities, %{}) do
      caps when is_map(caps) -> Map.keys(caps)
      caps when is_list(caps) -> caps
      _ -> []
    end
  end

  @spec cap_config_fields(map() | nil) :: [{String.t(), any()}]
  defp cap_config_fields(nil), do: []

  defp cap_config_fields(config) do
    config
    |> Map.drop(["enabled"])
    |> Enum.sort_by(&elem(&1, 0))
  end

  @spec inspect_cap_value(any()) :: String.t()
  defp inspect_cap_value(val) when is_list(val), do: "#{length(val)} item(s)"
  defp inspect_cap_value(val) when is_map(val), do: "#{map_size(val)} entries"
  defp inspect_cap_value(val), do: to_string(val)
end
