defmodule RetroHexChatWeb.Components.UI.UserLookupDialog do
  @moduledoc """
  User lookup dialog and Whois/Whowas result card.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  attr :id, :string, default: "user-lookup-dialog"
  attr :show, :boolean, default: false
  attr :nickname, :string, default: ""
  attr :error_message, :string, default: nil
  attr :on_change, :any, default: "user_lookup_change"
  attr :on_whois, :any, default: "user_lookup_whois"
  attr :on_whowas, :any, default: "user_lookup_whowas"
  attr :on_close, :any, default: "close_user_lookup"

  @spec user_lookup_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def user_lookup_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_close} class="max-w-sm">
      <.dialog_header id={@id} title={dgettext("dialogs", "User Lookup")} on_close={@on_close}>
        <:icon><Icons.icon_btn_search class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
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
            <.button type="button" size="sm" variant="outline" phx-click={@on_close}>
              <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
              {dgettext("dialogs", "Close")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, default: "lookup-result-dialog"
  attr :show, :boolean, default: false
  attr :result, :map, default: nil
  attr :on_close, :any, default: "close_lookup_result"
  attr :on_whois, :any, default: "lookup_result_whois"
  attr :on_whowas, :any, default: "lookup_result_whowas"
  attr :on_query, :any, default: "lookup_result_query"

  @spec lookup_result_card(map()) :: Phoenix.LiveView.Rendered.t()
  def lookup_result_card(%{result: nil} = assigns) do
    assigns = assign(assigns, :title, dgettext("dialogs", "User Lookup"))

    ~H"""
    <.dialog id={@id} show={false} on_cancel={@on_close} class="max-w-md">
      <.dialog_header id={@id} title={@title} on_close={@on_close}>
        <:icon><Icons.icon_btn_search class="w-4 h-4" /></:icon>
      </.dialog_header>
    </.dialog>
    """
  end

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
    <.dialog id={@id} show={@show} on_cancel={@on_close} class="max-w-md">
      <.dialog_header id={@id} title={@title} on_close={@on_close}>
        <:icon>
          <Icons.icon_btn_search :if={@kind == :whois} class="w-4 h-4" />
          <Icons.icon_clock :if={@kind == :whowas} class="w-4 h-4" />
        </:icon>
      </.dialog_header>

      <.dialog_body>
        <div data-testid="lookup-result-card" class="space-y-retro-8">
          <dl class="shadow-retro-field bg-white p-retro-8 text-xs">
            <div :for={row <- @rows} class="grid grid-cols-[112px_1fr] gap-retro-8 py-retro-2">
              <dt class="font-bold">{row.label}:</dt>
              <dd class="min-w-0 break-words">{row.value}</dd>
            </div>
          </dl>
        </div>
      </.dialog_body>

      <.dialog_footer>
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
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
