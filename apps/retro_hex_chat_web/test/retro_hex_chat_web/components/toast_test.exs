defmodule RetroHexChatWeb.Components.ToastTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.Toast

  @moduletag :unit

  defp tips_state(html) do
    [_, json] = Regex.run(~r/data-tips-state="([^"]*)"/, html)
    json |> String.replace("&quot;", "\"") |> Jason.decode!()
  end

  test "the chat's container carries the person's tips" do
    html =
      render_component(&Toast.toast_container/1,
        tips_state: %{seen_tips: ["first_join"], suppressed: false}
      )

    assert %{"suppressed" => false, "seen_tips" => ["first_join"]} = tips_state(html)
  end

  test "a page of its own runs no tips, whatever the person's setting" do
    html = render_component(&Toast.toast_container/1, tips: false)

    assert %{"suppressed" => true} = tips_state(html)
  end
end
