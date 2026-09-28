defmodule RetroHexChatWeb.Components.UI.OpenTabConfirmDialog do
  @moduledoc """
  The warning that stands between a click and a second browser tab.

  Composed from dialog + button primitives.

  The confirm button is an **anchor**, not a `phx-click`, and that is the whole
  design. `rel="noopener"` is architecture in this product rather than styling —
  a tab that shares the opener's event loop was measured at 1203 ms against
  12 ms — and a scripted `window.open` fired from a confirmation callback is the
  shape a pop-up blocker refuses. A real `href` on the button the reader presses
  buys both for free, and `Button` renders an anchor whenever it is given one.
  The `phx-click` beside it only clears the pending target; a click binding
  leaves a real `href` alone.

  Three kinds, because the only useful sentence differs by destination:

    * `:surface` — a room of ours, named by `label`
    * `:attachment` — a file of ours, named by `label`
    * `:external` — somewhere else, and the reader gets the host in bold with
      the full URL under it. A link that is disguised is only ever given away by
      its address, so hiding the address would leave the warning with nothing
      the reader could act on.

  ## Usage

      <.open_tab_confirm_dialog
        id="open-tab-confirm"
        show={true}
        target={%{kind: :external, url: "https://example.com/a", host: "example.com"}}
        on_open="open_tab_confirm_open"
        on_cancel="open_tab_confirm_cancel"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the open-in-a-new-tab confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :target, :map,
    default: nil,
    doc: "the pending destination: `%{kind:, url:, label:, host:}`; `nil` when closed"

  attr :on_open, :any, default: nil, doc: "JS command or event name for confirming"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancelling"

  @spec open_tab_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def open_tab_confirm_dialog(assigns) do
    ~H"""
    <span data-testid="open-tab-confirm-dialog">
      <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="cd-dialog-wrap">
        <.dialog_header id={@id} title={title(@target)} on_close={@on_cancel}>
          <:icon><Icons.icon_btn_open class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="cd-dialog-body">
          <div class="cd-message-row">
            <span class="cd-message-icon" aria-hidden="true">
              <.kind_icon kind={kind(@target)} />
            </span>
            <div class="cd-message-copy">
              <p class="cd-message-text" data-testid="open-tab-confirm-message">
                {message(@target)}
              </p>
              <%!-- The address, and only when a host was actually resolved. It
                    wraps rather than truncates: the half of a URL that a
                    truncation eats is the path, which is exactly where a link
                    pretending to be somewhere else does its pretending.

                    A door of ours that declared itself external — the arcade,
                    whose own path redirects to the static host — has no host to
                    show, so it gets the sentence and no address. Printing a path
                    of ours under "you are leaving" would name the wrong place. --%>
              <p :if={show_url?(@target)} class="otc-url" data-testid="open-tab-confirm-url">
                {url(@target)}
              </p>
              <p class="cd-message-question">
                {dgettext("dialogs", "It opens in a new browser tab. This one stays where it is.")}
              </p>
            </div>
          </div>
        </.dialog_body>

        <.dialog_footer class="cd-dialog-footer">
          <%!-- The anchor is the door. See the moduledoc: `href` carries the
                reader out, `phx-click` only puts the dialog away. --%>
          <.button
            variant="default"
            href={url(@target)}
            target="_blank"
            rel="noopener"
            phx-click={@on_open}
            data-testid="open-tab-confirm-open"
            class="cd-dialog-action"
          >
            <:icon><Icons.icon_btn_open class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Open")}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="open-tab-confirm-cancel"
            class="cd-dialog-action"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  attr :kind, :atom, required: true

  defp kind_icon(%{kind: :external} = assigns) do
    ~H"""
    <Icons.icon_globe class="w-5 h-5" />
    """
  end

  defp kind_icon(%{kind: :attachment} = assigns) do
    ~H"""
    <Icons.icon_file_send class="w-5 h-5" />
    """
  end

  defp kind_icon(assigns) do
    ~H"""
    <Icons.icon_link class="w-5 h-5" />
    """
  end

  # A closed dialog still renders its markup, so every reader here answers for
  # `nil` as well as for a target. `:surface` is the fallback because it is the
  # one kind whose copy names nothing the reader has not already been told.
  @spec kind(map() | nil) :: atom()
  defp kind(%{kind: kind}) when kind in [:surface, :attachment, :external], do: kind
  defp kind(_target), do: :surface

  @spec url(map() | nil) :: String.t()
  defp url(%{url: url}) when is_binary(url) and url != "", do: url
  defp url(_target), do: "#"

  @spec show_url?(map() | nil) :: boolean()
  defp show_url?(target) do
    kind(target) == :external and presence(target && Map.get(target, :host)) != nil
  end

  @spec title(map() | nil) :: String.t()
  defp title(target) do
    case kind(target) do
      :external -> dgettext("dialogs", "Leaving RetroHexChat")
      _ours -> dgettext("dialogs", "Open in a New Tab")
    end
  end

  @spec message(map() | nil) :: String.t()
  defp message(target) do
    case {kind(target), label(target)} do
      {:external, host} when is_binary(host) ->
        dgettext("dialogs", "This link goes to %{host}, which is not part of RetroHexChat.",
          host: host
        )

      {:external, nil} ->
        dgettext("dialogs", "This link goes somewhere outside RetroHexChat.")

      {:attachment, name} when is_binary(name) ->
        dgettext("dialogs", "This opens the attachment %{name}.", name: name)

      {:attachment, nil} ->
        dgettext("dialogs", "This opens the attachment.")

      {:surface, name} when is_binary(name) ->
        dgettext("dialogs", "This opens %{name}.", name: name)

      {:surface, nil} ->
        dgettext("dialogs", "This opens another part of RetroHexChat.")
    end
  end

  # For an external destination the label *is* the host, so the message and the
  # address below it can never disagree about where the reader is going.
  @spec label(map() | nil) :: String.t() | nil
  defp label(%{kind: :external} = target) do
    presence(Map.get(target, :host))
  end

  defp label(target) when is_map(target), do: presence(Map.get(target, :label))
  defp label(_target), do: nil

  @spec presence(term()) :: String.t() | nil
  defp presence(value) when is_binary(value) and value != "", do: value
  defp presence(_value), do: nil
end
