defmodule RetroHexChatWeb.Components.UI.GroupCall.MediaStateTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.Components.UI.GroupCall.MediaState

  test "a call that has not said is heard and seen, and shares no screen" do
    assert MediaState.enabled?(nil, :audio)
    assert MediaState.enabled?(%{media: %{}}, :video)
    refute MediaState.enabled?(%{media: %{}}, :screen)
  end

  test "reads a call's media or a bare media map alike" do
    refute MediaState.enabled?(%{media: %{audio: false}}, :audio)
    assert MediaState.enabled?(%{screen: true}, :screen)
  end
end
