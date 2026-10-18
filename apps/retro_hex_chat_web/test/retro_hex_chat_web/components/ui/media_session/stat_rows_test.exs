defmodule RetroHexChatWeb.Components.UI.MediaSession.StatRowsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.MediaSession.StatRows

  @moduletag :unit

  defp rows(assigns) do
    ~H"""
    <dl>
      <.stat_row label="Loss" value="2%" icon={:icon_warning} tip="Packets lost" info_open={@open} />
      <.stat_status label="Audio" active={@active} active_label="Active" idle_label="Idle" />
    </dl>
    """
  end

  test "a reading is a label and its value, with the tip as a tooltip" do
    html = render_component(&rows/1, %{open: false, active: true})

    assert html =~ "<dt"
    assert html =~ "2%"
    assert html =~ ~s(title="Packets lost")
    refute html =~ "<p"
  end

  test "an opened tip is written under the reading" do
    assert render_component(&rows/1, %{open: true, active: true}) =~ "<p"
  end

  test "a channel's state is the caller's word, in success colour only while active" do
    active = render_component(&rows/1, %{open: false, active: true})
    idle = render_component(&rows/1, %{open: false, active: false})

    assert active =~ "Active"
    assert active =~ "text-success"
    assert idle =~ "Idle"
    refute idle =~ "text-success"
  end
end
