defmodule RetroHexChatWeb.AnalyticsTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Utils
  alias RetroHexChatWeb.Analytics

  defp pushed(socket), do: Utils.get_push_events(socket)

  defp socket, do: %Phoenix.LiveView.Socket{}

  test "sends an event with its params" do
    socket = Analytics.track(socket(), "channel_view", %{channel: "#lobby"})

    assert [["analytics", %{name: "channel_view", params: %{channel: "#lobby"}}]] = pushed(socket)
  end

  test "an event it does not know is a crash, not a silent new report" do
    assert_raise FunctionClauseError, fn -> Analytics.track(socket(), "nope") end
  end

  test "a member is sent with the account id, a visitor without one" do
    assert [["analytics_user", %{member: "yes", user_id: 7}]] =
             socket() |> Analytics.identify(7) |> pushed()

    assert [["analytics_user", %{member: "no", user_id: nil}]] =
             socket() |> Analytics.identify(nil) |> pushed()
  end
end
