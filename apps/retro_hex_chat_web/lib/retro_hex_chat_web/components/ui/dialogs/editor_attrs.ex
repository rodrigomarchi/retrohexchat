defmodule RetroHexChatWeb.Components.UI.EditorAttrs do
  @moduledoc """
  Attributes the list-and-editor panels declare alike.

  A panel lists entries and opens a small form to add or edit one; the form
  opens over the panel's own window or over the whole screen, and the panel
  reports Add, Edit, Remove, Save and Cancel to its parent. Phoenix declares
  component attributes one `attr` at a time, so the shared ones live here and
  each panel calls these macros where it would have written them.
  """

  @doc "`sub_scope`: where the panel's add/edit form opens."
  defmacro sub_scope_attr do
    quote do
      attr :sub_scope, :atom,
        default: :window,
        values: [:viewport, :window],
        doc: "where the add/edit form opens: over this window, or over the screen"
    end
  end

  @doc "The events a list-and-editor panel raises: add, edit, delete, save, cancel."
  defmacro editor_event_attrs do
    quote do
      attr :on_add, :any, default: nil
      attr :on_edit, :any, default: nil
      attr :on_delete, :any, default: nil
      attr :on_save, :any, default: nil
      attr :on_cancel_edit, :any, default: nil
    end
  end
end
