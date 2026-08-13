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

  attr :on_submit, :any,
    default: "user_lookup_submit",
    doc: """
    Both buttons submit the form, so the nickname that travels is the one on
    screen. Reading it from an assign instead would send whatever the last
    `phx-change` had time to store — empty, if the user typed and clicked
    quickly enough, which is only ever visible when the round trip is slow.
    Which button was pressed arrives as `lookup`.
    """

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
      class="ul-panel"
    >
      <form
        id={"#{@id}-form"}
        data-testid="user-lookup-form"
        phx-submit={@on_submit}
        phx-change={@on_change}
        class="ul-form"
      >
        <div class="ul-field-row">
          <label class="ul-field-label" for={"#{@id}-nickname"}>
            {dgettext("dialogs", "Nickname")}:
          </label>
          <div class="ul-field-control">
            <.input
              type="text"
              id={"#{@id}-nickname"}
              name="nickname"
              value={@nickname}
              autofocus
              autocomplete="off"
              placeholder={dgettext("dialogs", "Enter nickname...")}
              data-testid="user-lookup-nickname"
              class="ul-nickname-input"
            />
            <p :if={@error_message} class="ul-error" data-testid="user-lookup-error">
              {@error_message}
            </p>
          </div>
        </div>

        <div class="ul-action-row">
          <.button
            type="submit"
            name="lookup"
            value="whois"
            size="sm"
            data-testid="user-lookup-whois"
            class="ul-action-button"
          >
            <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Whois")}
          </.button>
          <.button
            type="submit"
            name="lookup"
            value="whowas"
            size="sm"
            variant="outline"
            data-testid="user-lookup-whowas"
            class="ul-action-button"
          >
            <:icon><Icons.icon_clock class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Last Seen")}
          </.button>
        </div>
      </form>

      <div class="ul-result-region">
        <.lookup_result_card
          :if={@result}
          result={@result}
          on_close={@on_result_close}
          on_whois={@on_result_whois}
          on_whowas={@on_result_whowas}
          on_query={@on_result_query}
        />
        <div :if={!@result} class="ul-empty-state" data-testid="user-lookup-empty">
          {dgettext("dialogs", "No lookup yet.")}
        </div>
      </div>
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
    <section data-testid="lookup-result-card" class="ul-result-card">
      <header class="ul-result-header">
        <Icons.icon_btn_search :if={@kind == :whois} class="w-4 h-4" />
        <Icons.icon_clock :if={@kind == :whowas} class="w-4 h-4" />
        <span data-testid="lookup-result-title" class="ul-result-title">{@title}</span>
      </header>

      <dl class="ul-result-list retro-scrollbar">
        <div :for={row <- @rows} class="ul-result-row">
          <dt class="ul-result-label">{row.label}:</dt>
          <dd class="ul-result-value">{row.value}</dd>
        </div>
      </dl>

      <div class="ul-result-actions">
        <.button
          :if={@kind == :whois}
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_whowas}
          phx-value-nick={@nickname}
          data-testid="lookup-result-whowas"
          class="ul-action-button"
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
          class="ul-action-button"
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
          class="ul-action-button"
        >
          <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Whois")}
        </.button>
        <.button
          type="button"
          size="sm"
          phx-click={@on_close}
          data-testid="lookup-result-close"
          class="ul-action-button"
        >
          <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Clear")}
        </.button>
      </div>
    </section>
    """
  end
end
