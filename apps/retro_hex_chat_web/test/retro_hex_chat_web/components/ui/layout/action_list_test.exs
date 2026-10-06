defmodule RetroHexChatWeb.Components.UI.ActionListTest do
  @moduledoc """
  The structure a row has to have for its press to mean anything.

  Two of these are not style: a button nested inside another button is invalid
  HTML with no defined click behaviour, and `aria-pressed` on a control that
  fires rather than stays down tells a screen reader the opposite of what
  happens. Both were the shape the previous list had.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.HTML, only: [raw: 1]
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ActionList

  @moduletag :unit

  defp row(assigns) do
    defaults = %{
      id: "row-tech",
      on_activate: "activate",
      title: [%{inner_block: fn _, _ -> "#tech" end, __slot__: :title}]
    }

    render_component(&action_row/1, Map.merge(defaults, assigns))
  end

  defp action(overrides) do
    Map.merge(
      %{
        __slot__: :action,
        inner_block: fn _, _ -> "" end,
        event: "remove",
        label: "Remove #tech"
      },
      Map.new(overrides)
    )
  end

  describe "the press" do
    test "the row carries the activation event and its params" do
      html = row(%{value: %{"channel" => "#tech"}})

      assert html =~ ~s(phx-click="activate")
      assert html =~ ~s(phx-value-channel="#tech")
    end

    test "a row without actions renders exactly one button" do
      assert row(%{}) |> buttons() |> length() == 1
    end
  end

  describe "the verb on the row" do
    test "is a real button carrying the row's own event and params" do
      html =
        row(%{
          value: %{"channel" => "#tech"},
          cta: [%{__slot__: :cta, inner_block: fn _, _ -> "" end, label: "Join"}]
        })

      cta =
        html |> Floki.parse_fragment!() |> Floki.find(".action-list__cta")

      assert Floki.attribute(cta, "phx-click") == ["activate"]
      assert Floki.attribute(cta, "phx-value-channel") == ["#tech"]
      assert cta |> Floki.text() |> String.trim() == "Join"
    end

    test "sits beside the press, not inside it" do
      html = row(%{cta: [%{__slot__: :cta, inner_block: fn _, _ -> "" end, label: "Join"}]})

      assert html |> buttons() |> length() == 2
      assert html |> Floki.parse_fragment!() |> Floki.find("button button") == []
    end
  end

  describe "a row that can do more than one thing" do
    test "the actions are siblings of the press, never nested inside it" do
      html = row(%{action: [action(event: "remove"), action(event: "stop", label: "Stop")]})

      assert html |> buttons() |> length() == 3
      assert html |> Floki.parse_fragment!() |> Floki.find("button button") == []
    end

    test "an icon-only action carries its name for assistive technology" do
      html = row(%{action: [action([])]})

      assert html =~ ~s(aria-label="Remove #tech")
      assert html =~ ~s(title="Remove #tech")
    end

    test "an action sends its own params and can be disabled in place" do
      html = row(%{action: [action(value: %{"position" => 2}, disabled: true)]})

      assert html =~ ~s(phx-value-position="2")

      assert html
             |> Floki.parse_fragment!()
             |> Floki.find(".action-list__action")
             |> Floki.attribute("disabled") == ["disabled"]
    end

    test "an action inherits the row's target unless it names its own" do
      html = row(%{target: "#host", action: [action([])]})

      assert html =~ ~s(phx-target="#host")
    end
  end

  describe "a control that is not a button" do
    test "sits beside the press, because a button holds no interactive content" do
      html =
        row(%{
          control: [
            %{
              __slot__: :control,
              inner_block: fn _, _ -> ~s(<input type="checkbox" name="on" />) |> raw() end
            }
          ]
        })

      doc = Floki.parse_fragment!(html)

      assert Floki.find(doc, ".action-list__primary input") == []
      assert doc |> Floki.find(".action-list__control input") |> length() == 1
    end
  end

  describe "row_action/1, the control a table row shares with a card row" do
    test "carries its event, its params and its accessible name" do
      html =
        render_component(&row_action/1,
          event: "remove",
          value: %{"nickname" => "alice"},
          label: "Remove alice",
          inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
        )

      button = html |> Floki.parse_fragment!() |> Floki.find("button")

      assert Floki.attribute(button, "phx-click") == ["remove"]
      assert Floki.attribute(button, "phx-value-nickname") == ["alice"]
      assert Floki.attribute(button, "aria-label") == ["Remove alice"]
      assert Floki.attribute(button, "title") == ["Remove alice"]
    end
  end

  describe "action_figure/1" do
    test "labels the number it shows" do
      html = render_component(&action_figure/1, label: "Users", value: 42)

      assert html =~ "Users"
      assert html =~ "42"
      assert html =~ "action-list__figure"
    end
  end

  describe "the row a side panel is editing" do
    test "is marked current, and never pressed" do
      html = row(%{current: true})

      assert html =~ ~s(aria-current="true")
      refute html =~ "aria-pressed"
      assert html =~ "action-list__row--current"
    end

    test "an ordinary row is neither" do
      html = row(%{})

      refute html =~ "aria-current"
      refute html =~ "action-list__row--current"
    end
  end

  describe "the list around the rows" do
    test "names itself for assistive technology" do
      html =
        render_component(&action_list/1,
          id: "channels",
          label: "Channels",
          inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
        )

      assert html =~ ~s(aria-label="Channels")
      assert html =~ ~s(id="channels")
    end
  end

  defp buttons(html), do: html |> Floki.parse_fragment!() |> Floki.find("button")
end
