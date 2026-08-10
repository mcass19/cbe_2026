defmodule LobbyTui.SshIntegrationTest do
  @moduledoc """
  The SSH entry point over a real `:ssh.daemon/2`: a client connects with a
  username and no credentials, appears in the room under that nickname, and
  is gone as soon as the connection closes.

  This is the only coverage of the pieces that cannot be faked — OTP's
  `no_auth_needed`, the username reaching `mount/1` across a real handshake,
  and the disconnect path running `terminate/2`.
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @moduletag :tmp_dir

  alias LobbyTui.Lobby

  setup %{tmp_dir: tmp_dir} do
    LobbyTui.Lobby.Seeder.seed_seats!()

    system_dir = Path.join(tmp_dir, "system")
    user_dir = Path.join(tmp_dir, "user")
    File.mkdir_p!(system_dir)
    File.mkdir_p!(user_dir)

    key = :public_key.generate_key({:rsa, 2048, 65_537})
    pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
    File.write!(Path.join(system_dir, "ssh_host_rsa_key"), pem)

    {:ok, system_dir: String.to_charlist(system_dir), user_dir: String.to_charlist(user_dir)}
  end

  # Tearing down a live session logs a writer/draw failure — the last
  # frame races the closing channel. Expected on any disconnect, and
  # captured here so the suite output stays readable.
  test "an unauthenticated client joins as its username and leaves on disconnect", ctx do
    capture_log(fn -> join_and_disconnect(ctx) end)
  end

  defp join_and_disconnect(ctx) do
    daemon =
      start_supervised!(
        {ExRatatui.SSH.Daemon,
         mod: LobbyTui.Ssh,
         name: nil,
         port: 0,
         no_auth_needed: true,
         system_dir: ctx.system_dir,
         user_dir: ctx.system_dir}
      )

    {:ok, daemon_ref} = ExRatatui.SSH.Daemon.daemon_ref(daemon)
    {:ok, info} = :ssh.daemon_info(daemon_ref)
    port = Keyword.fetch!(info, :port)

    nickname = "w" <> Base.encode32(:crypto.strong_rand_bytes(3), padding: false)

    {:ok, conn} =
      :ssh.connect(~c"127.0.0.1", port,
        user: String.to_charlist(nickname),
        silently_accept_hosts: true,
        user_dir: ctx.user_dir,
        user_interaction: false
      )

    {:ok, chan} = :ssh_connection.session_channel(conn, 5_000)
    :success = :ssh_connection.ptty_alloc(conn, chan, term: ~c"xterm", width: 80, height: 24)
    :ok = :ssh_connection.shell(conn, chan)

    assert until(fn -> attendee_named(nickname) != nil end),
           "the ssh client never appeared in the room as #{nickname}"

    :ok = :ssh.close(conn)

    assert until(fn -> attendee_named(nickname) == nil end),
           "the attendee outlived the ssh connection"
  end

  defp attendee_named(nickname) do
    Lobby.Attendee
    |> Ash.read!()
    |> Enum.find(&(&1.nickname == nickname))
  end

  # Polls a condition rather than sleeping a fixed amount: the room is
  # reached through a real SSH handshake, so the timing is not ours to
  # predict.
  defp until(fun, attempts \\ 40)
  defp until(_fun, 0), do: false

  defp until(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(50)
      until(fun, attempts - 1)
    end
  end
end
