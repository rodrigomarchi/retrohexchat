defmodule RetroHexChatWeb.ShowcaseLive.Chat.ColorPickerPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ColorPicker
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Color Picker"),
       active_page: "color-picker",
       selected: 3
     )}
  end

  @impl true
  def handle_event("color-select", %{"index" => index}, socket) do
    {:noreply, assign(socket, :selected, String.to_integer(index))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Color Picker")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default")}
        description="4x4 grid of the 16 standard IRC colors."
      >
        <.color_picker id="demo-default" />
        <.code_example>
          &lt;.color_picker id="my-picker" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Selection")}
        description="Click a color to select it. The selected swatch gets a bold border."
      >
        <div class="flex items-center gap-retro-12">
          <.color_picker id="demo-selected" selected={@selected} />
          <div class="text-xs text-muted-foreground">
            <p>{dgettext("showcase", "Selected:")} <span class="font-bold">{@selected}</span></p>
            <p>
              {dgettext("showcase", "Color:")}
              <span
                class="inline-block w-[14px] h-[14px] border border-gray-500 align-middle"
                style={"background-color: #{elem(Enum.at(irc_colors(), @selected), 1)};"}
              />
              <span class="font-bold">{elem(Enum.at(irc_colors(), @selected), 0)}</span>
            </p>
          </div>
        </div>
        <.code_example>
          &lt;.color_picker id="my-picker" selected={3} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Color Reference")}
        description="All 16 IRC colors with their indices."
      >
        <div class="grid grid-cols-4 gap-2">
          <div
            :for={{{name, hex}, idx} <- Enum.with_index(irc_colors())}
            class="flex items-center gap-retro-4 text-xs"
          >
            <span
              class="w-[18px] h-[18px] border border-gray-500 shrink-0"
              style={"background-color: #{hex};"}
            />
            <span class="text-muted-foreground">{idx}:</span>
            <span>{name}</span>
          </div>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
