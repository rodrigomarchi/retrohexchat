defmodule RetroHexChatWeb.Admin.AppInfoPage do
  use Gettext, backend: RetroHexChatWeb.Gettext

  @moduledoc """
  Custom LiveDashboard page showing RetroHexChat application info:
  active channels and connected users.
  """
  use Phoenix.LiveDashboard.PageBuilder

  alias RetroHexChat.Channels
  alias RetroHexChat.Presence.Tracker

  @impl true
  def menu_link(_, _) do
    {:ok, dgettext("admin", "App Info")}
  end

  @impl true
  def render(assigns) do
    {channels, channel_count} = list_channels()
    user_count = count_connected_users(channels)

    channel_fields =
      Enum.map(channels, fn name ->
        users = Tracker.list_users("channel:#{name}")

        {dgettext("admin", "#%{name}", name: name),
         dgettext("admin", "%{users_count} users", users_count: length(users))}
      end)

    assigns =
      assigns
      |> Map.put(:channel_count, channel_count)
      |> Map.put(:user_count, user_count)
      |> Map.put(:channel_fields, channel_fields)

    ~H"""
    <.row>
      <:col>
        <.fields_card
          title={dgettext("admin", "Overview")}
          inner_title="Application Stats"
          fields={[
            {"Active Channels", @channel_count},
            {"Connected Users", @user_count}
          ]}
        />
      </:col>
      <:col>
        <.fields_card
          title={dgettext("admin", "Channels")}
          fields={@channel_fields}
        />
      </:col>
    </.row>
    """
  end

  @spec list_channels() :: {[String.t()], non_neg_integer()}
  defp list_channels do
    registry = Channels.Registry.registry_name()

    names =
      Registry.select(registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.sort()

    {names, length(names)}
  end

  @spec count_connected_users([String.t()]) :: non_neg_integer()
  defp count_connected_users(channels) do
    channels
    |> Enum.flat_map(fn name ->
      Tracker.list_users("channel:#{name}")
      |> Enum.map(& &1.nickname)
    end)
    |> Enum.uniq()
    |> length()
  end
end
