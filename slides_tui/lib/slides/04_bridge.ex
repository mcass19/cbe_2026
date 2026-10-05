defmodule TuisEverywhere.Slides.Bridge do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Layout
  alias ExRatatui.Widgets.CodeBlock
  alias TuisEverywhere.Slides.Ui

  # Code doesn't scale with the grid, so both sides stay under 56
  # columns: next to the bullets, that still fits the deck's 110×30.
  @elixir_side """
  %Paragraph{text: "Hello!", alignment: :center,
             style: %Style{fg: :green}}
  # once per frame, the widget list becomes plain maps...
  %{"type" => "paragraph", "text" => "Hello!",
    "alignment" => "center",
    "style" => %{"fg" => "green"}}
  # ...and crosses the NIF in one call
  Native.draw_frame(terminal, commands)
  """

  @rust_side """
  #[rustler::nif(schedule = "DirtyIo")]
  fn draw_frame(terminal: ResourceArc<TerminalResource>,
                commands: Term)
  // decode the map into ratatui's own types...
  let text  = text::decode_text(map["text"])?;
  let style = decode_style(map["style"])?;
  // ...and let ratatui do the rest
  Paragraph::new(text).style(style).alignment(alignment)
      .render(area, buf);
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
    code_lines = String.split(@elixir_side <> "\n" <> @rust_side, "\n", trim: true)
    code_width = code_lines |> Enum.map(&String.length/1) |> Enum.max()

    Ui.headline_with_figure(
      area,
      "The bridge",
      {:bullets, @bullets},
      {:fixed, code_width, length(code_lines) + 1, &code/1}
    )
  end

  defp code(rect) do
    elixir_height = @elixir_side |> String.split("\n", trim: true) |> length()

    [elixir_rect, _gap, rust_rect] =
      Layout.split(rect, :vertical, [{:length, elixir_height}, {:length, 1}, {:min, 0}])

    [
      {%CodeBlock{content: @elixir_side, language: "elixir", theme: Ui.theme().code_theme},
       elixir_rect},
      {%CodeBlock{content: @rust_side, language: "rust", theme: Ui.theme().code_theme}, rust_rect}
    ]
  end
end
