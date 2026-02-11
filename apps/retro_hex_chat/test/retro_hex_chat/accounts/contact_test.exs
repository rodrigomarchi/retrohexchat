defmodule RetroHexChat.Accounts.ContactTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Accounts.Contact

  describe "new/1" do
    test "creates contact with all fields provided" do
      now = DateTime.utc_now()

      contact =
        Contact.new(
          contact_nickname: "Alice",
          note: "A friend",
          first_contact_date: now
        )

      assert contact.contact_nickname == "Alice"
      assert contact.note == "A friend"
      assert contact.first_contact_date == now
    end

    test "creates contact with defaults (only contact_nickname)" do
      contact = Contact.new(contact_nickname: "Alice")

      assert contact.contact_nickname == "Alice"
      assert contact.note == nil
      assert %DateTime{} = contact.first_contact_date
    end

    test "creates contact from map with all fields" do
      now = DateTime.utc_now()

      contact =
        Contact.new(%{
          contact_nickname: "Bob",
          note: "Colleague",
          first_contact_date: now
        })

      assert contact.contact_nickname == "Bob"
      assert contact.note == "Colleague"
      assert contact.first_contact_date == now
    end

    test "creates contact from map with defaults" do
      contact = Contact.new(%{contact_nickname: "Bob"})

      assert contact.contact_nickname == "Bob"
      assert contact.note == nil
      assert %DateTime{} = contact.first_contact_date
    end

    test "raises on missing contact_nickname" do
      assert_raise ArgumentError, fn ->
        Contact.new(note: "oops")
      end
    end

    test "note default is nil" do
      contact = Contact.new(contact_nickname: "Alice")
      assert contact.note == nil
    end

    test "first_contact_date default is a DateTime" do
      before = DateTime.utc_now()
      contact = Contact.new(contact_nickname: "Alice")
      after_create = DateTime.utc_now()

      assert DateTime.compare(contact.first_contact_date, before) in [:eq, :gt]
      assert DateTime.compare(contact.first_contact_date, after_create) in [:eq, :lt]
    end
  end
end
