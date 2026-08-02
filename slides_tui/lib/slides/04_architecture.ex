defmodule TuisEverywhere.Slides.Architecture do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Layout
  alias ExRatatui.Widgets.CodeBlock
  alias ExRatatui.Widgets.Paragraph
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @example """
  defmodule Hello do
    use ExRatatui.App

    def render(state, frame) do
      area = %Rect{x: 0, y: 0, width: frame.width, height: frame.height}

      [{%Gauge{ratio: state.progress, label: "warming up"}, area}]
    end
  end
  """

  @bullets [
    "widgets are pure Elixir structs — data in, cells out",
    "one NIF call per frame: encode, layout + draw in Rust, diff",
    "events polled on a dirty IO scheduler, delivered as messages",
    "rustler_precompiled: installing needs no Rust toolchain"
  ]

  def title, do: "Architecture"

  def notes do
    """
    ## Architecture

    - the bridge: render/2 returns widget structs; they are encoded once
      and cross the NIF boundary as one call per frame
    - layout is solved on the Rust side (ratatui's constraint solver);
      Elixir never does cell math
    - the terminal lives in a ResourceArc — BEAM-owned native state,
      cleaned up with the process
    - event polling runs on a DirtyIo scheduler so it never blocks a
      normal scheduler; keystrokes arrive as plain messages
    - precompiled NIFs per target/ABI: mix deps.get and it just works —
      no cargo, no cross-compilation stories on user machines
    - the code on screen is a complete, runnable app — this is the whole
      surface a beginner needs
    """
  end

  def render(_state, area) do
    code_width = 72
    code_height = @example |> String.split("\n") |> length()
    bullets_height = 2 * length(@bullets) - 1
    body_height = max(code_height, bullets_height)

    bundle = SlidesLayout.center(area, width: 116, height: 4 + 2 + body_height)

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    [text_col, _mid, code_col] =
      Layout.split(body, :horizontal, [{:min, 0}, {:length, 4}, {:length, code_width}])

    code = %CodeBlock{content: @example, language: "elixir", line_numbers: true}

    [
      {Ui.headline("Bridge + NIF"), head},
      {%Paragraph{text: Ui.bullet_lines(@bullets)},
       SlidesLayout.center(text_col, height: bullets_height)},
      {code, SlidesLayout.center(code_col, height: code_height)}
    ]
  end
end
