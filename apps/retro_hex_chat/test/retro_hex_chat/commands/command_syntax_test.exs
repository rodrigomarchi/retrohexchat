defmodule RetroHexChat.Commands.CommandSyntaxTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Commands.CommandSyntax
  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.CommandSyntax.SubOption
  alias RetroHexChat.Commands.Handlers.{Ban, Join, Kick, Mode, Msg}
  alias RetroHexChat.Commands.Registry

  describe "Parameter struct" do
    @tag :unit
    test "creates a required parameter" do
      param = %Parameter{
        name: "nick",
        required: true,
        type: :nick,
        position: 0,
        description: "Target nickname"
      }

      assert param.name == "nick"
      assert param.required == true
      assert param.type == :nick
      assert param.position == 0
      assert param.description == "Target nickname"
    end

    @tag :unit
    test "creates an optional parameter" do
      param = %Parameter{
        name: "reason",
        required: false,
        type: :text,
        position: 1,
        description: nil
      }

      assert param.required == false
      assert param.description == nil
    end

    @tag :unit
    test "supports all parameter types" do
      types = [:nick, :channel, :text, :mode_flags, :number, :command]

      for type <- types do
        param = %Parameter{name: "test", required: true, type: type, position: 0}
        assert param.type == type
      end
    end
  end

  describe "SubOption struct" do
    @tag :unit
    test "creates a sub-option with param" do
      opt = %SubOption{
        flag: "+o",
        label: "Operador",
        description: "Dar status de operador ao nick",
        requires_param: true
      }

      assert opt.flag == "+o"
      assert opt.label == "Operador"
      assert opt.requires_param == true
    end

    @tag :unit
    test "creates a sub-option without param" do
      opt = %SubOption{
        flag: "+m",
        label: "Moderado",
        description: "Somente +v e +o podem falar",
        requires_param: false
      }

      assert opt.requires_param == false
    end
  end

  describe "CommandSyntax struct" do
    @tag :unit
    test "creates a basic command syntax" do
      syntax = %CommandSyntax{
        command: "kick",
        syntax: "/kick <nickname> [reason]",
        description: "Kick a user from the channel.",
        category: :channel,
        parameters: [
          %Parameter{name: "nickname", required: true, type: :nick, position: 0},
          %Parameter{name: "reason", required: false, type: :text, position: 1}
        ],
        examples: ["/kick troll", "/kick troll Spamming"],
        sub_options: nil
      }

      assert syntax.command == "kick"
      assert length(syntax.parameters) == 2
      assert syntax.sub_options == nil
    end

    @tag :unit
    test "creates a command syntax with sub-options" do
      syntax = %CommandSyntax{
        command: "mode",
        syntax: "/mode <+/-flags> [params]",
        description: "Set channel modes.",
        category: :channel,
        parameters: [
          %Parameter{name: "+/-flags", required: true, type: :mode_flags, position: 0},
          %Parameter{name: "params", required: false, type: :text, position: 1}
        ],
        examples: ["/mode +o nick"],
        sub_options: [
          %SubOption{
            flag: "+o",
            label: "Operador",
            description: "Dar operador",
            requires_param: true
          }
        ]
      }

      assert length(syntax.sub_options) == 1
    end

    @tag :unit
    test "creates a command syntax with no parameters" do
      syntax = %CommandSyntax{
        command: "clear",
        syntax: "/clear",
        description: "Clear the chat window.",
        category: :basics,
        parameters: [],
        examples: ["/clear"],
        sub_options: nil
      }

      assert syntax.parameters == []
    end
  end

  describe "to_client_payload/1" do
    @tag :unit
    test "converts a CommandSyntax to a map suitable for push_event" do
      syntax = %CommandSyntax{
        command: "kick",
        syntax: "/kick <nickname> [reason]",
        description: "Kick a user from the channel.",
        category: :channel,
        parameters: [
          %Parameter{
            name: "nickname",
            required: true,
            type: :nick,
            position: 0,
            description: "Target user"
          },
          %Parameter{name: "reason", required: false, type: :text, position: 1, description: nil}
        ],
        examples: ["/kick troll"],
        sub_options: nil
      }

      payload = CommandSyntax.to_client_payload(syntax)

      assert payload.command == "kick"
      assert payload.syntax == "/kick <nickname> [reason]"
      assert payload.description == "Kick a user from the channel."
      assert length(payload.parameters) == 2

      [p1, p2] = payload.parameters
      assert p1.name == "nickname"
      assert p1.required == true
      assert p1.type == "nick"
      assert p1.position == 0
      assert p1.description == "Target user"

      assert p2.name == "reason"
      assert p2.required == false
      assert p2.type == "text"
      assert p2.description == nil

      assert payload.sub_options == nil
    end

    @tag :unit
    test "converts sub_options to maps" do
      syntax = %CommandSyntax{
        command: "mode",
        syntax: "/mode <+/-flags> [params]",
        description: "Set modes.",
        category: :channel,
        parameters: [],
        examples: [],
        sub_options: [
          %SubOption{
            flag: "+o",
            label: "Operador",
            description: "Dar operador",
            requires_param: true
          },
          %SubOption{
            flag: "+m",
            label: "Moderado",
            description: "Canal moderado",
            requires_param: false
          }
        ]
      }

      payload = CommandSyntax.to_client_payload(syntax)

      assert length(payload.sub_options) == 2
      [so1, so2] = payload.sub_options
      assert so1.flag == "+o"
      assert so1.label == "Operador"
      assert so1.requires_param == true
      assert so2.requires_param == false
    end
  end

  describe "compute_current_param_index/2" do
    @tag :unit
    test "returns 0 when no args typed" do
      params = [
        %Parameter{name: "nick", required: true, type: :nick, position: 0},
        %Parameter{name: "reason", required: false, type: :text, position: 1}
      ]

      assert CommandSyntax.compute_current_param_index(params, "") == 0
    end

    @tag :unit
    test "returns 1 when one arg typed" do
      params = [
        %Parameter{name: "nick", required: true, type: :nick, position: 0},
        %Parameter{name: "reason", required: false, type: :text, position: 1}
      ]

      assert CommandSyntax.compute_current_param_index(params, "troll") == 1
    end

    @tag :unit
    test "returns last index when all args provided" do
      params = [
        %Parameter{name: "nick", required: true, type: :nick, position: 0},
        %Parameter{name: "reason", required: false, type: :text, position: 1}
      ]

      assert CommandSyntax.compute_current_param_index(params, "troll spamming") == 1
    end

    @tag :unit
    test "returns nil when params is empty" do
      assert CommandSyntax.compute_current_param_index([], "anything") == nil
    end
  end

  describe "handler syntax_definition/0 implementations" do
    @tag :unit
    test "mode handler returns syntax with sub_options" do
      syntax = Mode.syntax_definition()

      assert %CommandSyntax{} = syntax
      assert syntax.command == "mode"
      assert syntax.category == :channel
      assert [_ | _] = syntax.parameters
      assert is_list(syntax.sub_options)
      assert [_, _, _, _, _ | _] = syntax.sub_options

      flags = Enum.map(syntax.sub_options, & &1.flag)
      assert "+o" in flags
      assert "+v" in flags
      assert "+b" in flags
      assert "+m" in flags
    end

    @tag :unit
    test "kick handler returns syntax with nick and reason params" do
      syntax = Kick.syntax_definition()

      assert %CommandSyntax{} = syntax
      assert syntax.command == "kick"

      assert [nick_param, reason_param] = syntax.parameters
      assert nick_param.type == :nick
      assert nick_param.required == true
      assert reason_param.type == :text
      assert reason_param.required == false
    end

    @tag :unit
    test "join handler returns syntax with channel param" do
      syntax = Join.syntax_definition()

      assert %CommandSyntax{} = syntax
      assert syntax.command == "join"

      [channel_param | _] = syntax.parameters
      assert channel_param.type == :channel
      assert channel_param.required == true
    end

    @tag :unit
    test "msg handler returns syntax with nick and message params" do
      syntax = Msg.syntax_definition()

      assert %CommandSyntax{} = syntax
      assert syntax.command == "msg"

      assert [nick_param, msg_param] = syntax.parameters
      assert nick_param.type == :nick
      assert msg_param.type == :text
      assert msg_param.required == true
    end

    @tag :unit
    test "ban handler returns syntax with nick param" do
      syntax = Ban.syntax_definition()

      assert %CommandSyntax{} = syntax
      assert syntax.command == "ban"
      assert hd(syntax.parameters).type == :nick
    end

    @tag :unit
    test "Registry.get_syntax/1 returns syntax for known commands" do
      syntax = Registry.get_syntax("mode")

      assert %CommandSyntax{} = syntax
      assert syntax.command == "mode"
    end

    @tag :unit
    test "Registry.get_syntax/1 returns nil for commands without syntax" do
      assert Registry.get_syntax("nonexistent") == nil
    end

    @tag :unit
    test "Registry.all_syntax_definitions/0 returns map of syntaxes" do
      all = Registry.all_syntax_definitions()

      assert is_map(all)
      assert map_size(all) > 0
      assert %CommandSyntax{} = all["mode"]
    end
  end
end
