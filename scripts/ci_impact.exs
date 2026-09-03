defmodule CIImpact do
  @moduledoc false

  @full_checks [
    "compile",
    "lint_js",
    "js_tests",
    "ci_impact_tests",
    "ci_partition_profile_plan",
    "py_tests",
    "i18n_quality",
    "i18n_coverage",
    "i18n_catalog",
    "lint_hooks",
    "lint_bundle",
    "e2e_catalog",
    "format",
    "credo",
    "lint_css",
    "test",
    "test_feature",
    "dialyzer"
  ]

  @check_order @full_checks ++
                 [
                   "test_domain",
                   "test_web",
                   "e2e_changed",
                   "e2e_smoke_connect",
                   "e2e_smoke_chat",
                   "e2e_smoke_dialogs",
                   "e2e_smoke_i18n",
                   "e2e_smoke_calls",
                   "e2e_smoke_mobile",
                   "e2e"
                 ]

  def full_checks, do: @full_checks

  def plan(files) do
    files
    |> normalize_files()
    |> Enum.reduce(empty_plan(), &classify_file/2)
    |> finalize()
  end

  def fallback(files, reason) do
    %{
      files: normalize_files(files),
      checks: @full_checks,
      skipped: [],
      surfaces: ["full"],
      reasons: %{"full" => [reason]},
      fallback: %{level: :full, reason: reason}
    }
  end

  defp normalize_files(files) do
    files
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.trim_leading(&1, "./"))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp empty_plan do
    %{
      files: [],
      checks: MapSet.new(),
      skipped: [],
      surfaces: MapSet.new(),
      reasons: %{},
      fallback: nil
    }
  end

  defp classify_file(file, plan) do
    plan = %{plan | files: [file | plan.files]}

    cond do
      global_file?(file) ->
        full(plan, "#{file} affects global CI, build, config, or shared test setup")

      docs_file?(file) ->
        surface(plan, "docs", "#{file} is documentation-only")

      domain_lib?(file) ->
        plan
        |> surface("domain", "#{file} changed domain source")
        |> add("compile", "#{file} is Elixir source")
        |> add("format", "#{file} is Elixir source")
        |> add("credo", "#{file} is Elixir source")
        |> add("i18n_coverage", "#{file} can add or drop a translatable string")
        |> add("i18n_catalog", "#{file} can add or drop a translatable string")
        |> add("test_domain", "#{file} changed the domain app")
        |> add("test_web", "web app depends on retro_hex_chat")
        |> maybe_domain_feature(file)

      domain_test?(file) ->
        plan
        |> surface("domain_test", "#{file} changed domain tests")
        |> add("format", "#{file} is Elixir test source")
        |> add("test_domain", "#{file} changed domain tests")

      web_lib?(file) ->
        plan
        |> surface("web", "#{file} changed web source")
        |> add("compile", "#{file} is Elixir source")
        |> add("format", "#{file} is Elixir source")
        |> add("credo", "#{file} is Elixir source")
        |> add("i18n_coverage", "#{file} can add or drop a translatable string")
        |> add("i18n_catalog", "#{file} can add or drop a translatable string")
        |> add("test_web", "#{file} changed the web app")
        |> maybe_web_feature(file)

      web_test?(file) ->
        plan
        |> surface("web_test", "#{file} changed web tests")
        |> add("format", "#{file} is Elixir test source")
        |> add(web_test_check(file), "#{file} changed web tests")

      assets_js?(file) ->
        plan
        |> surface("assets_js", "#{file} changed frontend JavaScript")
        |> add("lint_js", "#{file} changed frontend JavaScript")
        |> add("js_tests", "#{file} changed frontend JavaScript")
        |> maybe_i18n_asset(file)
        |> maybe_frontend_smokes(file)

      assets_css?(file) ->
        plan
        |> surface("assets_css", "#{file} changed frontend CSS")
        |> add("lint_css", "#{file} changed frontend CSS")
        |> add("lint_bundle", "#{file} can affect bundle budget")
        |> maybe_css_smokes(file)

      assets_config?(file) ->
        plan
        |> surface("assets_config", "#{file} changed frontend tooling")
        |> add("lint_js", "#{file} changed frontend tooling")
        |> add("js_tests", "#{file} changed frontend tooling")
        |> add("lint_bundle", "#{file} can affect bundle budget")

      i18n_file?(file) ->
        plan
        |> surface("i18n", "#{file} changed i18n source or catalogs")
        |> add("py_tests", "#{file} changed i18n source or catalogs")
        |> add("i18n_quality", "#{file} changed i18n source or catalogs")
        |> add("i18n_coverage", "#{file} changed i18n source or catalogs")
        |> add("i18n_catalog", "#{file} changed i18n source or catalogs")
        |> add_e2e_smoke("i18n", "#{file} can affect localized browser journeys")
        |> maybe_format_for_i18n(file)

      e2e_spec?(file) ->
        plan
        |> surface("e2e", "#{file} changed an E2E spec")
        |> add("e2e_changed", "#{file} changed an E2E spec")
        |> add("e2e_catalog", "#{file} can change the @flow headers the catalog is built from")

      e2e_support?(file) ->
        plan
        |> surface("e2e", "#{file} changed E2E shared support")
        |> add("e2e", "#{file} changed E2E shared support")

      script_test?(file) ->
        plan
        |> surface("script_tests", "#{file} changed script tests")
        |> add("ci_impact_tests", "#{file} changed script tests")
        |> add("py_tests", "#{file} changed script tests")

      true ->
        full(plan, "#{file} has no impact rule")
    end
  end

  defp finalize(%{fallback: %{level: :full}} = plan) do
    %{
      plan
      | files: plan.files |> Enum.reverse() |> Enum.sort(),
        checks: @full_checks,
        skipped: [],
        surfaces: plan.surfaces |> MapSet.put("full") |> sort_surfaces()
    }
  end

  defp finalize(plan) do
    checks = sort_checks(plan.checks)

    %{
      plan
      | files: plan.files |> Enum.reverse() |> Enum.sort(),
        checks: checks,
        skipped: @full_checks -- checks,
        surfaces: sort_surfaces(plan.surfaces)
    }
  end

  defp add(plan, check, reason) do
    %{
      plan
      | checks: MapSet.put(plan.checks, check),
        reasons: Map.update(plan.reasons, check, [reason], &[reason | &1])
    }
  end

  defp surface(plan, surface, reason) do
    %{
      plan
      | surfaces: MapSet.put(plan.surfaces, surface),
        reasons: Map.update(plan.reasons, surface, [reason], &[reason | &1])
    }
  end

  defp full(plan, reason) do
    %{
      plan
      | checks: MapSet.new(@full_checks),
        surfaces: MapSet.put(plan.surfaces, "full"),
        fallback: %{level: :full, reason: reason},
        reasons: Map.update(plan.reasons, "full", [reason], &[reason | &1])
    }
  end

  defp maybe_domain_feature(plan, file) do
    if path_contains_any?(file, [
         "/accounts/",
         "/channels/",
         "/chat/",
         "/commands/",
         "/p2p/",
         "/presence/",
         "/services/",
         "/calls/",
         "/group_call/"
       ]) do
      add(plan, "test_feature", "#{file} can affect LiveView journeys through domain behavior")
    else
      plan
    end
  end

  defp maybe_web_feature(plan, file) do
    plan =
      if path_contains_any?(file, [
           "/live/",
           "/components/ui/",
           "/controllers/app/",
           "/channels/"
         ]) do
        add(plan, "test_feature", "#{file} changed a web interaction surface")
      else
        plan
      end

    maybe_web_smokes(plan, file)
  end

  defp maybe_web_smokes(plan, file) do
    file
    |> web_smoke_surfaces()
    |> add_e2e_smokes(plan, file)
  end

  defp maybe_i18n_asset(plan, file) do
    if String.starts_with?(file, "apps/retro_hex_chat_web/assets/js/lib/i18n") do
      plan
      |> surface("i18n", "#{file} changed frontend i18n")
      |> add("py_tests", "#{file} changed frontend i18n")
      |> add("i18n_quality", "#{file} changed frontend i18n")
      |> add_e2e_smoke("i18n", "#{file} can affect localized browser journeys")
    else
      plan
    end
  end

  defp maybe_frontend_smokes(plan, file) do
    smoke_surfaces = frontend_smoke_surfaces(file)
    plan = add_e2e_smokes(smoke_surfaces, plan, file)

    if smoke_surfaces == [] and legacy_full_e2e_frontend?(file) do
      add(plan, "e2e", "#{file} changed browser behavior without a focused smoke yet")
    else
      plan
    end
  end

  defp maybe_css_smokes(plan, file) do
    file
    |> css_smoke_surfaces()
    |> add_e2e_smokes(plan, file)
  end

  defp add_e2e_smokes(surfaces, plan, file) do
    Enum.reduce(surfaces, plan, fn surface, acc ->
      add_e2e_smoke(acc, surface, "#{file} affects the #{surface} browser smoke")
    end)
  end

  defp add_e2e_smoke(plan, surface, reason) do
    check = "e2e_smoke_#{surface}"

    plan
    |> surface("e2e_#{surface}", reason)
    |> add(check, reason)
  end

  defp web_smoke_surfaces(file) do
    surfaces = []

    surfaces =
      if path_contains_any?(file, [
           "/live/app/connect_live",
           "/live/app/session_helpers",
           "/components/ui/connect/",
           "/components/ui/shell/connect_status_bar",
           "/controllers/app/session_controller",
           "/controllers/app/lobby_redirect_controller",
           "/app/trusted_device_cookie",
           "/plugs/put_trusted_device"
         ]) do
        ["connect" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/live/app/chat_live",
           "/live/app/chat_helpers",
           "/live/chat_live/",
           "/components/layouts/chat",
           "/components/ui/shell/chat_app_header",
           "/components/ui/shell/menu_bar",
           "/components/ui/shell/menu_bar_app",
           "/components/ui/shell/status_bar_app"
         ]) do
        ["chat" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/live/chat_live/ui_actions/",
           "/live/chat_live/settings_dialogs_events",
           "/live/chat_live/address_book_events",
           "/live/chat_live/alias_events",
           "/live/chat_live/autojoin_events",
           "/live/chat_live/bot_events",
           "/live/chat_live/notify_events",
           "/live/chat_live/profile_events",
           "/live/chat_live/timer_events",
           "/components/ui/primitives/alert_dialog",
           "/components/ui/primitives/dialog",
           "/components/ui/primitives/dropdown_menu",
           "/components/ui/primitives/sheet"
         ]) do
        ["dialogs" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/i18n",
           "/gettext",
           "/live/put_locale",
           "/controllers/locale_controller",
           "/components/ui/shell/language_menu"
         ]) do
        ["i18n" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/channels/group_call_channel",
           "/controllers/calls_health_controller",
           "/live/app/group_call_stats",
           "/live/app/p2p_stats",
           "/components/icons/call_controls",
           "/components/icons/media",
           "/components/diagrams/p2p",
           "/components/diagrams/conference"
         ]) do
        ["calls" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/live/app/chat_live",
           "/components/layouts/chat",
           "/components/ui/shell/chat_app_header",
           "/components/ui/shell/menu_bar"
         ]) do
        ["mobile" | surfaces]
      else
        surfaces
      end

    surfaces |> Enum.uniq() |> Enum.sort()
  end

  defp frontend_smoke_surfaces(file) do
    surfaces =
      if file in [
           "apps/retro_hex_chat_web/assets/js/app.js",
           "apps/retro_hex_chat_web/assets/js/hooks/critical_hooks.js",
           "apps/retro_hex_chat_web/assets/js/hooks/registry.js"
         ] do
        ["calls", "chat", "connect", "dialogs", "i18n", "mobile"]
      else
        []
      end

    surfaces =
      if path_contains_any?(file, [
           "/hooks/connection/connect_form_hook",
           "/lib/connection/client_info",
           "/lib/connection/device_label_suggestion"
         ]) do
        ["connect" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/hooks/connection/",
           "/hooks/chat/",
           "/hooks/input/",
           "/hooks/notifications/",
           "/hooks/ui/window_manager_hook",
           "/hooks/ui/conversations_hook",
           "/hooks/ui/nicklist_hook",
           "/lib/chat/",
           "/lib/input/",
           "/lib/notifications/",
           "/lib/ui/document_title",
           "/lib/ui/unread"
         ]) do
        ["chat" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/hooks/ui/window_manager_hook",
           "/hooks/ui/menu_bar_hook",
           "/hooks/ui/menu_reposition_hook",
           "/hooks/ui/toolbar_group_hook",
           "/hooks/ui/url_catcher_hook"
         ]) do
        ["dialogs" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/lib/i18n",
           "/lib/i18n_catalog"
         ]) do
        ["i18n" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/hooks/group_call/",
           "/hooks/p2p/",
           "/hooks/lobby/lobby_media_hook",
           "/hooks/lobby/lobby_webrtc_hook",
           "/lib/p2p/"
         ]) do
        ["calls" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/hooks/ui/viewport_detect_hook",
           "/hooks/ui/window_manager_hook",
           "/hooks/ui/menu_bar_hook",
           "/hooks/input/",
           "/lib/input/"
         ]) do
        ["mobile" | surfaces]
      else
        surfaces
      end

    surfaces |> Enum.uniq() |> Enum.sort()
  end

  defp css_smoke_surfaces(file) do
    surfaces =
      if file == "apps/retro_hex_chat_web/assets/css/retrohex.css" do
        ["calls", "chat", "connect", "dialogs", "mobile"]
      else
        []
      end

    surfaces =
      if path_contains_any?(file, [
           "/base/",
           "/layout/window-manager.css",
           "/components/app-menu.css",
           "/components/chat-",
           "/components/activity-and-message-scroll.css",
           "/components/connection-status.css",
           "/components/list-states.css"
         ]) do
        ["chat" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/dialogs/",
           "/layout/window-manager.css",
           "/components/app-menu.css"
         ]) do
        ["dialogs" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/features/p2p",
           "/features/group-call",
           "/features/file-transfer",
           "/components/media-session"
         ]) do
        ["calls" | surfaces]
      else
        surfaces
      end

    surfaces =
      if path_contains_any?(file, [
           "/layout/window-manager.css",
           "/components/app-menu.css",
           "/dialogs/channel-central.css"
         ]) do
        ["mobile" | surfaces]
      else
        surfaces
      end

    surfaces |> Enum.uniq() |> Enum.sort()
  end

  defp legacy_full_e2e_frontend?(file) do
    path_contains_any?(file, [
      "/lib/space/",
      "/hooks/space/",
      "/lib/games/",
      "/hooks/games/",
      "/hooks/lobby/lobby_game_canvas_hook"
    ])
  end

  defp maybe_format_for_i18n(plan, file) do
    if String.ends_with?(file, ".exs") do
      add(plan, "format", "#{file} is Elixir source")
    else
      plan
    end
  end

  defp web_test_check(file) do
    if String.contains?(file, "_feature_test.exs") do
      "test_feature"
    else
      "test_web"
    end
  end

  defp sort_checks(checks) do
    checks
    |> MapSet.to_list()
    |> Enum.sort_by(&(Enum.find_index(@check_order, fn check -> check == &1 end) || 999))
  end

  defp sort_surfaces(surfaces) do
    surfaces
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp global_file?(file) do
    file in [
      "Makefile",
      "mix.exs",
      "mix.lock",
      ".formatter.exs",
      ".credo.exs",
      "scripts/ci.exs",
      "scripts/ci_impact.exs",
      "scripts/ci_impact_test.exs",
      "scripts/ci_github_plan.exs",
      "scripts/ci_partition_profile.exs",
      "scripts/umbrella_boundary_audit.exs"
    ] or
      String.starts_with?(file, ".github/workflows/") or
      String.starts_with?(file, "config/") or
      String.contains?(file, "/test/support/") or
      String.ends_with?(file, "/test_helper.exs") or
      String.contains?(file, "/priv/repo/migrations/")
  end

  defp docs_file?(file), do: String.starts_with?(file, "docs/") or String.ends_with?(file, ".md")

  defp domain_lib?(file), do: String.starts_with?(file, "apps/retro_hex_chat/lib/")
  defp domain_test?(file), do: String.starts_with?(file, "apps/retro_hex_chat/test/")
  defp web_lib?(file), do: String.starts_with?(file, "apps/retro_hex_chat_web/lib/")
  defp web_test?(file), do: String.starts_with?(file, "apps/retro_hex_chat_web/test/")

  defp assets_js?(file) do
    String.starts_with?(file, "apps/retro_hex_chat_web/assets/js/") or
      String.starts_with?(file, "apps/retro_hex_chat_web/assets/test/") or
      String.starts_with?(file, "apps/retro_hex_chat_web/assets/scripts/")
  end

  defp assets_css?(file), do: String.starts_with?(file, "apps/retro_hex_chat_web/assets/css/")

  defp assets_config?(file) do
    file in [
      "apps/retro_hex_chat_web/assets/package.json",
      "apps/retro_hex_chat_web/assets/package-lock.json",
      "apps/retro_hex_chat_web/assets/eslint.config.mjs",
      "apps/retro_hex_chat_web/assets/vitest.config.js",
      "apps/retro_hex_chat_web/assets/tailwind.config.js",
      "apps/retro_hex_chat_web/assets/tsconfig.json"
    ]
  end

  defp i18n_file?(file) do
    String.starts_with?(file, "scripts/i18n") or
      String.contains?(file, "/priv/gettext/") or
      String.starts_with?(file, "apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs/")
  end

  defp e2e_spec?(file), do: String.starts_with?(file, "e2e/tests/")

  defp e2e_support?(file) do
    String.starts_with?(file, "e2e/helpers/") or
      String.starts_with?(file, "e2e/pages/") or
      file in [
        "e2e/global-setup.ts",
        "e2e/playwright.config.ts",
        "e2e/package.json",
        "e2e/package-lock.json",
        "e2e/tsconfig.json"
      ]
  end

  defp script_test?(file), do: String.starts_with?(file, "scripts/tests/")

  defp path_contains_any?(file, patterns), do: Enum.any?(patterns, &String.contains?(file, &1))
end
