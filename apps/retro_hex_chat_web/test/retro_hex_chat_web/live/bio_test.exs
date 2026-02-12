defmodule RetroHexChatWeb.BioTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  describe "/bio command" do
    test "set bio shows confirmation message", %{conn: conn} do
      nick = "Bio1#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio Elixir enthusiast"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Bio set: Elixir enthusiast"
    end

    test "view bio shows current bio", %{conn: conn} do
      nick = "Bio2#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Set bio first
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio Hello world"})

      Process.sleep(50)

      # View bio
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Your bio: Hello world"
    end

    test "view bio with no bio set shows help message", %{conn: conn} do
      nick = "Bio3#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "No bio set"
    end

    test "clear bio shows confirmation", %{conn: conn} do
      nick = "Bio4#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Set bio first
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio Something"})

      Process.sleep(50)

      # Clear bio
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio clear"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Bio cleared"
    end

    test "bio appears in whois output", %{conn: conn} do
      nick = "Bio5#{System.unique_integer([:positive])}"
      target = "Bio6#{System.unique_integer([:positive])}"

      {:ok, target_view, _html} = live(conn, "/chat?nickname=#{target}")

      # Target sets their bio
      target_view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio I love retro computing"})

      Process.sleep(50)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Whois the target
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Bio:"
      assert html =~ "I love retro computing"
    end

    test "whois without bio does not show bio field", %{conn: conn} do
      nick = "Bio7#{System.unique_integer([:positive])}"
      target = "Bio8#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(conn, "/chat?nickname=#{target}")
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      # Should show whois but NOT a Bio: line
      assert html =~ "Whois: #{target}"
      refute html =~ "Bio:"
    end

    test "truncation warning shown for long bio", %{conn: conn} do
      nick = "Bio9#{System.unique_integer([:positive])}"
      long_bio = String.duplicate("x", 250)

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/bio #{long_bio}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "truncated to 200 characters"
    end
  end
end
