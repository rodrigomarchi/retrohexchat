defmodule CIImpact do
  @moduledoc false

  @full_checks [
    "compile",
    "lint_js",
    "js_tests",
    "ci_impact_tests",
    "py_tests",
    "i18n_quality",
    "format",
    "credo",
    "lint_css",
    "test",
    "test_feature",
    "dialyzer"
  ]

  @check_order @full_checks ++
                 [
                   "lint_hooks",
                   "lint_bundle",
                   "test_domain",
                   "test_web",
                   "e2e_changed",
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
        |> maybe_critical_frontend(file)

      assets_css?(file) ->
        plan
        |> surface("assets_css", "#{file} changed frontend CSS")
        |> add("lint_css", "#{file} changed frontend CSS")
        |> add("lint_bundle", "#{file} can affect bundle budget")

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
        |> maybe_format_for_i18n(file)

      e2e_spec?(file) ->
        plan
        |> surface("e2e", "#{file} changed an E2E spec")
        |> add("e2e_changed", "#{file} changed an E2E spec")

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
  end

  defp maybe_critical_frontend(plan, file) do
    if path_contains_any?(file, [
         "/hooks/",
         "/lib/p2p/",
         "/lib/space/",
         "/lib/games/",
         "/lib/connection/",
         "/lib/i18n"
       ]) do
      add(plan, "e2e", "#{file} changed browser behavior used by journeys")
    else
      plan
    end
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
      "scripts/ci_impact_test.exs"
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
