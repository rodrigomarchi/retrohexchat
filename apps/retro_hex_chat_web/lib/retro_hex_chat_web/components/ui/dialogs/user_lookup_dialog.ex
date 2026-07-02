defmodule RetroHexChatWeb.Components.UI.UserLookupDialog do
  @moduledoc """
  User lookup panel: a nickname form with Whois/Last-Seen actions and, below it,
  the Whois/Whowas result card for the last lookup.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  attr :id, :string, default: "user-lookup-dialog"
  attr :nickname, :string, default: ""
  attr :error_message, :string, default: nil
  attr :result, :map, default: nil
  attr :on_change, :any, default: "user_lookup_change"
  attr :on_whois, :any, default: "user_lookup_whois"
  attr :on_whowas, :any, default: "user_lookup_whowas"
  attr :on_result_close, :any, default: "close_lookup_result"
  attr :on_result_whois, :any, default: "lookup_result_whois"
  attr :on_result_whowas, :any, default: "lookup_result_whowas"
  attr :on_result_query, :any, default: "lookup_result_query"

  @spec user_lookup_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def user_lookup_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="user-lookup-panel"
      class="flex h-full min-h-0 flex-col gap-retro-8 overflow-y-auto"
    >
      <form
        id={"#{@id}-form"}
        data-testid="user-lookup-form"
        phx-submit={@on_whois}
        phx-change={@on_change}
        class="space-y-retro-8"
      >
        <div class="flex flex-col gap-retro-4">
          <label class="text-xs font-bold" for={"#{@id}-nickname"}>
            {dgettext("dialogs", "Nickname")}:
          </label>
          <.input
            type="text"
            id={"#{@id}-nickname"}
            name="nickname"
            value={@nickname}
            autofocus
            autocomplete="off"
            placeholder={dgettext("dialogs", "Enter nickname...")}
            data-testid="user-lookup-nickname"
          />
          <p :if={@error_message} class="text-xs text-destructive" data-testid="user-lookup-error">
            {@error_message}
          </p>
        </div>

        <div class="flex justify-end gap-retro-4">
          <.button type="submit" size="sm" data-testid="user-lookup-whois">
            <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Whois")}
          </.button>
          <.button
            type="button"
            size="sm"
            variant="outline"
            phx-click={@on_whowas}
            phx-value-nickname={@nickname}
            data-testid="user-lookup-whowas"
          >
            <:icon><Icons.icon_clock class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Last Seen")}
          </.button>
        </div>
      </form>

      <.lookup_result_card
        :if={@result}
        result={@result}
        on_close={@on_result_close}
        on_whois={@on_result_whois}
        on_whowas={@on_result_whowas}
        on_query={@on_result_query}
      />
    </div>
    """
  end

  attr :result, :map, required: true
  attr :on_close, :any, default: "close_lookup_result"
  attr :on_whois, :any, default: "lookup_result_whois"
  attr :on_whowas, :any, default: "lookup_result_whowas"
  attr :on_query, :any, default: "lookup_result_query"

  @spec lookup_result_card(map()) :: Phoenix.LiveView.Rendered.t()
  def lookup_result_card(assigns) do
    assigns =
      assign(assigns,
        kind: Map.get(assigns.result, :kind),
        nickname: Map.get(assigns.result, :nickname, ""),
        title: Map.get(assigns.result, :title, dgettext("dialogs", "User Lookup")),
        rows: Map.get(assigns.result, :rows, []),
        online: Map.get(assigns.result, :online, false)
      )

    ~H"""
    <section data-testid="lookup-result-card" class="space-y-retro-8">
      <header class="flex items-center gap-retro-4 text-xs font-bold">
        <Icons.icon_btn_search :if={@kind == :whois} class="w-4 h-4" />
        <Icons.icon_clock :if={@kind == :whowas} class="w-4 h-4" />
        <span data-testid="lookup-result-title">{@title}</span>
      </header>

      <dl class="shadow-retro-field bg-white p-retro-8 text-xs">
        <div :for={row <- @rows} class="grid grid-cols-[112px_1fr] gap-retro-8 py-retro-2">
          <dt class="font-bold">{row.label}:</dt>
          <dd class="min-w-0 break-words">{row.value}</dd>
        </div>
      </dl>

      <div class="flex justify-end gap-retro-4">
        <.button
          :if={@kind == :whois}
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_whowas}
          phx-value-nick={@nickname}
          data-testid="lookup-result-whowas"
        >
          <:icon><Icons.icon_clock class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Whowas")}
        </.button>
        <.button
          :if={@kind == :whois}
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_query}
          phx-value-nick={@nickname}
          data-testid="lookup-result-query"
        >
          <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Query (PM)")}
        </.button>
        <.button
          :if={@kind == :whowas}
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_whois}
          phx-value-nick={@nickname}
          disabled={!@online}
          data-testid="lookup-result-whois"
        >
          <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Whois")}
        </.button>
        <.button type="button" size="sm" phx-click={@on_close} data-testid="lookup-result-close">
          <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Clear")}
        </.button>
      </div>
    </section>
    """
  end
end
