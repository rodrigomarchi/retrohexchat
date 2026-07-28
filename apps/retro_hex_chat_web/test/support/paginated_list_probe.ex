defmodule RetroHexChatWeb.PaginatedListProbe do
  @moduledoc """
  A minimal LiveView + LiveComponent that does nothing but exercise
  `RetroHexChatWeb.PaginatedList` against a real stream.

  `Phoenix.LiveView.stream/4` needs a socket with a lifecycle, so the wrapper
  cannot be tested against a bare `%Socket{}` — this is the smallest real host
  that makes its stream behaviour observable.
  """

  defmodule Island do
    @moduledoc false
    use Phoenix.LiveComponent

    alias RetroHexChatWeb.PaginatedList

    @impl true
    def mount(socket) do
      {:ok, PaginatedList.init(socket, :rows, page_size: 3)}
    end

    @impl true
    def update(%{action: {:reset, page}}, socket) do
      {:ok, PaginatedList.reset(socket, :rows, page)}
    end

    def update(%{action: {:append, page}}, socket) do
      {:ok, PaginatedList.append(socket, :rows, page)}
    end

    def update(%{action: {:prepend, page}}, socket) do
      {:ok, PaginatedList.prepend(socket, :rows, page)}
    end

    def update(%{action: :loading}, socket) do
      {:ok, PaginatedList.loading(socket, :rows)}
    end

    def update(%{action: {:load, fetch}}, socket) do
      {:ok, PaginatedList.load(socket, :rows, fetch)}
    end

    def update(assigns, socket), do: {:ok, Phoenix.Component.assign(socket, assigns)}

    @impl true
    def render(assigns) do
      ~H"""
      <div id="probe-mount">
        <ul id="probe-rows" phx-update="stream">
          <li :for={{dom_id, row} <- @streams.rows} id={dom_id} data-row={row.id}>
            {row.label}
          </li>
        </ul>
      </div>
      """
    end
  end

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={RetroHexChatWeb.PaginatedListProbe.Island} id="probe" />
    """
  end
end
