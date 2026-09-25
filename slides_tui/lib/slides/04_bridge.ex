defmodule TuisEverywhere.Slides.Bridge do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Layout
  alias ExRatatui.Widgets.CodeBlock
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @elixir_side """
  %Paragraph{text: "Hello!", style: %Style{fg: :green}, alignment: :center}

  # once per frame, the whole widget list becomes plain maps...
  %{"type" => "paragraph", "text" => "Hello!",
    "style" => %{"fg" => "green"}, "alignment" => "center"}

  # ...and crosses the NIF in one call
  Native.draw_frame(terminal, commands)
  """

  @rust_side """
  #[rustler::nif(schedule = "DirtyIo")]
  fn draw_frame(terminal: ResourceArc<TerminalResource>, commands: Term)

  // decode the map into ratatui's own types...
  let text  = text::decode_text(map["text"])?;
  let style = decode_style(map["style"])?;

  // ...and let ratatui do the rest
  Paragraph::new(text).style(style).alignment(alignment).render(area, buf);
  """

  @bullets [
    "widgets are plain Elixir structs — data in, cells out",
    "`Rustler` — one NIF call per frame, maps in, ratatui renders",
    "layout is ratatui's constraint solver — Elixir never does cell math",
    "events polled on a dirty IO scheduler, delivered as messages",
    "`rustler_precompiled` — no Rust toolchain needed"
  ]

  def title, do: "Rustler"

  def notes do
    """
    - the bridge: rustler, what makes the talk possible
    - a widget is a struct. no process, no state. paragraph, gauge, table, same shape
    - render/2 -> list of {widget, rect} -> plain maps -> one nif call per frame, not per widget
    - rust side decodes into ratatui types, ratatui does layout, diffing, painting. elixir never does cell math
    - input the other way: poll on a dirty io scheduler, keys arrive as messages
    - terminal lives in a ResourceArc: dies with the process, restores the tty on gc
    - rustler_precompiled: mix deps.get, no cargo anywhere. linux x86_64 / aarch64 / arm hf / riscv64, macos both, windows x86_64. otp 26 to 29. the .so is 4.6MB after the size-tuned profile
    - the nif loads lazily on first use: depending on the library never pulls rust into the compiler vm
    - safety: a rust panic is an elixir exception in the calling process, not a vm death. zero unsafe blocks in the crate, the risk lives in the deps (ratatui, crossterm, image decoders)
    - war story: dropped keystrokes under fast typing. the beam's own tty reader was racing crossterm for bytes. fix: park it with the same sigtstp handoff the shell does on ctrl-z, resume on teardown
    - boring on purpose
    """
  end

  def render(_state, area) do
    code_width = 76
    elixir_height = @elixir_side |> String.split("\n") |> length()
    rust_height = @rust_side |> String.split("\n") |> length()
    code_height = elixir_height + 1 + rust_height
    bullets_height = 2 * length(@bullets) - 1
    body_height = max(code_height, bullets_height)

    bundle = SlidesLayout.center(area, width: 150, height: 4 + 2 + body_height)

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    [text_col, _mid, code_col] =
      Layout.split(body, :horizontal, [{:min, 0}, {:length, 4}, {:length, code_width}])

    [elixir_rect, _gap, rust_rect] =
      Layout.split(SlidesLayout.center(code_col, height: code_height), :vertical, [
        {:length, elixir_height},
        {:length, 1},
        {:min, 0}
      ])

    [
      {Ui.headline("The bridge"), head},
      {%Paragraph{text: Ui.bullet_lines(@bullets)},
       SlidesLayout.center(text_col, height: bullets_height)},
      {%CodeBlock{content: @elixir_side, language: "elixir"}, elixir_rect},
      {%CodeBlock{content: @rust_side, language: "rust"}, rust_rect}
    ]
  end
end
