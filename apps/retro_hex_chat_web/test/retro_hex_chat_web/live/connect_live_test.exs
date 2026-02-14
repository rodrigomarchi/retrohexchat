defmodule RetroHexChatWeb.ConnectLiveTest do
  use RetroHexChatWeb.ConnCase

  import Phoenix.LiveViewTest

  @moduletag :liveview

  describe "mount" do
    test "renders connection dialog with nickname input", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Connect to RetroHexChat"
      assert html =~ ~s(name="nickname")
    end

    test "renders title and branding", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "RetroHexChat"
      assert html =~ "Connect"
    end

    test "renders OnboardingHook on root element", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(phx-hook="OnboardingHook")
    end
  end

  describe "validate" do
    test "shows error for empty nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => ""})
      # Empty nickname should either show error or keep button disabled
      assert html =~ "disabled" or html =~ "error"
    end

    test "shows error for invalid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => " bad"})
      assert html =~ "error-text"
    end

    test "clears error for valid nickname", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = view |> element("form") |> render_change(%{"nickname" => "ValidNick"})
      refute html =~ "error-text"
    end
  end

  describe "nickname boundary" do
    test "connect with single-char nickname succeeds", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "A"})
      result = view |> element("form") |> render_submit(%{"nickname" => "A"})
      assert {:error, {:live_redirect, %{to: "/chat?nickname=A"}}} = result
    end

    test "connect with 16-char nickname succeeds", %{conn: conn} do
      nick = String.duplicate("A", 16)
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => nick})
      result = view |> element("form") |> render_submit(%{"nickname" => nick})
      expected_path = "/chat?nickname=#{nick}"
      assert {:error, {:live_redirect, %{to: ^expected_path}}} = result
    end
  end

  describe "connect" do
    test "valid submit navigates to /chat", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      view |> element("form") |> render_change(%{"nickname" => "TestUser"})
      result = view |> element("form") |> render_submit(%{"nickname" => "TestUser"})
      assert {:error, {:live_redirect, %{to: "/chat?nickname=TestUser"}}} = result
    end
  end

  describe "wizard flow" do
    test "wizard renders Step 1 when wizard_mode is true", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate JS hook pushing check_onboarding with first_visit: true
      html = render_click(view, "check_onboarding", %{"first_visit" => true})

      assert html =~ "Assistente de Configuração"
      assert html =~ "Passo 1 de 3"
      assert html =~ "wizard-logo"
      assert html =~ "wizard-nickname-input"
    end

    test "Step 1 shows nickname input and tip text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      html = render(view)

      assert html =~ "Escolha seu nickname"
      assert html =~ "Seu nick é como seu nome no chat"
    end

    test "wizard_validate_nickname validates input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})

      # Invalid nickname
      html = render_click(view, "wizard_validate_nickname", %{"nickname" => " bad"})
      assert html =~ "wizard-nickname-error"

      # Valid nickname
      html = render_click(view, "wizard_validate_nickname", %{"nickname" => "GoodNick"})
      refute html =~ "wizard-nickname-error"
    end

    test "wizard_next from welcome moves to server step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      render_click(view, "wizard_validate_nickname", %{"nickname" => "TestUser"})

      html = render_click(view, "wizard_next", %{"step" => "welcome"})

      assert html =~ "Passo 2 de 3"
      assert html =~ "Configuração do Servidor"
    end

    test "wizard_next from server moves to channels step", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      render_click(view, "wizard_validate_nickname", %{"nickname" => "TestUser"})
      render_click(view, "wizard_next", %{"step" => "welcome"})

      html = render_click(view, "wizard_next", %{"step" => "server"})

      assert html =~ "Passo 3 de 3"
      assert html =~ "Escolha canais"
    end

    test "wizard_back navigates backward", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      render_click(view, "wizard_validate_nickname", %{"nickname" => "TestUser"})
      render_click(view, "wizard_next", %{"step" => "welcome"})

      html = render_click(view, "wizard_back", %{"step" => "server"})

      assert html =~ "Passo 1 de 3"
    end

    test "wizard_dismiss returns to normal form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})

      html = render_click(view, "wizard_dismiss", %{})

      assert html =~ "Connect to RetroHexChat"
      refute html =~ "Assistente de Configuração"
    end

    test "wizard_skip navigates to /chat with onboarded param", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      render_click(view, "wizard_validate_nickname", %{"nickname" => "TestUser"})
      render_click(view, "wizard_next", %{"step" => "welcome"})
      render_click(view, "wizard_next", %{"step" => "server"})

      result = render_click(view, "wizard_skip", %{})
      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "/chat"
      assert path =~ "nickname=TestUser"
      assert path =~ "onboarded=true"
    end

    test "wizard_complete navigates with selected channels", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      render_click(view, "check_onboarding", %{"first_visit" => true})
      render_click(view, "wizard_validate_nickname", %{"nickname" => "TestUser"})
      render_click(view, "wizard_next", %{"step" => "welcome"})
      render_click(view, "wizard_next", %{"step" => "server"})
      render_click(view, "wizard_toggle_channel", %{"channel" => "#general"})

      result = render_click(view, "wizard_complete", %{})
      assert {:error, {:live_redirect, %{to: path}}} = result
      assert path =~ "join="
      assert path =~ "onboarded=true"
    end

    test "wizard_mode false shows normal connect form", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = render_click(view, "check_onboarding", %{"first_visit" => false})

      assert html =~ "Connect to RetroHexChat"
      refute html =~ "Assistente de Configuração"
    end
  end
end
