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
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
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
      {%CodeBlock{content: @elixir_side, language: "elixir", theme: Ui.theme().code_theme},
       elixir_rect},
      {%CodeBlock{content: @rust_side, language: "rust", theme: Ui.theme().code_theme}, rust_rect}
    ]
  end
end
