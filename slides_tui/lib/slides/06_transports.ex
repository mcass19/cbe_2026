defmodule TuisEverywhere.Slides.Transports do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Transports"

  def notes do
    """
    - two questions: where do the bytes go, where do the events come from. ratatui paints cells, the terminal side turns them into ansi bytes. answer those two and the app runs anywhere
    - every transport here is still bytes, a terminal on the other end. keep that word, it comes back in two slides
    - :local, what we had so far. crossterm owns the tty
    - :ssh, the node IS the ssh server. otp's own daemon: passwords, keys, or a pwdfun callback, no sshd. every connection gets its own server + its own in-memory terminal, nothing shared. "tmux, not screen": no reattach, no scrollback. dashboards on servers, admin consoles, wargames
    - :distributed, app on a node with no terminal, attach from the laptop. wire protocol is three messages: draw, event, resize. plain terms, no serialization. the app node never loads the nif, stateful widgets get snapshotted so a nif handle never crosses nodes. x86 laptop into an arm device works. trust model is the cookie, same as remsh. observer energy
    - nerves, the three meet: pi on hdmi = :local, nerves_ssh subsystem = ssh -t in, attach over dist to a device that never compiled rust. nerves_ex_ratatui_example: system monitor + led, one module, three doors
    - subsystem quirk if asked: otp eats the pty request before the handler exists, so it starts at 80x24 and asks the terminal its size with a cursor position report. always pass -t
    - contract is small -> custom transports. the guide has a working tcp one in ~95 lines. raw tcp has no resize channel by construction, which is the argument for ssh
    - punchline: the app module does not change. transport is an option, not an architecture
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "One app, any door", [
      "where do the bytes go, where do the events come from",
      ":local — the terminal in front of it, crossterm owns the tty",
      ":ssh — the BEAM as an SSH server, one isolated session per connection",
      ":distributed — attach from another node, the app side never loads the NIF",
      "Nerves — local, nerves_ssh subsystem, attach over dist: one firmware",
      "custom — small contract: bytes out, events in"
    ])
  end
end
