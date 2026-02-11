defmodule RetroHexChatWeb.Components.Nicklist do
  @moduledoc """
  User list grouped by role: operators (@), voiced (+), regular users.
  Sorted alphabetically within groups. Shows away status and group counts.
  """
  use Phoenix.Component

  attr :users, :list, default: []
  attr :nick_color_fn, :any, default: nil

  @spec nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist(assigns) do
    grouped = group_users(assigns.users)
    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <div class="nicklist">
      <div class="nicklist-header">Users ({length(@users)})</div>
      <ul class="nicklist-list">
        <li class="nicklist-group-header">Operators ({length(@grouped.operators)})</li>
        <li
          :for={user <- @grouped.operators}
          class={"nick-operator #{if user.away, do: "nick-away", else: ""}"}
          phx-click="nick_right_click"
          phx-value-nick={user.nickname}
          style={nick_style(@nick_color_fn, user.nickname)}
        >
          @{user.nickname}
        </li>
        <li class="nicklist-group-header">Voiced ({length(@grouped.voiced)})</li>
        <li
          :for={user <- @grouped.voiced}
          class={"nick-voiced #{if user.away, do: "nick-away", else: ""}"}
          phx-click="nick_right_click"
          phx-value-nick={user.nickname}
          style={nick_style(@nick_color_fn, user.nickname)}
        >
          +{user.nickname}
        </li>
        <li class="nicklist-group-header">Regular ({length(@grouped.regular)})</li>
        <li
          :for={user <- @grouped.regular}
          class={"nick-regular #{if user.away, do: "nick-away", else: ""}"}
          phx-click="nick_right_click"
          phx-value-nick={user.nickname}
          style={nick_style(@nick_color_fn, user.nickname)}
        >
          {user.nickname}
        </li>
      </ul>
    </div>
    """
  end

  @spec nick_style((String.t() -> String.t()) | nil, String.t()) :: String.t()
  defp nick_style(nil, _nickname), do: ""
  defp nick_style(color_fn, nickname), do: "color: #{color_fn.(nickname)};"

  @spec group_users(list(map())) :: %{
          operators: list(map()),
          regular: list(map()),
          voiced: list(map())
        }
  defp group_users(users) do
    %{
      operators:
        users
        |> Enum.filter(&(&1.role == :operator))
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
