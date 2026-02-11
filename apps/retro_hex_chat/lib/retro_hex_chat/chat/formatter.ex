defmodule RetroHexChat.Chat.Formatter do
  @moduledoc """
  Parses mIRC format control codes and produces safe HTML or plain text.

  ## Control Codes

  - 0x02 — Bold (toggle)
  - 0x03 — Color (followed by optional fg[,bg] numbers 0-15)
  - 0x0F — Reset (clears all formatting)
  - 0x16 — Reverse (toggle fg/bg swap)
  - 0x1D — Italic (toggle)
  - 0x1E — Strikethrough (toggle)
  - 0x1F — Underline (toggle)
  """

  @type safe_html :: {:safe, String.t()}

  @default_max_codes 128

  @bold 0x02
  @color 0x03
  @reset 0x0F
  @reverse 0x16
  @italic 0x1D
  @strikethrough 0x1E
  @underline 0x1F

  defp initial_state do
    %{
      bold: false,
      italic: false,
      underline: false,
      strikethrough: false,
      reverse: false,
      fg_color: nil,
      bg_color: nil
    }
  end

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Parses mIRC format control codes and returns Phoenix HTML-safe output.

  All user text is HTML-escaped before wrapping in `<span>` elements.
  Only `<span>` elements with `class` attributes are generated.

  ## Options

  - `:max_codes` — Maximum format codes to process (default: 128).
    Excess codes are stripped at display time.
  """
  @spec to_safe_html(String.t(), keyword()) :: safe_html()
  def to_safe_html(content, opts \\ [])

  def to_safe_html("", _opts), do: {:safe, ""}

  def to_safe_html(content, opts) do
    max_codes = Keyword.get(opts, :max_codes, @default_max_codes)
    tokens = tokenize(content)
    tokens = enforce_code_limit(tokens, max_codes)
    html = render_tokens(tokens, initial_state(), [])
    {:safe, html}
  end

  @doc """
  Removes all mIRC format control codes, returning plain text only.
  Color code digits and commas following 0x03 are also removed.
  """
  @spec strip(String.t()) :: String.t()
  def strip(""), do: ""

  def strip(content) do
    content
    |> tokenize()
    |> Enum.reduce([], fn
      {:text, text}, acc -> [text | acc]
      _code, acc -> acc
    end)
    |> Enum.reverse()
    |> Enum.join()
  end

  @doc """
  Alias for `strip/1`. Returns only visible text. Used for validation.
  """
  @spec visible_text(String.t()) :: String.t()
  def visible_text(content), do: strip(content)

  @doc """
  Returns true if content has at least one non-whitespace visible character
  after stripping all format codes.
  """
  @spec has_visible_text?(String.t()) :: boolean()
  def has_visible_text?(content) do
    content
    |> strip()
    |> String.trim()
    |> byte_size()
    |> Kernel.>(0)
  end

  @doc """
  Counts the number of format control codes in the content.
  """
  @spec count_codes(String.t()) :: non_neg_integer()
  def count_codes(""), do: 0

  def count_codes(content) do
    content
    |> tokenize()
    |> Enum.count(fn
      {:text, _} -> false
      _ -> true
    end)
  end

  # ── Tokenizer ────────────────────────────────────────────────────────

  defp tokenize(content) do
    tokenize(content, [])
  end

  defp tokenize(<<>>, acc) do
    Enum.reverse(acc)
  end

  defp tokenize(<<@bold, rest::binary>>, acc) do
    tokenize(rest, [{:bold} | acc])
  end

  defp tokenize(<<@italic, rest::binary>>, acc) do
    tokenize(rest, [{:italic} | acc])
  end

  defp tokenize(<<@underline, rest::binary>>, acc) do
    tokenize(rest, [{:underline} | acc])
  end

  defp tokenize(<<@strikethrough, rest::binary>>, acc) do
    tokenize(rest, [{:strikethrough} | acc])
  end

  defp tokenize(<<@reverse, rest::binary>>, acc) do
    tokenize(rest, [{:reverse} | acc])
  end

  defp tokenize(<<@reset, rest::binary>>, acc) do
    tokenize(rest, [{:reset} | acc])
  end

  defp tokenize(<<@color, rest::binary>>, acc) do
    case parse_color_args(rest) do
      {:ok, fg, bg, remaining} ->
        tokenize(remaining, [{:color, fg, bg} | acc])

      :no_color ->
        # Bare color code = color reset
        tokenize(rest, [{:color_reset} | acc])
    end
  end

  defp tokenize(<<char::utf8, rest::binary>>, [{:text, text} | acc]) do
    tokenize(rest, [{:text, text <> <<char::utf8>>} | acc])
  end

  defp tokenize(<<char::utf8, rest::binary>>, acc) do
    tokenize(rest, [{:text, <<char::utf8>>} | acc])
  end

  # ── Color argument parser ────────────────────────────────────────────

  defp parse_color_args(binary) do
    case read_color_number(binary) do
      {nil, _rest} ->
        :no_color

      {fg, rest} ->
        parse_optional_bg(fg, rest)
    end
  end

  defp parse_optional_bg(fg, <<",", rest::binary>>) do
    case read_color_number(rest) do
      {nil, _} ->
        # Comma but no valid bg number — treat as fg only, don't consume comma
        {:ok, fg, nil, <<",", rest::binary>>}

      {bg, rest2} ->
        {:ok, fg, bg, rest2}
    end
  end

  defp parse_optional_bg(fg, rest) do
    {:ok, fg, nil, rest}
  end

  # Read up to 2 digits, producing a number 0-15.
  # If two digits form a number > 15, only consume the first digit.
  defp read_color_number(<<d1, d2, rest::binary>>)
       when d1 in ?0..?9 and d2 in ?0..?9 do
    two_digit = (d1 - ?0) * 10 + (d2 - ?0)

    if two_digit <= 15 do
      {two_digit, rest}
    else
      # Only consume first digit
      {d1 - ?0, <<d2, rest::binary>>}
    end
  end

  defp read_color_number(<<d1, rest::binary>>) when d1 in ?0..?9 do
    {d1 - ?0, rest}
  end

  defp read_color_number(rest) do
    {nil, rest}
  end

  # ── Code limit enforcement ───────────────────────────────────────────

  defp enforce_code_limit(tokens, max_codes) do
    {result, _count} =
      Enum.reduce(tokens, {[], 0}, fn
        {:text, _} = token, {acc, count} ->
          {[token | acc], count}

        code_token, {acc, count} ->
          if count < max_codes do
            {[code_token | acc], count + 1}
          else
            # Strip excess code — just drop it
            {acc, count}
          end
      end)

    Enum.reverse(result)
  end

  # ── HTML renderer ────────────────────────────────────────────────────

  defp render_tokens([], state, acc) do
    close_span_if_active(state, acc)
    |> Enum.reverse()
    |> Enum.join()
  end

  defp render_tokens([{:text, text} | rest], state, acc) do
    escaped = html_escape(text)

    if has_active_formatting?(state) do
      # Text within an active formatting span
      render_tokens(rest, state, [escaped | acc])
    else
      render_tokens(rest, state, [escaped | acc])
    end
  end

  defp render_tokens([{:bold} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{bold: !state.bold})
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:italic} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{italic: !state.italic})
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:underline} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{underline: !state.underline})
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:strikethrough} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{strikethrough: !state.strikethrough})
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:reverse} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{reverse: !state.reverse})
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:reset} | rest], _state, acc) do
    new_state = initial_state()

    acc =
      if has_active_formatting?(new_state) do
        acc
      else
        acc
      end

    # Close any open span
    render_tokens(rest, new_state, close_current_span(acc))
  end

  defp render_tokens([{:color, fg, bg} | rest], state, acc) do
    changes = %{fg_color: fg}
    changes = if bg, do: Map.put(changes, :bg_color, bg), else: changes
    {acc, state} = transition_state(acc, state, changes)
    render_tokens(rest, state, acc)
  end

  defp render_tokens([{:color_reset} | rest], state, acc) do
    {acc, state} = transition_state(acc, state, %{fg_color: nil, bg_color: nil})
    render_tokens(rest, state, acc)
  end

  # ── State transition helpers ─────────────────────────────────────────

  defp transition_state(acc, old_state, changes) do
    new_state = Map.merge(old_state, changes)

    acc =
      if has_active_formatting?(old_state) do
        close_current_span(acc)
      else
        acc
      end

    acc =
      if has_active_formatting?(new_state) do
        [open_span(new_state) | acc]
      else
        acc
      end

    {acc, new_state}
  end

  defp close_current_span(acc) do
    ["</span>" | acc]
  end

  defp close_span_if_active(state, acc) do
    if has_active_formatting?(state) do
      ["</span>" | acc]
    else
      acc
    end
  end

  defp has_active_formatting?(state) do
    state.bold or state.italic or state.underline or state.strikethrough or
      state.reverse or state.fg_color != nil or state.bg_color != nil
  end

  defp open_span(state) do
    classes = build_classes(state)
    ~s(<span class="#{classes}">)
  end

  defp build_classes(state) do
    []
    |> maybe_add(state.bold, "irc-bold")
    |> maybe_add(state.italic, "irc-italic")
    |> maybe_add(state.underline, "irc-underline")
    |> maybe_add(state.strikethrough, "irc-strikethrough")
    |> maybe_add(state.reverse, "irc-reverse")
    |> maybe_add(state.fg_color != nil, "irc-fg-#{state.fg_color}")
    |> maybe_add(state.bg_color != nil, "irc-bg-#{state.bg_color}")
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp maybe_add(list, true, class), do: [class | list]
  defp maybe_add(list, false, _class), do: list

  # ── HTML escaping ────────────────────────────────────────────────────

  defp html_escape(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
