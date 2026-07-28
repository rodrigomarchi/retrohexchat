defmodule RetroHexChatWeb.Components.UI.ListStates do
  @moduledoc """
  The states every list in the app can be in, as shared components.

  A list is not just its rows. It is also: empty, loading its first page,
  loading another page, exhausted, truncated, or broken. Before this module the
  app had no end marker at all and no error state whatsoever, so a query that
  failed rendered as a list that was merely short.

  `list_empty_state/1` is deliberately **not** a new empty state: it is
  `UI.EmptyState.empty_state/1` — which already existed and was adopted by
  exactly one caller — wrapped in an attribute API. Fifteen dialogs hand-rolled
  their own instead of using it, and slots are the likely reason: every adoption
  meant writing three of them. Attributes make the shared component cheaper to
  reach for than a bespoke div, which is the only way the other fifteen ever
  converge on it.

  Accessibility is part of the contract here, not decoration:

    * `list_end_marker/1` and `list_announcer/1` are polite live regions — they
      report, they do not interrupt.
    * `list_error_retry/1` is an alert, because a failed page is the one state a
      reader must not scroll past without noticing.
    * `list_load_more_button/1` exists so pagination is reachable without a
      scroll gesture. Auto-loading alone strands keyboard and screen-reader
      users; the button is the accessible path and stays visible alongside it.
    * `list_skeleton/1` is `aria-hidden` — it carries no information.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.EmptyState
  import RetroHexChatWeb.Components.UI.Skeleton

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc """
  Shown in place of the rows when a list has nothing in it.

  An attribute-shaped front door to `UI.EmptyState.empty_state/1`. Pass `text`
  when the reader can do something about it ("Try a different filter"), leave it
  off when empty is simply empty.
  """
  attr :title, :string, required: true
  attr :text, :string, default: nil
  attr :icon, :atom, default: :list
  attr :class, :string, default: nil
  attr :rest, :global

  slot :action, doc: "Optional call to action, e.g. a button that clears the filter"

  @spec list_empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def list_empty_state(assigns) do
    ~H"""
    <.empty_state
      class={classes(["list-empty-state", @class])}
      data-testid="list-empty-state"
      {@rest}
    >
      <:icon><.state_icon icon={@icon} /></:icon>
      <:title>{@title}</:title>
      <:description :if={@text}>
        <span class="list-empty-state__text">{@text}</span>
      </:description>
      <:action :if={@action != []}>{render_slot(@action)}</:action>
    </.empty_state>
    """
  end

  @doc """
  Closes a paginated list once there is nothing more to fetch.

  Without it the end of a list is indistinguishable from a load that never
  finished — the reader waits at the edge for rows that are not coming.
  """
  attr :text, :string, default: nil
  attr :class, :string, default: nil
  attr :testid, :string, default: "list-end-marker"
  attr :rest, :global

  @spec list_end_marker(map()) :: Phoenix.LiveView.Rendered.t()
  def list_end_marker(assigns) do
    assigns = assign_new(assigns, :label, fn -> assigns.text || dgettext("ui", "End of list") end)

    ~H"""
    <div
      class={classes(["list-end-marker", @class])}
      data-testid={@testid}
      role="status"
      aria-live="polite"
      {@rest}
    >
      <span class="list-end-marker__rule" aria-hidden="true"></span>
      <span class="list-end-marker__label">{@label}</span>
      <span class="list-end-marker__rule" aria-hidden="true"></span>
    </div>
    """
  end

  @doc """
  The keyboard-reachable way to fetch the next page.

  Kept alongside scroll-triggered loading rather than instead of it: the scroll
  is the fast path for a pointer, this is the only path for a keyboard.
  """
  attr :target, :any, required: true, doc: "phx-target of the island owning the list"
  attr :event, :string, default: "load_more"
  attr :loading, :boolean, default: false
  attr :label, :string, default: nil
  attr :class, :string, default: nil

  attr :testid, :string,
    default: "list-load-more",
    doc: "Names the button itself; a window with two paginated lists needs two names"

  attr :rest, :global

  @spec list_load_more_button(map()) :: Phoenix.LiveView.Rendered.t()
  def list_load_more_button(assigns) do
    assigns =
      assigns
      |> assign_new(:resolved_label, fn ->
        assigns.label || dgettext("ui", "Load more")
      end)
      |> assign(:busy_label, dgettext("ui", "Loading..."))

    ~H"""
    <div class={classes(["list-load-more", @class])} {@rest}>
      <button
        type="button"
        class="list-load-more__button"
        data-testid={@testid}
        phx-click={@event}
        phx-target={@target}
        disabled={@loading}
        aria-busy={to_string(@loading)}
      >
        {if @loading, do: @busy_label, else: @resolved_label}
      </button>
    </div>
    """
  end

  @doc """
  Discloses that the list on screen is not the whole list.

  Renders nothing unless something is actually hidden, so it reads as a warning
  rather than as furniture. This is the component that keeps a capped query from
  quietly presenting itself as complete.
  """
  attr :shown, :integer, required: true
  attr :total, :integer, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec list_count_strip(map()) :: Phoenix.LiveView.Rendered.t()
  def list_count_strip(assigns) do
    ~H"""
    <p
      :if={truncated?(@shown, @total)}
      class={classes(["list-count-strip", @class])}
      data-testid="list-count-strip"
      {@rest}
    >
      {dgettext("ui", "Showing %{shown} of %{total}", shown: @shown, total: @total)}
    </p>
    """
  end

  @doc "Shown when a page failed to load, with the way to try again."
  attr :on_retry, :string, required: true
  attr :target, :any, required: true
  attr :text, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec list_error_retry(map()) :: Phoenix.LiveView.Rendered.t()
  def list_error_retry(assigns) do
    assigns =
      assigns
      |> assign_new(:message, fn ->
        assigns.text || dgettext("ui", "Could not load more items.")
      end)
      |> assign(:retry_label, dgettext("ui", "Try again"))

    ~H"""
    <div
      class={classes(["list-error-retry", @class])}
      data-testid="list-error-retry"
      role="alert"
      {@rest}
    >
      <span class="list-error-retry__icon" aria-hidden="true">
        <Icons.icon_warning class="h-4 w-4" />
      </span>
      <span class="list-error-retry__text">{@message}</span>
      <button
        type="button"
        class="list-error-retry__button"
        data-testid="list-error-retry-button"
        phx-click={@on_retry}
        phx-target={@target}
      >
        {@retry_label}
      </button>
    </div>
    """
  end

  @doc """
  A live region that announces the outcome of a load.

  Distinct from the loading indicator on purpose: that one says work is
  happening, this one says what arrived. A screen-reader user who only hears
  "loading" never learns whether twenty rows appeared or the list ended.
  """
  attr :message, :string, default: nil

  attr :state, :map,
    default: nil,
    doc: "PaginatedList.State to derive the message from, when no message is given"

  attr :rest, :global

  @spec list_announcer(map()) :: Phoenix.LiveView.Rendered.t()
  def list_announcer(assigns) do
    assigns =
      assign_new(assigns, :announcement, fn -> assigns.message || announce(assigns.state) end)

    ~H"""
    <p
      class="sr-only"
      data-testid="list-announcer"
      role="status"
      aria-live="polite"
      aria-atomic="true"
      {@rest}
    >
      {@announcement}
    </p>
    """
  end

  @doc """
  Placeholder rows for a first load.

  Reserves the space the rows will occupy so the panel does not jump when they
  land — a spinner in an empty box cannot do that.
  """
  attr :rows, :integer, default: 6
  attr :class, :string, default: nil
  attr :rest, :global

  @spec list_skeleton(map()) :: Phoenix.LiveView.Rendered.t()
  def list_skeleton(assigns) do
    ~H"""
    <div
      class={classes(["list-skeleton", @class])}
      data-testid="list-skeleton"
      aria-hidden="true"
      {@rest}
    >
      <.skeleton :for={row <- 1..@rows//1} class="list-skeleton__row" data-row={row} />
    </div>
    """
  end

  # ── Internals ────────────────────────────────────────────────────

  # What a reader who cannot see the list needs told after a load: how much
  # arrived, or that there is nothing further to ask for. The loading indicator
  # already says work is happening; this says how it ended.
  @spec announce(State.t() | nil) :: String.t() | nil
  defp announce(nil), do: nil

  defp announce(%State{} = state) do
    cond do
      State.error?(state) -> dgettext("ui", "Could not load more items.")
      State.empty?(state) -> dgettext("ui", "The list is empty.")
      State.exhausted?(state) -> dgettext("ui", "End of list.")
      State.loaded?(state) -> dgettext("ui", "%{count} items loaded.", count: state.count)
      true -> nil
    end
  end

  @spec truncated?(integer(), integer() | nil) :: boolean()
  defp truncated?(_shown, nil), do: false
  defp truncated?(shown, total), do: total > shown

  attr :icon, :atom, required: true

  @spec state_icon(map()) :: Phoenix.LiveView.Rendered.t()
  defp state_icon(%{icon: :channels} = assigns) do
    ~H"""
    <Icons.icon_btn_channel_list class="h-6 w-6" />
    """
  end

  defp state_icon(%{icon: :people} = assigns) do
    ~H"""
    <Icons.icon_tab_nicklist class="h-6 w-6" />
    """
  end

  defp state_icon(assigns) do
    ~H"""
    <Icons.icon_document_alert class="h-6 w-6" />
    """
  end
end
