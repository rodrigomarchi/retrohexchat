defmodule RetroHexChatWeb.Components.UI.GameSheet do
  @moduledoc """
  An arcade game's sheet: its icon, name, line and engine, its screenshot
  beside what it is, then its keys and its tips. The game's public page and
  the in-app Arcade show this same sheet, so the game reads the same before
  and after signing in; only the buttons differ, and they sit in the same
  place — the `actions` slot, beside the name.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Landing.GameCards, only: [game_screenshot: 1]

  alias RetroHexChatWeb.Icons

  attr :game, :map, required: true, doc: "a `RetroHexChatWeb.GameCatalog` arcade game"
  attr :heading, :string, default: "h2", doc: "the name's tag: the public page's h1"
  attr :heading_id, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :actions, doc: "the ways in, beside the name"

  @spec game_sheet(map()) :: Phoenix.LiveView.Rendered.t()
  def game_sheet(assigns) do
    ~H"""
    <div class={classes(["flex flex-col gap-retro-10", @class])} {@rest}>
      <div class="flex flex-wrap items-center gap-retro-12">
        <Icons.game_icon game_id={@game.id} class="h-12 w-12 flex-shrink-0" />
        <div class="min-w-[12rem] flex-1 space-y-retro-2">
          <.dynamic tag={@heading} id={@heading_id} class="text-lg font-bold leading-tight text-text">
            {@game.name}
          </.dynamic>
          <p class="text-sm leading-snug">{@game.tagline}</p>
          <.badge :if={@game.engine_name} variant="secondary">
            {dgettext("games", "%{engine} Engine", engine: @game.engine_name)}
          </.badge>
        </div>
        <div :if={@actions != []} class="flex flex-wrap gap-retro-6">
          {render_slot(@actions)}
        </div>
      </div>

      <div class="grid grid-cols-1 items-start gap-retro-10 md:grid-cols-2">
        <div class="shadow-retro-field">
          <.game_screenshot game={@game} main />
        </div>
        <fieldset :if={@game.about != []} class="retro-fieldset min-w-0 p-retro-8">
          <legend class="px-retro-4 text-xs font-bold">{dgettext("games", "About")}</legend>
          <p :for={paragraph <- @game.about} class="mb-retro-6 text-sm leading-relaxed last:mb-0">
            {paragraph}
          </p>
        </fieldset>
      </div>

      <div
        :if={@game.keys != [] or @game.tips != []}
        class="grid grid-cols-1 items-start gap-retro-10 md:grid-cols-2"
      >
        <fieldset
          :if={@game.keys != []}
          class="retro-fieldset min-w-0 p-retro-8"
          data-testid="game-controls"
        >
          <legend class="px-retro-4 text-xs font-bold">
            {dgettext("games", "Keyboard Controls")}
          </legend>
          <table class="w-full text-xs leading-snug">
            <thead>
              <tr>
                <th class="w-[7.75rem] border-b border-gray-400 py-retro-2 pr-retro-6 text-left font-bold">
                  {dgettext("games", "Key")}
                </th>
                <th class="border-b border-gray-400 py-retro-2 text-left font-bold">
                  {dgettext("games", "Action")}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{key, action} <- @game.keys}>
                <td class="w-[7.75rem] whitespace-nowrap py-retro-2 pr-retro-6 align-top">
                  <kbd class="shadow-retro-raised bg-surface px-retro-4 font-mono text-[11px]">
                    {key}
                  </kbd>
                </td>
                <td class="py-retro-2 align-top">{action}</td>
              </tr>
            </tbody>
          </table>
        </fieldset>

        <fieldset :if={@game.tips != []} class="retro-fieldset min-w-0 p-retro-8">
          <legend class="px-retro-4 text-xs font-bold">{dgettext("games", "Tips")}</legend>
          <ul class="list-disc space-y-retro-4 pl-retro-16 text-sm leading-relaxed">
            <li :for={tip <- @game.tips}>{tip}</li>
          </ul>
        </fieldset>
      </div>
    </div>
    """
  end
end
