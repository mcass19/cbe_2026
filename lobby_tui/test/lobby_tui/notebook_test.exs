defmodule LobbyTui.NotebookTest do
  use ExUnit.Case, async: false

  alias ExRatatui.Event.Key
  alias LobbyTui.{Lobby, Notebook}

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  # Short and unique: the nickname cap is 16 characters, so tests need
  # room to watch a "-2" suffix land without tripping the clamp.
  defp uniq(prefix \\ "nb") do
    prefix <> Base.encode32(:crypto.strong_rand_bytes(3), padding: false)
  end

  defp mount!(opts) do
    {:ok, state} = Notebook.mount(Keyword.put_new(opts, :connect?, false))
    on_exit(fn -> Lobby.leave(state.attendee) end)
    state
  end

  describe "mount/1" do
    test "joins the room under the given nickname" do
      name = uniq()
      state = mount!(nickname: name)

      assert state.attendee.nickname == name
      refute state.seated?
    end

    test "defaults the nickname when none is given" do
      state = mount!([])

      assert state.attendee.nickname =~ ~r/^notebook/
    end

    test "sanitizes the nickname like every other transport" do
      state = mount!(nickname: "a\x01\x02b")

      assert state.attendee.nickname =~ ~r/^ab/
    end

    test "falls back to guest for a nickname below the two-character minimum" do
      state = mount!(nickname: "x")

      assert state.attendee.nickname =~ ~r/^guest/
    end

    test "auto-suffixes a nickname already in the room" do
      name = uniq()
      _first = mount!(nickname: name)
      second = mount!(nickname: name)

      assert second.attendee.nickname == "#{name}-2"
    end

    test "picks the named avatar" do
      avatar = Lobby.list_avatars!() |> List.first()
      state = mount!(nickname: uniq(), avatar: avatar.name)

      assert state.attendee.avatar_id == avatar.id
    end

    test "picks a random avatar when the name matches nothing" do
      state = mount!(nickname: uniq(), avatar: "no-such-avatar")

      assert state.attendee.avatar_id
    end

    test "ignores q by default, like the browser embed" do
      state = mount!(nickname: uniq())

      refute state.allow_quit?
      assert {:noreply, _} = Notebook.handle_event(%Key{code: "q", kind: "press"}, state)
    end

    test "allows quitting with q when asked" do
      state = mount!(nickname: uniq(), quit?: true)

      assert state.allow_quit?
      assert {:stop, _} = Notebook.handle_event(%Key{code: "q", kind: "press"}, state)
    end
  end

  describe "terminate/2" do
    test "leaves the room so the nickname frees immediately" do
      name = uniq()
      state = mount!(nickname: name)

      assert :ok = Notebook.terminate(:shutdown, state)

      second = mount!(nickname: name)
      assert second.attendee.nickname == name
    end
  end
end
