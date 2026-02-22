defmodule RetroHexChat.Bots.TemplateEngine do
  @moduledoc """
  Simple placeholder substitution engine for bot response templates.

  Replaces `{key}` placeholders with values from a variable map.
  Supported placeholders: {nickname}, {channel}, {topic}, {prefix}, {botname}.
  """

  @spec render(String.t(), map()) :: String.t()
  def render(template, vars) when is_binary(template) and is_map(vars) do
    Enum.reduce(vars, template, fn {key, value}, acc ->
      String.replace(acc, "{#{key}}", to_string(value))
    end)
  end
end
