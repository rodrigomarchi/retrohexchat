Code.require_file("ci_impact.exs", __DIR__)

ExUnit.start()

defmodule CIImpactTest do
  use ExUnit.Case, async: true

  test "documentation-only changes select no technical checks" do
    plan = CIImpact.plan(["docs/plans/guardiao-ci-evolucao.md"])

    assert plan.checks == []
    assert plan.fallback == nil
    assert "docs" in plan.surfaces
  end

  test "global files fall back to the full guard" do
    plan = CIImpact.plan(["config/test.exs"])

    assert plan.fallback.level == :full
    assert plan.checks == CIImpact.full_checks()
    assert "full" in plan.surfaces
  end

  test "domain source protects domain and web consumers" do
    plan = CIImpact.plan(["apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex"])

    assert "compile" in plan.checks
    assert "format" in plan.checks
    assert "credo" in plan.checks
    assert "test_domain" in plan.checks
    assert "test_web" in plan.checks
    assert "test_feature" in plan.checks
    assert plan.fallback == nil
  end

  test "plain domain tests run the domain test check" do
    plan = CIImpact.plan(["apps/retro_hex_chat/test/retro_hex_chat/chat/message_test.exs"])

    assert plan.checks == ["format", "test_domain"]
  end

  test "web LiveView source runs web and feature tests" do
    plan = CIImpact.plan(["apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.ex"])

    assert "compile" in plan.checks
    assert "format" in plan.checks
    assert "credo" in plan.checks
    assert "test_web" in plan.checks
    assert "test_feature" in plan.checks
  end

  test "web feature tests run feature tests only plus formatting" do
    plan =
      CIImpact.plan([
        "apps/retro_hex_chat_web/test/retro_hex_chat_web/live/address_book_feature_test.exs"
      ])

    assert plan.checks == ["format", "test_feature"]
  end

  test "frontend hook changes run JS checks and focused E2E smokes" do
    plan =
      CIImpact.plan([
        "apps/retro_hex_chat_web/assets/js/hooks/ui/window_manager_hook.js"
      ])

    assert "lint_js" in plan.checks
    assert "js_tests" in plan.checks
    assert "e2e_smoke_chat" in plan.checks
    assert "e2e_smoke_dialogs" in plan.checks
    assert "e2e_smoke_mobile" in plan.checks
    refute "e2e" in plan.checks
  end

  test "critical chat CSS changes run CSS, bundle, and chat smoke checks" do
    plan =
      CIImpact.plan([
        "apps/retro_hex_chat_web/assets/css/retrohex/components/chat-formatting.css"
      ])

    assert plan.checks == ["lint_css", "lint_bundle", "e2e_smoke_chat"]
  end

  test "dialog CSS changes run dialog smoke checks" do
    plan =
      CIImpact.plan([
        "apps/retro_hex_chat_web/assets/css/retrohex/dialogs/address-book.css"
      ])

    assert "lint_css" in plan.checks
    assert "lint_bundle" in plan.checks
    assert "e2e_smoke_dialogs" in plan.checks
  end

  test "frontend i18n changes run tooling and browser i18n smoke checks" do
    plan =
      CIImpact.plan([
        "apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs/pt_BR.js"
      ])

    assert "lint_js" in plan.checks
    assert "js_tests" in plan.checks
    assert "py_tests" in plan.checks
    assert "i18n_quality" in plan.checks
    assert "e2e_smoke_i18n" in plan.checks
  end

  test "i18n catalog changes run i18n checks" do
    plan = CIImpact.plan(["apps/retro_hex_chat_web/priv/gettext/es/LC_MESSAGES/connect.po"])

    assert "py_tests" in plan.checks
    assert "i18n_quality" in plan.checks
  end

  test "unknown paths fall back to the full guard" do
    plan = CIImpact.plan(["unknown/tool.output"])

    assert plan.fallback.level == :full
    assert plan.checks == CIImpact.full_checks()
  end
end
