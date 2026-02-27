defmodule RetroHexChatWeb.ShowcaseLive.FieldsetPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Fieldset", active_page: "fieldset")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Fieldset</h2>

      <.showcase_card
        title="Basic Fieldset"
        description="A Win98 groupbox with etched groove border and legend."
      >
        <.retro_fieldset legend="Personal Information">
          <.field_row>
            <label class="text-sm w-24">Name:</label>
            <input
              type="text"
              class="shadow-retro-field bg-white px-1 py-[2px] text-sm flex-1"
              value="Troll"
            />
          </.field_row>
          <.field_row>
            <label class="text-sm w-24">Email:</label>
            <input
              type="text"
              class="shadow-retro-field bg-white px-1 py-[2px] text-sm flex-1"
              value="troll@retro.chat"
            />
          </.field_row>
        </.retro_fieldset>
        <.code_example>
          &lt;.retro_fieldset legend="Personal Information"&gt;
          &lt;.field_row&gt;
          &lt;label class="text-sm w-24"&gt;Name:&lt;/label&gt;
          &lt;input type="text" class="shadow-retro-field bg-white" /&gt;
          &lt;/.field_row&gt;
          &lt;/.retro_fieldset&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Event Sounds"
        description="Replicating the platform's Sounds dialog fieldset."
      >
        <.retro_fieldset legend="Event Sounds">
          <div class="shadow-retro-field bg-white">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-gray-300">
                  <th class="text-left px-2 py-1 font-bold">Event</th>
                  <th class="text-left px-2 py-1 font-bold">Sound</th>
                  <th class="text-left px-2 py-1 font-bold">Flash</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={
                  {event, sound} <- [
                    {"Channel Message", "Ding Low"},
                    {"Private Message", "Chime High"},
                    {"Highlight/Mention", "Alert"},
                    {"User Joined", "Click"},
                    {"User Left", "Click"},
                    {"Connected", "Chime Short"},
                    {"Disconnected", "Chime Low"}
                  ]
                }>
                  <td class="px-2 py-1">{event}</td>
                  <td class="px-2 py-1">
                    <select class="shadow-retro-field bg-white px-1 py-[1px] text-sm w-28">
                      <option selected>{sound}</option>
                    </select>
                  </td>
                  <td class="px-2 py-1">
                    <.button variant="outline" size="sm">Play</.button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.retro_fieldset>
      </.showcase_card>

      <.showcase_card title="Without Legend" description="Fieldset without a legend text.">
        <.retro_fieldset>
          <.field_row>
            <input type="checkbox" class="retro-checkbox" checked />
            <label class="text-sm">Enable notifications</label>
          </.field_row>
          <.field_row>
            <input type="checkbox" class="retro-checkbox" />
            <label class="text-sm">Play sounds</label>
          </.field_row>
          <.field_row>
            <input type="checkbox" class="retro-checkbox" checked />
            <label class="text-sm">Flash taskbar</label>
          </.field_row>
        </.retro_fieldset>
        <.code_example>
          &lt;.retro_fieldset&gt;
          &lt;.field_row&gt;
          &lt;input type="checkbox" class="retro-checkbox" checked /&gt;
          &lt;label&gt;Enable notifications&lt;/label&gt;
          &lt;/.field_row&gt;
          &lt;/.retro_fieldset&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Stacked Layout" description="Field rows in vertical (stacked) layout.">
        <.retro_fieldset legend="Connection Settings">
          <.field_row stacked>
            <label class="text-sm font-bold">Server Address:</label>
            <input
              type="text"
              class="shadow-retro-field bg-white px-1 py-[2px] text-sm w-full"
              value="irc.retro.chat"
            />
          </.field_row>
          <.field_row stacked>
            <label class="text-sm font-bold">Port:</label>
            <input
              type="text"
              class="shadow-retro-field bg-white px-1 py-[2px] text-sm w-32"
              value="6667"
            />
          </.field_row>
        </.retro_fieldset>
        <.code_example>
          &lt;.field_row stacked&gt;
          &lt;label&gt;Server Address:&lt;/label&gt;
          &lt;input type="text" class="shadow-retro-field bg-white" /&gt;
          &lt;/.field_row&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
