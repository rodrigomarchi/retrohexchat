defmodule RetroHexChatWeb.AnalyticsFunnelTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  alias RetroHexChat.Services.NickServ

  @moduletag :liveview_feature

  defp submit_nickname(view, nickname) do
    view |> element(~s(form[phx-submit="connect"])) |> render_submit(%{"nickname" => nickname})
  end

  test "a new nickname is reported as a sign-up, never by name", %{conn: conn} do
    nick = "Funnel#{uid()}"
    {:ok, view, _html} = live(conn, ~p"/connect")

    assert_push_event(view, "analytics_user", %{member: "no"})

    submit_nickname(view, nick)
    assert_push_event(view, "analytics", %{name: "signup_start", params: params})
    assert params == %{}

    view
    |> element(~s(form[phx-submit="register"]))
    |> render_submit(%{"password" => "pass123", "password_confirm" => "pass123"})

    assert_push_event(view, "analytics", %{
      name: "sign_up",
      params: %{method: "nickname"},
      next_page: true
    })
  end

  test "a refused nickname and a wrong password are reported by reason", %{conn: conn} do
    nick = "Known#{uid()}"
    NickServ.register(nick, "pass123")
    {:ok, view, _html} = live(conn, ~p"/connect")

    submit_nickname(view, "has space")
    assert_push_event(view, "analytics", %{name: "signup_error", params: %{reason: "nickname"}})

    submit_nickname(view, nick)
    assert_push_event(view, "analytics", %{name: "login_start"})

    view |> element(~s(form[phx-submit="authenticate"])) |> render_submit(%{"password" => "nope"})

    assert_push_event(view, "analytics", %{
      name: "signup_error",
      params: %{reason: "wrong_password"}
    })
  end

  test "a visitor stopped by an account reports the feature that stopped them", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    render_hook(view, "open_paint", %{})

    assert_push_event(view, "analytics", %{name: "signup_prompt", params: %{feature: :paint}})
  end

  test "pages carry the measurement id only when there is one", %{conn: conn} do
    refute conn |> get(~p"/faq") |> html_response(200) =~ "ga-measurement-id"

    Application.put_env(:retro_hex_chat_web, :ga_measurement_id, "G-TEST")
    on_exit(fn -> Application.delete_env(:retro_hex_chat_web, :ga_measurement_id) end)

    assert conn |> get(~p"/faq") |> html_response(200) =~
             ~s(<meta name="ga-measurement-id" content="G-TEST">)
  end
end
