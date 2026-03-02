defmodule Mix.Tasks.Lint.CssConsistencyTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Lint.CssConsistency

  @moduletag :unit

  describe "extract_classes_from_css/2" do
    test "extracts simple class selectors" do
      css = ".foo { color: red; }\n.bar { display: none; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "foo" in classes
      assert "bar" in classes
    end

    test "extracts compound selectors" do
      css = ".parent .child { margin: 0; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "parent" in classes
      assert "child" in classes
    end

    test "extracts BEM-style modifier selectors" do
      css = ".block--modifier { padding: 0; }\n.block__element { margin: 0; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "block--modifier" in classes
      assert "block__element" in classes
    end

    test "ignores classes inside CSS comments" do
      css = "/* .commented-out { display: none; } */\n.real { color: blue; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "real" in classes
      refute "commented-out" in classes
    end

    test "ignores @import lines" do
      css = "@import \"./other.css\";\n.actual { padding: 4px; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "actual" in classes
    end

    test "handles pseudo-class selectors" do
      css = ".btn:hover { color: blue; }\n.link:focus { outline: 1px; }"
      result = CssConsistency.extract_classes_from_css(css, "test.css")
      classes = Enum.map(result, &elem(&1, 0))
      assert "btn" in classes
      assert "link" in classes
    end

    test "tracks source file" do
      css = ".widget { display: flex; }"
      result = CssConsistency.extract_classes_from_css(css, "components.css")
      assert {"widget", "components.css"} in result
    end
  end

  describe "extract_refs_from_template/1" do
    test "extracts static class attributes" do
      file = write_temp_file(~s|<div class="foo bar">hello</div>|)
      refs = CssConsistency.extract_refs_from_template(file)
      assert "foo" in refs
      assert "bar" in refs
    end

    test "extracts dynamic brace classes" do
      file = write_temp_file(~s|<div class={"alpha beta"}>test</div>|)
      refs = CssConsistency.extract_refs_from_template(file)
      assert "alpha" in refs
      assert "beta" in refs
    end

    test "extracts literal part from interpolated expressions" do
      content = ~S|<div class={"base-class#{if @active, do: " active", else: ""}"}></div>|
      file = write_temp_file(content)
      refs = CssConsistency.extract_refs_from_template(file)
      assert "base-class" in refs
    end

    test "extracts classes from _class helper functions" do
      content = """
      defp tab_class(active) do
        base = "tab-item"
        if active, do: "tab-item tab-active", else: base
      end
      """

      file = write_temp_file(content)
      refs = CssConsistency.extract_refs_from_template(file)
      assert "tab-item" in refs
      assert "tab-active" in refs
    end
  end

  describe "extract_refs_from_js/1" do
    test "extracts classList.add references" do
      file = write_temp_file_js(~s|el.classList.add("focused");|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "focused" in refs
    end

    test "extracts classList.remove references" do
      file = write_temp_file_js(~s|el.classList.remove("active");|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "active" in refs
    end

    test "extracts classList.toggle references" do
      file = write_temp_file_js(~s|el.classList.toggle("visible");|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "visible" in refs
    end

    test "extracts classList.contains references" do
      file = write_temp_file_js(~s|if (el.classList.contains("hidden")) {}|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "hidden" in refs
    end

    test "extracts querySelector class references" do
      file = write_temp_file_js(~s|document.querySelector(".chat-input");|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "chat-input" in refs
    end

    test "extracts querySelectorAll class references" do
      file = write_temp_file_js(~s|el.querySelectorAll(".search-highlight");|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "search-highlight" in refs
    end

    test "extracts className assignment" do
      file = write_temp_file_js(~s|el.className = "search-highlight";|)
      refs = CssConsistency.extract_refs_from_js(file)
      assert "search-highlight" in refs
    end
  end

  describe "parse_allowlist/1" do
    test "parses sections correctly" do
      content = """
      [unused]
      dead-class
      old-widget-*

      [missing]
      dynamic-thing

      [dynamic-prefixes]
      chat-message--
      """

      {unused, missing, dynamic} = CssConsistency.parse_allowlist(content)
      assert MapSet.member?(unused, "dead-class")
      assert MapSet.member?(unused, "old-widget-*")
      assert MapSet.member?(missing, "dynamic-thing")
      assert "chat-message--" in dynamic
    end

    test "ignores comments and blank lines" do
      content = """
      [unused]
      # This is a comment
      real-entry

      [missing]
      """

      {unused, missing, _dynamic} = CssConsistency.parse_allowlist(content)
      assert MapSet.size(unused) == 1
      assert MapSet.member?(unused, "real-entry")
      assert MapSet.size(missing) == 0
    end

    test "handles empty content" do
      {unused, missing, dynamic} = CssConsistency.parse_allowlist("")
      assert MapSet.size(unused) == 0
      assert MapSet.size(missing) == 0
      assert dynamic == []
    end
  end

  describe "filter_by_allowlist/3" do
    test "removes exact matches" do
      classes = MapSet.new(["foo", "bar", "baz"])
      allow = MapSet.new(["bar"])
      result = CssConsistency.filter_by_allowlist(classes, allow, [])
      assert MapSet.equal?(result, MapSet.new(["foo", "baz"]))
    end

    test "removes glob pattern matches" do
      classes = MapSet.new(["irc-fg-0", "irc-fg-15", "other"])
      allow = MapSet.new(["irc-fg-*"])
      result = CssConsistency.filter_by_allowlist(classes, allow, [])
      assert MapSet.equal?(result, MapSet.new(["other"]))
    end

    test "removes dynamic prefix matches" do
      classes = MapSet.new(["chat-message--action", "chat-message--notice", "other"])
      result = CssConsistency.filter_by_allowlist(classes, MapSet.new(), ["chat-message--"])
      assert MapSet.equal?(result, MapSet.new(["other"]))
    end
  end

  describe "extract_brace_exprs/2" do
    test "extracts simple brace expression" do
      content = ~s|class={"foo bar"}|
      result = CssConsistency.extract_brace_exprs(content, "class={")
      assert [~s|"foo bar"|] = result
    end

    test "handles nested braces from interpolation" do
      content = ~S|class={"base#{if true, do: " active", else: ""}"}|
      result = CssConsistency.extract_brace_exprs(content, "class={")
      assert length(result) == 1
    end
  end

  describe "end-to-end on actual codebase" do
    test "extract_defined_classes returns a set" do
      defined = CssConsistency.extract_defined_classes()
      assert is_struct(defined, MapSet)
    end

    test "extract_vendor_classes returns a set (may be empty without retro CSS)" do
      vendor = CssConsistency.extract_vendor_classes()
      assert is_struct(vendor, MapSet)
    end

    test "extract_all_references returns a non-empty set" do
      refs = CssConsistency.extract_all_references()
      assert MapSet.size(refs) > 0
    end
  end

  defp write_temp_file(content) do
    path = Path.join(System.tmp_dir!(), "css_lint_test_#{:rand.uniform(1_000_000)}.ex")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp write_temp_file_js(content) do
    path = Path.join(System.tmp_dir!(), "css_lint_test_#{:rand.uniform(1_000_000)}.js")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
