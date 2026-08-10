defmodule LobbyTui.SshTest do
  use ExUnit.Case, async: false

  alias LobbyTui.{Lobby, Ssh}

  setup do
    LobbyTui.Lobby.Seeder.seed_seats!()
    :ok
  end

  # Short and unique: the nickname cap is 16 characters, so tests need
  # room to watch a "-2" suffix land without tripping the clamp.
  defp uniq(prefix \\ "u") do
    prefix <> Base.encode32(:crypto.strong_rand_bytes(3), padding: false)
  end

  defp mount!(ssh_user) do
    {:ok, state} = Ssh.mount(ssh_user: ssh_user, connect?: false)
    on_exit(fn -> Lobby.leave(state.attendee) end)
    state
  end

  describe "sanitize_nickname/1" do
    test "keeps a plain username as-is" do
      assert Ssh.sanitize_nickname("alice") == "alice"
    end

    test "falls back to guest for a missing username" do
      assert Ssh.sanitize_nickname(nil) == "guest"
    end

    test "falls back to guest for a username below the two-character minimum" do
      assert Ssh.sanitize_nickname("x") == "guest"
      assert Ssh.sanitize_nickname("  ") == "guest"
    end

    test "strips unprintable bytes and falls back when nothing printable remains" do
      assert Ssh.sanitize_nickname("a\x01\x02b") == "ab"
      assert Ssh.sanitize_nickname("\x01\x02") == "guest"
    end

    test "clamps a long username to the nickname limit" do
      assert Ssh.sanitize_nickname(String.duplicate("a", 30)) == String.duplicate("a", 16)
    end
  end

  describe "mount/1" do
    test "joins the room under the ssh username" do
      name = uniq()
      state = mount!(name)

      assert state.attendee.nickname == name
      refute state.seated?
    end

    test "auto-suffixes a nickname already in the room" do
      name = uniq()
      _first = mount!(name)
      second = mount!(name)

      assert second.attendee.nickname == "#{name}-2"
    end

    test "keeps a suffixed nickname within the sixteen-character limit" do
      name = String.duplicate("z", 16)
      first = mount!(name)
      second = mount!(name)

      assert first.attendee.nickname == name
      assert second.attendee.nickname == String.duplicate("z", 14) <> "-2"
    end

    test "joins as guest when the client offers no username" do
      state = mount!(nil)

      assert state.attendee.nickname =~ ~r/^guest/
    end

    test "allows quitting with q, like the local transport" do
      state = mount!(uniq())

      assert state.allow_quit?
    end
  end

  describe "daemon_spec/0" do
    setup do
      original = Application.get_env(:lobby_tui, :ssh)
      on_exit(fn -> Application.put_env(:lobby_tui, :ssh, original) end)
      :ok
    end

    test "is nil when the endpoint is disabled" do
      Application.put_env(:lobby_tui, :ssh, enabled: false)

      assert Ssh.daemon_spec() == nil
    end

    test "serves this module, unauthenticated, on the default port" do
      Application.put_env(:lobby_tui, :ssh, enabled: true)

      assert {ExRatatui.SSH.Daemon, opts} = Ssh.daemon_spec()
      assert opts[:mod] == Ssh
      assert opts[:port] == 2222
      assert opts[:no_auth_needed] == true
      assert is_integer(opts[:max_sessions])
      assert is_integer(opts[:idle_time])
    end

    test "generates its own host key when none is configured" do
      Application.put_env(:lobby_tui, :ssh, enabled: true)

      {_mod, opts} = Ssh.daemon_spec()

      assert opts[:auto_host_key] == true
      refute Keyword.has_key?(opts, :system_dir)
    end

    @tag :tmp_dir
    test "uses the configured host key instead of generating one", %{tmp_dir: tmp_dir} do
      Application.put_env(:lobby_tui, :ssh,
        enabled: true,
        host_key_base64: Base.encode64("PRIVATE KEY"),
        host_key_dir: tmp_dir
      )

      {_mod, opts} = Ssh.daemon_spec()

      # The two host-key strategies are mutually exclusive — the daemon
      # refuses a pair.
      assert opts[:system_dir] == String.to_charlist(tmp_dir)
      refute Keyword.has_key?(opts, :auto_host_key)
    end
  end

  describe "materialize_host_key!/2" do
    @tag :tmp_dir
    test "writes the key where OTP looks for it, readable only by the owner", %{tmp_dir: tmp_dir} do
      dir = Path.join(tmp_dir, "host_keys")

      assert Ssh.materialize_host_key!(dir, Base.encode64("PRIVATE KEY")) ==
               String.to_charlist(dir)

      path = Path.join(dir, "ssh_host_ed25519_key")
      assert File.read!(path) == "PRIVATE KEY"

      %File.Stat{mode: mode} = File.stat!(path)
      assert Bitwise.band(mode, 0o777) == 0o600
    end
  end

  describe "terminate/2" do
    test "leaves the room so the nickname frees immediately" do
      name = uniq()
      {:ok, state} = Ssh.mount(ssh_user: name, connect?: false)

      assert :ok = Ssh.terminate(:shutdown, state)

      # Free means re-joinable under the very same nickname, with no suffix.
      {:ok, rejoined} = Ssh.mount(ssh_user: name, connect?: false)
      assert rejoined.attendee.nickname == name
      Lobby.leave(rejoined.attendee)
    end

    test "tolerates a state that never finished mounting" do
      assert :ok = Ssh.terminate(:shutdown, nil)
    end
  end
end
