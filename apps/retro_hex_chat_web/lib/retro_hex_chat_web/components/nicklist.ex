defmodule RetroHexChatWeb.Components.Nicklist do
  @moduledoc """
  User list grouped by role: owners (~), operators (@), half-operators (%),
  voiced (+), regular users. Sorted alphabetically within groups.
  Shows away status and group counts. Empty groups are hidden.
  """
  use Phoenix.Component

  attr :users, :list, default: []
  attr :nick_color_fn, :any, default: nil

  @spec nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist(assigns) do
    grouped = group_users(assigns.users)
    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <div class="nicklist" id="nicklist-container" phx-hook="NicklistHook">
      <div class="sidebar-tab-bar sidebar-tab-bar--right">
        <div class="tab-item tab-active">
          <span class="tab-label">Users ({length(@users)})</span>
          <button
            type="button"
            class="tab-close"
            phx-click="toggle_nicklist"
            title="Hide user list"
            aria-label="Hide user list"
          >
            ×
          </button>
        </div>
      </div>
      <div
        :if={@users == []}
        class="empty-state nicklist-empty-state"
        data-testid="nicklist-empty-state"
      >
        <p>Nobody here — you're the first!</p>
      </div>
      <ul :if={@users != []} class="nicklist-list">
        <.nick_group
          :if={@grouped.owners != []}
          label="Owners"
          count={length(@grouped.owners)}
          users={@grouped.owners}
          prefix="~"
          role_class="nick-owner"
          nick_color_fn={@nick_color_fn}
        />
        <.nick_group
          :if={@grouped.operators != []}
          label="Operators"
          count={length(@grouped.operators)}
          users={@grouped.operators}
          prefix="@"
          role_class="nick-operator"
          nick_color_fn={@nick_color_fn}
        />
        <.nick_group
          :if={@grouped.half_operators != []}
          label="Half-Ops"
          count={length(@grouped.half_operators)}
          users={@grouped.half_operators}
          prefix="%"
          role_class="nick-halfop"
          nick_color_fn={@nick_color_fn}
        />
        <.nick_group
          :if={@grouped.voiced != []}
          label="Voiced"
          count={length(@grouped.voiced)}
          users={@grouped.voiced}
          prefix="+"
          role_class="nick-voiced"
          nick_color_fn={@nick_color_fn}
        />
        <.nick_group
          :if={@grouped.regular != []}
          label="Regular"
          count={length(@grouped.regular)}
          users={@grouped.regular}
          prefix=""
          role_class="nick-regular"
          nick_color_fn={@nick_color_fn}
        />
      </ul>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :users, :list, required: true
  attr :prefix, :string, required: true
  attr :role_class, :string, required: true
  attr :nick_color_fn, :any, default: nil

  defp nick_group(assigns) do
    ~H"""
    <li class="nicklist-group-header">{@label} ({@count})</li>
    <li
      :for={user <- @users}
      class={"#{@role_class} #{if user.away, do: "nick-away", else: ""}"}
      phx-click="nick_right_click"
      phx-value-nick={user.nickname}
      style={nick_style(@nick_color_fn, user.nickname)}
    >
      {@prefix}{user.nickname}
    </li>
    """
  end

  @spec nick_style((String.t() -> String.t()) | nil, String.t()) :: String.t()
  defp nick_style(nil, _nickname), do: ""
  defp nick_style(color_fn, nickname), do: "color: #{color_fn.(nickname)};"

  @spec group_users(list(map())) :: %{
          owners: list(map()),
          operators: list(map()),
          half_operators: list(map()),
          regular: list(map()),
          voiced: list(map())
        }
  defp group_users(users) do
    %{
      owners:
        users
        |> Enum.filter(&(&1.role == :owner))
        |> Enum.sort_by(& &1.nickname),
      operators:
        users
        |> Enum.filter(&(&1.role == :operator))
        |> Enum.sort_by(& &1.nickname),
      half_operators:
        users
        |> Enum.filter(&(&1.role == :half_operator))
        |> Enum.sort_by(& &1.nickname),
      voiced:
        users
        |> Enum.filter(&(&1.role == :voiced))
        |> Enum.sort_by(& &1.nickname),
      regular:
        users
        |> Enum.filter(&(&1.role == :regular))
        |> Enum.sort_by(& &1.nickname)
    }
  end
end
