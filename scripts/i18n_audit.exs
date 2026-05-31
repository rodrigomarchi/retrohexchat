#!/usr/bin/env elixir

# Finds likely user-visible literals that still need to move behind Gettext.
# This is intentionally heuristic: it is a migration aid and CI guard, not a
# parser for every language construct in the repo.

defmodule I18nAudit do
  @default_patterns [
    "apps/retro_hex_chat_web/lib/**/*.ex",
    "apps/retro_hex_chat_web/lib/**/*.heex",
    "apps/retro_hex_chat_web/assets/js/**/*.js",
    "apps/retro_hex_chat/lib/**/*.ex"
  ]

  @extensions ~w(.ex .exs .heex .js)

  @ui_attrs ~w(
    aria-label aria-description aria-valuetext title alt placeholder label legend text
    confirm data-confirm data-title data-label
  )

  @ui_attr_pattern Enum.join(@ui_attrs, "|")

  @heex_attr_double Regex.compile!(
                      "(?:^|[\\s<])(?<attr>#{@ui_attr_pattern})\\s*=\\s*\"(?<text>(?:\\\\\"|[^\"])+)\""
                    )
  @heex_attr_single Regex.compile!(
                      "(?:^|[\\s<])(?<attr>#{@ui_attr_pattern})\\s*=\\s*'(?<text>(?:\\\\'|[^'])+)'"
                    )
  @heex_attr_braced_double Regex.compile!(
                             "(?:^|[\\s<])(?<attr>#{@ui_attr_pattern})\\s*=\\s*\\{\\s*\"(?<text>(?:\\\\\"|[^\"])+)\"\\s*\\}"
                           )
  @heex_attr_braced_single Regex.compile!(
                             "(?:^|[\\s<])(?<attr>#{@ui_attr_pattern})\\s*=\\s*\\{\\s*'(?<text>(?:\\\\'|[^'])+)'\\s*\\}"
                           )

  @heex_text_node ~r/>\s*([^<>{}\n]*[[:alpha:]][^<>{}\n]*)\s*</u
  @double_string ~r/"(?:\\.|[^"\\])*"/u
  @js_string ~r/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`/u
  @gettext_call ~r/\b(?:gettext|dgettext|ngettext|dngettext|pgettext|dpgettext)(?:_noop)?\s*\(/u
  @js_i18n_call ~r/\b(?:t|tn|gettext|ngettext)\s*\(/u
  @logger_call ~r/\bLogger\.(?:debug|info|notice|warning|error|critical|alert|emergency)\s*\(/u

  @skip_key ~r/(^|[\s{,(])(?:class|id|type|name|value|href|src|to|patch|navigate|method|role|for|form|rel|target|variant|size|speed|color|icon|path|url|key|event|hook|trigger|command|cmd|module|app|version|env|token|secret|adapter|router|endpoint|statics|pubsub_server|signing_salt|channel|nickname|password|auth_token|timezone|mode|state|webrtc_state|session_status|status|format|query|params|testid|data-testid|emoji_category|emoji_emojis|phx-[\w-]+|on_[a-z_]+)\s*[:=]\s*$/u

  @short_ui_words ~w(
    ok yes no close cancel save copy paste retry delete edit add remove join leave connect
    disconnect search clear apply reset back next prev previous done open accept decline mute
    unmute block unblock invite kick ban unban ignore unignore
  )

  @default_limit 120

  def main(args) do
    {opts, paths} = parse_args(args)

    if opts[:help] do
      print_usage()
      System.halt(0)
    end

    files = expand_paths(paths, opts[:include_tests])
    allowlist = load_allowlist(opts[:allowlist])

    findings =
      files
      |> Enum.flat_map(&scan_file/1)
      |> Enum.reject(&MapSet.member?(allowlist, &1.id))
      |> maybe_drop_low(opts[:strict])
      |> Enum.sort_by(&{severity_rank(&1.severity), &1.path, &1.line, &1.text})

    report = %{
      scanned_files: length(files),
      findings: findings,
      counts: counts(findings),
      allowlist_path: opts[:allowlist],
      strict: opts[:strict]
    }

    print_report(report, opts)

    if opts[:fail_on_findings] and findings != [] do
      System.halt(1)
    else
      System.halt(0)
    end
  end

  defp parse_args(args) do
    {opts, paths, invalid} =
      OptionParser.parse(args,
        strict: [
          allowlist: :string,
          fail_on_findings: :boolean,
          format: :string,
          help: :boolean,
          include_tests: :boolean,
          limit: :integer,
          strict: :boolean
        ],
        aliases: [f: :format, h: :help, l: :limit]
      )

    if invalid != [] do
      invalid_text = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
      IO.puts(:stderr, "Unknown option(s): #{invalid_text}")
      print_usage()
      System.halt(2)
    end

    opts =
      opts
      |> Keyword.put_new(:allowlist, "scripts/i18n_audit_allowlist.txt")
      |> Keyword.put_new(:format, "text")
      |> Keyword.put_new(:limit, @default_limit)
      |> Keyword.put_new(:strict, false)
      |> Keyword.put_new(:include_tests, false)
      |> Keyword.put_new(:fail_on_findings, false)

    unless opts[:format] in ~w(text markdown json) do
      IO.puts(:stderr, "Unsupported format: #{opts[:format]}")
      System.halt(2)
    end

    {opts, paths}
  end

  defp print_usage do
    IO.puts("""
    Usage:
      elixir scripts/i18n_audit.exs [paths...] [options]

    Options:
      --format text|markdown|json   Output format. Default: text
      --limit N                     Max findings printed in text/markdown. 0 means all
      --fail-on-findings            Exit 1 when high/medium findings exist
      --strict                      Include low-confidence findings
      --include-tests               Scan test files too
      --allowlist PATH              File with finding IDs to ignore

    Examples:
      elixir scripts/i18n_audit.exs
      elixir scripts/i18n_audit.exs --format markdown --limit 0
      elixir scripts/i18n_audit.exs --fail-on-findings
    """)
  end

  defp expand_paths([], include_tests) do
    @default_patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> filter_files(include_tests)
  end

  defp expand_paths(paths, include_tests) do
    paths
    |> Enum.flat_map(fn path ->
      cond do
        File.dir?(path) ->
          Enum.flat_map(@extensions, fn ext -> Path.wildcard(Path.join(path, "**/*#{ext}")) end)

        File.regular?(path) ->
          [path]

        true ->
          IO.puts(:stderr, "Skipping missing path: #{path}")
          []
      end
    end)
    |> filter_files(include_tests)
  end

  defp filter_files(files, include_tests) do
    files
    |> Enum.map(&Path.relative_to_cwd/1)
    |> Enum.reject(&excluded?(&1, include_tests))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp excluded?(path, include_tests) do
    excluded_segment? =
      Enum.any?(
        [
          "/_build/",
          "/deps/",
          "/node_modules/",
          "/priv/static/",
          "/priv/gettext/",
          "/assets/vendor/",
          "/assets/js/lib/i18n_catalog",
          "/lib/mix/tasks/"
        ],
        &String.contains?("/#{path}", &1)
      )

    test? =
      String.contains?(path, "/test/") or
        String.contains?(path, "/assets/test/") or
        String.starts_with?(path, "e2e/")

    excluded_segment? or (!include_tests and test?)
  end

  defp load_allowlist(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.split("#", parts: 2) |> hd() |> String.trim()))
      |> Enum.reject(&(&1 == ""))
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  defp scan_file(path) do
    source = File.read!(path)
    lines = String.split(source, "\n", trim: false)

    case Path.extname(path) do
      ".heex" -> scan_heex_lines(path, lines)
      ".js" -> scan_js_lines(path, lines)
      ext when ext in [".ex", ".exs"] -> scan_elixir_lines(path, lines)
      _ -> []
    end
  rescue
    e ->
      IO.puts(:stderr, "Could not scan #{path}: #{Exception.message(e)}")
      []
  end

  defp scan_heex_lines(path, lines) do
    {_state, findings} =
      Enum.reduce(Enum.with_index(lines, 1), {false, []}, fn {line, line_no},
                                                             {code_example?, acc} ->
        {skip_code_example?, next_code_example?} = code_example_state(line, code_example?)

        line_findings =
          if skip_code_example? do
            []
          else
            scan_heex_line(path, line, line_no)
          end

        {next_code_example?, acc ++ line_findings}
      end)

    findings
  end

  defp scan_elixir_lines(path, lines) do
    {_state, findings} =
      Enum.reduce(
        Enum.with_index(lines, 1),
        {%{doc: false, heex: false, code_example: false, gettext_depth: 0, logger_depth: 0}, []},
        fn {line, line_no}, {state, acc} ->
          {skip_doc?, doc_next} = doc_state(line, state.doc)
          {heex_now?, heex_next} = heex_state(line, state.heex)

          {skip_code_example?, code_example_next} =
            if heex_now? do
              code_example_state(line, state.code_example)
            else
              {false, false}
            end

          gettext_now? = state.gettext_depth > 0
          logger_now? = state.logger_depth > 0

          line_findings =
            cond do
              skip_doc? ->
                []

              skip_code_example? ->
                []

              heex_now? ->
                scan_heex_line(path, line, line_no)

              gettext_now? ->
                []

              logger_now? ->
                []

              true ->
                scan_elixir_literals(path, line, line_no)
            end

          gettext_next = gettext_state(line, state.gettext_depth)
          logger_next = logger_state(line, state.logger_depth)

          {%{
             doc: doc_next,
             heex: heex_next,
             code_example: code_example_next,
             gettext_depth: gettext_next,
             logger_depth: logger_next
           }, acc ++ line_findings}
        end
      )

    findings
  end

  defp doc_state(line, true) do
    {true, not String.contains?(line, ~s("""))}
  end

  defp doc_state(line, false) do
    starts_doc? = Regex.match?(~r/@(?:module)?doc\s+"""/, line)

    cond do
      starts_doc? ->
        triple_count = length(Regex.scan(~r/"""/, line))
        {true, triple_count == 1}

      Regex.match?(~r/@(?:module)?doc\s+(false|nil|".*")/, line) ->
        {true, false}

      true ->
        {false, false}
    end
  end

  defp heex_state(line, true) do
    {true, not String.contains?(line, ~s("""))}
  end

  defp heex_state(line, false) do
    cond do
      String.contains?(line, "~H\"\"\"") ->
        triple_count = length(Regex.scan(~r/"""/, line))
        {true, triple_count == 1}

      Regex.match?(~r/~H[|']/, line) ->
        {true, false}

      true ->
        {false, false}
    end
  end

  defp code_example_state(line, true) do
    {true, not String.contains?(line, "</.code_example>")}
  end

  defp code_example_state(line, false) do
    if String.contains?(line, "<.code_example") do
      {true, not String.contains?(line, "</.code_example>")}
    else
      {false, false}
    end
  end

  defp gettext_state(line, depth) do
    call_depth(line, depth, @gettext_call)
  end

  defp logger_state(line, depth) do
    call_depth(line, depth, @logger_call)
  end

  defp call_depth(line, depth, call_pattern) do
    code = Regex.replace(@double_string, line, ~s(""))

    cond do
      depth > 0 ->
        max(depth + paren_delta(code), 0)

      Regex.match?(call_pattern, code) ->
        max(paren_delta(code), 0)

      true ->
        0
    end
  end

  defp paren_delta(code) do
    opens = code |> String.graphemes() |> Enum.count(&(&1 == "("))
    closes = code |> String.graphemes() |> Enum.count(&(&1 == ")"))
    opens - closes
  end

  defp scan_heex_line(path, line, line_no) do
    if skip_heex_line?(line) do
      []
    else
      node_line = strip_heex_expressions(line)

      attr_findings =
        [@heex_attr_double, @heex_attr_single, @heex_attr_braced_double, @heex_attr_braced_single]
        |> Enum.flat_map(fn regex ->
          Regex.scan(regex, line, capture: ["attr", "text"])
          |> Enum.map(fn [attr, text] ->
            build_finding(path, line_no, "heex_attr:#{attr}", :high, text, line)
          end)
        end)

      node_findings =
        Regex.scan(@heex_text_node, node_line, capture: :all_but_first)
        |> Enum.map(fn [text] ->
          build_finding(path, line_no, "heex_text", :high, text, line)
        end)

      standalone_findings =
        case standalone_heex_text(node_line) do
          nil -> []
          text -> [build_finding(path, line_no, "heex_text", :high, text, line)]
        end

      (attr_findings ++ node_findings ++ standalone_findings)
      |> Enum.filter(&translatable?/1)
    end
  end

  defp strip_heex_expressions(line), do: strip_heex_expressions(line, "")

  defp strip_heex_expressions("", acc), do: acc

  defp strip_heex_expressions("{" <> rest, acc) do
    {_expr, remaining} = take_heex_expr(rest, 1)
    strip_heex_expressions(remaining, acc <> "{}")
  end

  defp strip_heex_expressions(<<char::utf8, rest::binary>>, acc) do
    strip_heex_expressions(rest, acc <> <<char::utf8>>)
  end

  defp take_heex_expr("", _depth), do: {"", ""}
  defp take_heex_expr(<<"\"", rest::binary>>, depth), do: take_heex_expr_string(rest, depth, "\"")
  defp take_heex_expr(<<"'", rest::binary>>, depth), do: take_heex_expr_string(rest, depth, "'")

  defp take_heex_expr(<<"{", rest::binary>>, depth) do
    {_expr, remaining} = take_heex_expr(rest, depth + 1)
    take_heex_expr(remaining, depth)
  end

  defp take_heex_expr(<<"}", rest::binary>>, 1), do: {"", rest}
  defp take_heex_expr(<<"}", rest::binary>>, depth), do: take_heex_expr(rest, depth - 1)
  defp take_heex_expr(<<_char::utf8, rest::binary>>, depth), do: take_heex_expr(rest, depth)

  defp take_heex_expr_string("", _depth, _quote), do: {"", ""}

  defp take_heex_expr_string(<<?\\, _char::utf8, rest::binary>>, depth, quote),
    do: take_heex_expr_string(rest, depth, quote)

  defp take_heex_expr_string(source, depth, quote) do
    quote_size = byte_size(quote)

    if String.starts_with?(source, quote) do
      <<_::binary-size(quote_size), rest::binary>> = source
      take_heex_expr(rest, depth)
    else
      <<_char::utf8, rest::binary>> = source
      take_heex_expr_string(rest, depth, quote)
    end
  end

  defp skip_heex_line?(line) do
    trimmed = String.trim(line)

    trimmed == "" or
      String.contains?(trimmed, "~H\"\"\"") or
      String.starts_with?(trimmed, "<%!--") or
      String.starts_with?(trimmed, "<!--") or
      Regex.match?(
        ~r/^<\/?(svg|path|rect|circle|ellipse|line|polyline|polygon|g|defs|clipPath|linearGradient|stop)\b/,
        trimmed
      )
  end

  defp standalone_heex_text(line) do
    trimmed =
      line
      |> String.replace(~r/<%=?[^%]*%>/, "")
      |> String.trim()

    cleaned =
      trimmed
      |> String.trim_trailing(",")
      |> String.trim("\"'")

    cond do
      trimmed == "" -> nil
      String.starts_with?(trimmed, ["<", "{", "}", "[", "]", "(", ":", ".", "#", "=", "|"]) -> nil
      String.starts_with?(trimmed, ["@", "do:", "else:", "true ->", "false ->"]) -> nil
      String.starts_with?(trimmed, ["\"", "'"]) -> nil
      String.contains?(trimmed, ["{", "}"]) -> nil
      String.contains?(trimmed, ["=", "->", "<.", "</", "/>", "@"]) -> nil
      String.contains?(trimmed, ["||", "&&"]) -> nil
      String.ends_with?(trimmed, [",", "(", "["]) -> nil
      Regex.match?(~r/^[a-z_]+:\s*/u, trimmed) -> nil
      Regex.match?(~r/^[A-Za-z_][\w.?!]*\(/u, trimmed) -> nil
      Regex.match?(~r/^(cond|case|fn|else|end)\b/u, trimmed) -> nil
      css_class_list?(cleaned) -> nil
      not Regex.match?(~r/[[:alpha:]]/u, trimmed) -> nil
      true -> trimmed
    end
  end

  defp scan_elixir_literals(path, line, line_no) do
    trimmed = String.trim_leading(line)

    cond do
      trimmed == "" or String.starts_with?(trimmed, "#") ->
        []

      String.contains?(line, [
        "gettext(",
        "dgettext(",
        "ngettext(",
        "dngettext(",
        "pgettext(",
        "dpgettext(",
        "gettext_noop(",
        "dgettext_noop(",
        "ngettext_noop(",
        "dngettext_noop(",
        "pgettext_noop(",
        "dpgettext_noop("
      ]) ->
        []

      String.contains?(line, ["use Gettext", "Logger.", "@doc", "doc:"]) ->
        []

      String.contains?(line, ["Calendar.strftime", "~s("]) ->
        []

      Regex.match?(~r/^defp\s+translate_[a-z_]+\("/u, trimmed) ->
        []

      true ->
        @double_string
        |> Regex.scan(line, return: :index)
        |> Enum.map(fn [{start, len}] ->
          raw = binary_part(line, start, len)
          text = unquote_string(raw)
          prefix = binary_part(line, 0, start)
          severity = elixir_severity(line)

          if skip_literal_context?(prefix, text) do
            nil
          else
            build_finding(path, line_no, "elixir_literal", severity, text, line)
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&translatable?/1)
    end
  end

  defp elixir_severity(line) do
    if Regex.match?(
         ~r/(put_flash|content:|message:|error:|title:|label:|description:|placeholder|page_title|reason_label|session_ended_label|sender_nick|text:)/,
         line
       ) do
      :high
    else
      :medium
    end
  end

  defp scan_js_lines(path, lines) do
    {_state, findings} =
      Enum.reduce(
        Enum.with_index(lines, 1),
        {%{block_comment: false, i18n_depth: 0}, []},
        fn {line, line_no}, {state, acc} ->
          {code, next_block?} = strip_js_comments(line, state.block_comment)
          i18n_now? = state.i18n_depth > 0

          line_findings =
            cond do
              String.trim(code) == "" -> []
              i18n_now? -> []
              true -> scan_js_literals(path, code, line_no)
            end

          next_i18n_depth = js_i18n_state(code, state.i18n_depth)

          {%{block_comment: next_block?, i18n_depth: next_i18n_depth}, acc ++ line_findings}
        end
      )

    findings
  end

  defp js_i18n_state(line, depth) do
    call_depth(line, depth, @js_i18n_call)
  end

  defp strip_js_comments(line, true) do
    # Keep the implementation conservative: when inside a block comment, skip
    # until the terminator and resume on the following line.
    {"", not String.contains?(line, "*/")}
  end

  defp strip_js_comments(line, false) do
    trimmed = String.trim_leading(line)

    cond do
      String.starts_with?(trimmed, "/*") ->
        {"", not String.contains?(trimmed, "*/")}

      String.starts_with?(trimmed, "//") ->
        {"", false}

      String.contains?(line, "/*") ->
        [before | _] = String.split(line, "/*", parts: 2)
        {before, not String.contains?(line, "*/")}

      String.contains?(line, "//") ->
        [before | _] = String.split(line, "//", parts: 2)
        {before, false}

      true ->
        {line, false}
    end
  end

  defp scan_js_literals(path, line, line_no) do
    trimmed = String.trim_leading(line)

    cond do
      Regex.match?(~r/^(import|export)\b/, trimmed) ->
        []

      String.contains?(line, ["console.", "case \"", "case '", "case `"]) ->
        []

      true ->
        @js_string
        |> Regex.scan(line, return: :index)
        |> Enum.map(fn [{start, len}] ->
          raw = binary_part(line, start, len)
          text = unquote_string(raw)
          prefix = binary_part(line, 0, start)

          cond do
            skip_literal_context?(prefix, text) ->
              nil

            js_i18n_call?(prefix) ->
              nil

            true ->
              build_finding(path, line_no, "js_literal", js_severity(prefix, line), text, line)
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&translatable?/1)
    end
  end

  defp js_i18n_call?(prefix) do
    Regex.match?(~r/\b(?:t|tn|gettext|ngettext)\s*\(\s*$/u, prefix) or
      Regex.match?(~r/\b(?:jt|gettextTemplate)\s*$/u, prefix)
  end

  defp js_severity(prefix, line) do
    explicit? =
      Regex.match?(
        ~r/(textContent|innerText|innerHTML|ariaLabel|placeholder|title)\s*=\s*$/,
        prefix
      ) or
        Regex.match?(
          ~r/(message|error|reason|label|description|title|text|content)\s*:\s*$/,
          prefix
        ) or
        Regex.match?(
          ~r/setAttribute\(\s*["'](?:aria-label|title|alt|placeholder)["']\s*,\s*$/,
          prefix
        )

    cond do
      explicit? -> :high
      String.contains?(line, ["pushEvent", "dispatchEvent", "CustomEvent"]) -> :medium
      true -> :medium
    end
  end

  defp skip_literal_context?(prefix, text) do
    cleaned = cleanup_text(text)

    Regex.match?(@skip_key, prefix) or
      Regex.match?(~r/^\s*\{:error,\s*$/u, prefix) or
      Regex.match?(~r/(==|!=)\s*$/u, prefix) or
      Regex.match?(~r/(~p|push_navigate|redirect)\s*$/u, prefix) or
      Regex.match?(~r/\bfrom\s*$/u, prefix) or
      Regex.match?(
        ~r/\b(?:querySelector|querySelectorAll|closest|matches|getElementById|getElementsByClassName|getElementsByTagName|createElement|matchMedia)\(\s*$/u,
        prefix
      ) or
      Regex.match?(~r/\bwindow\.open\(\s*[^,]+,\s*$/u, prefix) or
      Regex.match?(~r/\bwindow\.open\(\s*[^,]+,\s*[^,]+,\s*$/u, prefix) or
      Regex.match?(~r/\b(?:live|get|post|put|patch|delete|scope|forward)\s*$/u, prefix) or
      Regex.match?(~r/(fragment|~r)\(\s*$/u, prefix) or
      Regex.match?(~r/~r\s*$/u, prefix) or
      Regex.match?(~r/^\s*@[a-z0-9_]*_path\s*$/u, prefix) or
      Regex.match?(~r/(?:\.|^)(?:id|className|dataset\.[A-Za-z0-9_]+)\s*=\s*$/u, prefix) or
      Regex.match?(
        ~r/(?:\.|^)(?:font|fillStyle|strokeStyle|shadowColor|globalCompositeOperation)\s*=\s*$/u,
        prefix
      ) or
      Regex.match?(
        ~r/\b(?:addColorStop|getPropertyValue|includes|startsWith|endsWith|match)\(\s*$/u,
        prefix
      ) or
      Regex.match?(~r/\breplace\([^,]+,\s*$/u, prefix) or
      Regex.match?(~r/\b(?:Error|TypeError|RangeError)\(\s*$/u, prefix) or
      Regex.match?(~r/\btrackEvent\(\s*$/u, prefix) or
      Regex.match?(~r/\blocation\.(?:href|assign|replace)\s*=\s*$/u, prefix) or
      Regex.match?(~r/Calendar\.strftime\(\s*$/u, prefix) or
      Regex.match?(
        ~r/Logger\.(?:debug|info|notice|warning|error|critical|alert|emergency)\(\s*$/u,
        prefix
      ) or
      Regex.match?(~r/EmojiData\.by_category\(\s*$/u, prefix) or
      looks_like_code?(cleaned) or
      (Regex.match?(~r/^[a-z0-9_:-]+$/u, cleaned) and cleaned not in @short_ui_words)
  end

  defp build_finding(path, line, kind, severity, text, context) do
    text = cleanup_text(text)
    context = String.trim(context)

    %{
      id: finding_id(path, line, kind, text, context),
      path: path,
      line: line,
      kind: kind,
      severity: severity,
      text: text,
      context: context,
      fix: fix_hint(kind, text)
    }
  end

  defp translatable?(%{text: text, kind: kind}) do
    explicit? = String.starts_with?(kind, "heex_attr") or kind == "js_literal"

    cond do
      text == "" -> false
      String.length(text) < 2 -> false
      not Regex.match?(~r/[[:alpha:]]/u, text) -> false
      looks_like_code?(text) -> false
      explicit? and String.downcase(text) in @short_ui_words -> true
      Regex.match?(~r/[\s.!?,'"():;%{}]/u, text) -> true
      Regex.match?(~r/^[A-Z][[:alpha:]'-]+$/u, text) -> true
      true -> false
    end
  end

  defp looks_like_code?(text) do
    cond do
      text == "" ->
        true

      text == "RetroHexChat" ->
        true

      text in ["ChanServ", "NickServ"] ->
        true

      Regex.match?(~r/^#[0-9a-fA-F]{3,8}$/, text) ->
        true

      Regex.match?(~r/^&(?:gt|lt|amp|quot|apos|nbsp|times);$/u, text) ->
        true

      Regex.match?(~r/^&(lt|gt|amp);/u, text) ->
        true

      Regex.match?(~r/^\/?&gt;$/u, text) ->
        true

      Regex.match?(~r/^(?:\\u\{[0-9a-fA-F]+\})+$/u, text) ->
        true

      Regex.match?(~r/^v?\d+\.\d+(?:\.\d+)?(?:[-+][a-z0-9.-]+)?$/iu, text) ->
        true

      Regex.match?(~r/^\d{4}&(?:ndash|mdash);\d{4}$/u, text) ->
        true

      Regex.match?(~r/^\d+(\.\d+)?(px|rem|em|s|ms|%)?$/, text) ->
        true

      Regex.match?(~r/^\d+\s+(?:millisecond|milliseconds|second|seconds)$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}[a-z]+$/, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}$/, text) ->
        true

      Regex.match?(~r/^[+-]#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}!\*@\*$/u, text) ->
        true

      Regex.match?(~r/^%\{#\{[^}]+\}\}$/, text) ->
        true

      Regex.match?(~r/^%\{\\w\+\}$/u, text) ->
        true

      Regex.match?(~r/^%\{\(\\w\+\)\}$/u, text) ->
        true

      Regex.match?(~r/^\{#\{[^}]+\}\}$/u, text) ->
        true

      Regex.match?(~r/^\$#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^\^#\{[^}]+\}\$$/u, text) ->
        true

      Regex.match?(~r/^%#\{[^}]+\}%$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}(?:[-_:\/]#\{[^}]+\})+$/u, text) ->
        true

      Regex.match?(~r/^(?:user|channel|pm|game|p2p|arcade):#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^pending_#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^[a-z0-9_:-]+_#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^Guest_#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^cmd-#\{/u, text) ->
        true

      Regex.match?(~r/^\/[a-z0-9_\/?=&-]*#\{[^}]+\}$/u, text) ->
        true

      String.contains?(text, ["\#{params[", "token=\#{"]) ->
        true

      String.contains?(text, ["arcade_base_url()", "&#123;", "&#125;"]) ->
        true

      String.contains?(text, ["(?<!", "(?!", "\\w"]) and String.contains?(text, "#\{") ->
        true

      Regex.match?(~r/^#\{[^}]+\}-[a-z0-9_-]+-#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}-[a-z]+$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}\s+#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^[a-z0-9_-]+(?:\s+[a-z0-9_-]+--#\{[^}]+\})+$/u, text) ->
        true

      Regex.match?(~r/^#\{[^}]+\}[:;,\s-]+#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^[a-z][a-z0-9_-]*-\#\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD|UTC|SHA-256)$/i, text) ->
        true

      String.contains?(text, "toggle group must be") ->
        true

      Regex.match?(
        ~r/^(Escape|Enter|Tab|ArrowUp|ArrowDown|ArrowLeft|ArrowRight|Home|End)$/u,
        text
      ) ->
        true

      Regex.match?(~r/^[a-z]+\/[a-z0-9+.-]+$/i, text) ->
        true

      text
      |> String.replace(~r/\$\{[^}]+\}/u, "")
      |> String.match?(~r/^[^[:alpha:]]*$/u) ->
        true

      Regex.match?(~r/^[PRx]\$\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^\$\{[^}]+\}x\$\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^(?:Android|iOS|macOS)\s+\$\{[^}]+\}$/u, text) ->
        true

      Regex.match?(~r/^(?:Android|iOS|macOS|Windows)(?:\s+[A-Za-z0-9_.+()-]+)*$/u, text) ->
        true

      Regex.match?(~r/^rgba?\([^)]+\)$/iu, text) ->
        true

      Regex.match?(~r/^hsla?\([^)]+\)$/iu, text) ->
        true

      Regex.match?(~r/^(?:bold\s+)?\$\{[^}]+\}px\s+(?:monospace|sans-serif|serif)$/iu, text) ->
        true

      Regex.match?(
        ~r/^(?:bold\s+)?\d+(?:\.\d+)?px\s+(?:monospace|sans-serif|serif)$/iu,
        text
      ) ->
        true

      Regex.match?(~r/^[\w.-]+\.(js|css|png|jpg|jpeg|gif|svg|ico|ex|exs|heex|json|txt)$/i, text) ->
        true

      Regex.match?(~r/^[\w.-]+\.[a-z]{2,}$/iu, text) ->
        true

      Regex.match?(~r/^https?:\/\//, text) ->
        true

      String.starts_with?(text, "/g, ") ->
        true

      Regex.match?(~r/^\.\.?\//, text) ->
        true

      Regex.match?(
        ~r/^[.#]?[a-z0-9_-]+(?:\[[^\]]+\])?(?:\s*,\s*[.#]?[a-z0-9_-]+(?:\[[^\]]+\])?)*$/iu,
        text
      ) ->
        true

      Regex.match?(~r/^\$\{[A-Za-z_$][\w$]*\}[A-Za-z_$][\w$]*$/u, text) ->
        true

      Regex.match?(~r/^[A-Za-z_$][\w$]*\$\{[^}]+\}[A-Za-z_$][\w$]*$/u, text) ->
        true

      Regex.match?(~r/^\$\{[A-Za-z_$][\w$]*\}(?:[:._-]\$\{?[A-Za-z_$][\w$]*\}?)*$/u, text) ->
        true

      Regex.match?(~r/^\$\{[^}]+\}(?:[:\/.-]\$\{[^}]+\})+$/u, text) ->
        true

      Regex.match?(~r/^\$\{[^}]+\}[%a-zA-Z\/:.\s-]*$/u, text) and
          Regex.match?(~r/^(?:\$\{[^}]+\}|[:\/.\s%a-zA-Z-])+$/u, text) ->
        true

      Regex.match?(~r/^[.#]?[a-z0-9_-]+$/u, text) and String.downcase(text) == text ->
        true

      Regex.match?(~r/^[a-z0-9_:-]+$/u, text) and String.downcase(text) == text ->
        true

      Regex.match?(~r/^[a-z-]+:\s*[^;]+;(?:\s*[a-z-]+:\s*[^;]+;)+$/u, text) ->
        true

      css_class_list?(text) ->
        true

      String.contains?(text, "[&>") ->
        true

      true ->
        false
    end
  end

  defp css_class_list?(text) do
    tokens = String.split(text)

    length(tokens) > 1 and
      Enum.all?(tokens, fn token ->
        Regex.match?(
          ~r/^!?-?(?:[a-z]+:)*[a-z0-9_#\[\]&><\/%.:-]+$/i,
          token
        ) and
          Regex.match?(
            ~r/^(?:[a-z]+:)*-?(flex|grid|block|inline|hidden|fixed|absolute|relative|sticky|inset|top|bottom|left|right|translate|transition|ease|slide|text|bg|border|rounded|shadow|ring|underline|italic|p|m|mt|mb|ml|mr|mx|my|pt|pb|pl|pr|px|py|w|h|min|max|items|justify|content|gap|space|overflow|z|opacity|font|leading|tracking|select|cursor|resize|sr|focus|hover|active|disabled)/,
            token
          )
      end)
  end

  defp cleanup_text(text) do
    text
    |> String.trim()
    |> String.trim("\"'")
    |> String.replace(~r/\s+/u, " ")
    |> String.replace("\\n", " ")
    |> String.replace("\\\"", "\"")
    |> String.replace("\\'", "'")
  end

  defp unquote_string(raw) do
    raw
    |> String.slice(1, String.length(raw) - 2)
    |> cleanup_text()
  end

  defp finding_id(path, line, kind, text, context) do
    payload = "#{path}:#{line}:#{kind}:#{text}:#{context}"

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp fix_hint("heex_text", _text),
    do: "Wrap the text with {gettext(\"...\")} or move it into a translated component attr."

  defp fix_hint("elixir_literal", text) do
    if String.contains?(text, "\#{") do
      "Use gettext with named bindings, e.g. gettext(\"...%{name}...\", name: value)."
    else
      "Wrap with gettext(\"...\") or dgettext(domain, \"...\") if this belongs to a domain."
    end
  end

  defp fix_hint("js_literal", _text),
    do: "Pass translated text from HEEx/data attributes or read it from a JS i18n dictionary."

  defp fix_hint(kind, _text) when is_binary(kind),
    do: "Use gettext/dgettext/ngettext as appropriate."

  defp maybe_drop_low(findings, true), do: findings
  defp maybe_drop_low(findings, false), do: Enum.reject(findings, &(&1.severity == :low))

  defp counts(findings) do
    %{
      total: length(findings),
      high: Enum.count(findings, &(&1.severity == :high)),
      medium: Enum.count(findings, &(&1.severity == :medium)),
      low: Enum.count(findings, &(&1.severity == :low))
    }
  end

  defp severity_rank(:high), do: 0
  defp severity_rank(:medium), do: 1
  defp severity_rank(:low), do: 2

  defp print_report(report, opts) do
    case opts[:format] do
      "text" -> print_text(report, opts)
      "markdown" -> print_markdown(report, opts)
      "json" -> IO.puts(json(report))
    end
  end

  defp print_text(report, opts) do
    counts = report.counts

    IO.puts("I18n audit")
    IO.puts("Scanned files: #{report.scanned_files}")

    IO.puts(
      "Findings: #{counts.total} high=#{counts.high} medium=#{counts.medium} low=#{counts.low}"
    )

    IO.puts("Allowlist: #{report.allowlist_path}")
    IO.puts("")

    print_top_files(report.findings)

    report.findings
    |> limited(opts[:limit])
    |> Enum.each(fn finding ->
      IO.puts(
        "[#{finding.severity}] #{finding.id} #{finding.path}:#{finding.line} #{finding.kind}"
      )

      IO.puts("  text: #{finding.text}")
      IO.puts("  context: #{finding.context}")
      IO.puts("  fix: #{finding.fix}")
      IO.puts("")
    end)

    print_omitted(report.findings, opts[:limit])
  end

  defp print_markdown(report, opts) do
    counts = report.counts

    IO.puts("# I18n audit")
    IO.puts("")
    IO.puts("- Scanned files: #{report.scanned_files}")
    IO.puts("- Findings: #{counts.total}")
    IO.puts("- High: #{counts.high}")
    IO.puts("- Medium: #{counts.medium}")
    IO.puts("- Low: #{counts.low}")
    IO.puts("- Allowlist: `#{report.allowlist_path}`")
    IO.puts("")

    if report.findings != [] do
      IO.puts("## Top files")
      IO.puts("")

      report.findings
      |> top_files()
      |> Enum.each(fn {path, count} -> IO.puts("- `#{path}`: #{count}") end)

      IO.puts("")
    end

    IO.puts("| Severity | ID | Location | Kind | Text |")
    IO.puts("| --- | --- | --- | --- | --- |")

    report.findings
    |> limited(opts[:limit])
    |> Enum.each(fn finding ->
      IO.puts(
        "| #{finding.severity} | `#{finding.id}` | `#{finding.path}:#{finding.line}` | `#{finding.kind}` | #{escape_md(finding.text)} |"
      )
    end)

    omitted = omitted_count(report.findings, opts[:limit])

    if omitted > 0 do
      IO.puts("")
      IO.puts("_#{omitted} findings omitted. Use `--limit 0` to print all._")
    end
  end

  defp limited(findings, 0), do: findings
  defp limited(findings, limit), do: Enum.take(findings, limit)

  defp omitted_count(_findings, 0), do: 0
  defp omitted_count(findings, limit), do: max(length(findings) - limit, 0)

  defp print_omitted(findings, limit) do
    omitted = omitted_count(findings, limit)

    if omitted > 0 do
      IO.puts("#{omitted} more findings omitted. Use --limit 0 to print all.")
    end
  end

  defp print_top_files([]), do: :ok

  defp print_top_files(findings) do
    IO.puts("Top files:")

    findings
    |> top_files()
    |> Enum.each(fn {path, count} -> IO.puts("  #{count} #{path}") end)

    IO.puts("")
  end

  defp top_files(findings) do
    findings
    |> Enum.group_by(& &1.path)
    |> Enum.map(fn {path, entries} -> {path, length(entries)} end)
    |> Enum.sort_by(fn {path, count} -> {-count, path} end)
    |> Enum.take(8)
  end

  defp escape_md(text) do
    text
    |> String.replace("|", "\\|")
    |> String.replace("\n", " ")
  end

  defp json(value) when is_map(value) do
    entries =
      value
      |> Enum.map(fn {key, val} -> "#{json(to_string(key))}:#{json(val)}" end)
      |> Enum.join(",")

    "{#{entries}}"
  end

  defp json(value) when is_list(value) do
    "[" <> Enum.map_join(value, ",", &json/1) <> "]"
  end

  defp json(value) when is_integer(value), do: Integer.to_string(value)
  defp json(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp json(value) when is_atom(value), do: json(to_string(value))
  defp json(nil), do: "null"

  defp json(value) when is_binary(value) do
    escaped =
      value
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")
      |> String.replace("\r", "\\r")
      |> String.replace("\t", "\\t")

    "\"#{escaped}\""
  end
end

I18nAudit.main(System.argv())
