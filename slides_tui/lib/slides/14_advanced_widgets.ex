defmodule TuisEverywhere.Slides.AdvancedWidgets do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Subscription}
  alias ExRatatui.ThreeD.{Camera, Light, Material, Mesh, Object, Scene, Transform}
  alias ExRatatui.Widgets.{Block, Paragraph, Viewport3D}
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @bullets [
    "images — Kitty / Sixel / iTerm2, halfblock fallback",
    "3D — lit scenes rasterized into cells (live, over there)",
    "copy & paste — bracketed paste, one event per paste",
    "markdown & code — syntect-highlighted, straight from strings",
    "focus ring + mouse hit-testing, an eleven-slot theme palette",
    "custom widgets — compose existing ones in pure Elixir, no Rust"
  ]

  def title, do: "Advanced widgets"

  def notes do
    """
    - cube is live: Subscription.interval nudges the angle, render rebuilds the scene, torn down on slide change
    - images: auto-probe kitty / sixel / iterm2, halfblocks elsewhere
    - 3D: primitives, meshes, phong, lights, camera. rasterizer or a cpu ray tracer, the controls example toggles them live. half-block cells here: cell modes don't flicker, pixel modes re-transmit per frame
    - paste: one %Event.Paste{}, not shredded keys. OSC 52 for clipboard copy
    - textarea: soft wrap since 0.16, word or glyph, ratatui-textarea does the wrapping and the cursor. first feature from outside the project, thanks shashi
    - markdown + code blocks share syntect. the notes popup in this deck is the markdown widget
    - focus: declarative ring, tab cycles, click to focus via registered rects. theme: eleven semantic slots, pure data threaded through render, no globals
    - custom widgets: a protocol, compose existing widgets, expanded before the nif. no rust. nesting capped at 32, not expanded inside Popup content or WidgetList items, those inner rects are computed in rust
    - images gotcha: :fit and :crop never upscale, the guide calls it the most common confusion. no animated gif, no svg, first frame only
    - 3D: the gpu pipeline is deliberately not exposed, a gpu context inside a nif can take the runtime down. cpu only, on purpose
    - validation: malformed widget fields raise ArgumentError at encode time, never render garbage
    """
  end

  def mount(_opts), do: {:ok, %{angle: 0.0}}

  def subscriptions(_state), do: [Subscription.interval(:cube_spin, 100, :spin)]

  def handle_info(:spin, state), do: {:noreply, %{state | angle: state.angle + 0.06}}
  def handle_info(_msg, state), do: {:noreply, state}

  def render(%{angle: angle}, area) do
    bullets_height = 2 * length(@bullets) - 1

    bundle = SlidesLayout.center(area, width: 120, height: 24)

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [{:length, 4}, {:length, 2}, {:min, 0}])

    [text_col, _mid, cube_col] =
      Layout.split(body, :horizontal, [{:min, 0}, {:length, 4}, {:length, 44}])

    [
      {Ui.headline("Beyond text"), head},
      {%Paragraph{text: Ui.bullet_lines(@bullets)},
       SlidesLayout.center(text_col, height: bullets_height)},
      {viewport(angle), cube_col}
    ]
  end

  defp viewport(angle) do
    cube = %Object{
      mesh: Mesh.cube(),
      material: %Material{color: {225, 31, 193}},
      transform: %Transform{rotation: {:euler_xyz, {angle * 0.3, angle, 0.0}}}
    }

    %Viewport3D{
      scene: %Scene{
        objects: [cube],
        lights: [
          Light.ambient({255, 255, 255}, 0.2),
          Light.directional({-1.0, -1.0, -1.0}, {255, 255, 255}),
          Light.point({2.0, 3.0, 2.0}, {180, 220, 255})
        ],
        background: {8, 8, 16}
      },
      camera: %Camera{position: {3.0, 2.5, 4.0}, target: {0.0, 0.0, 0.0}},
      # A cell mode on purpose: pixel modes re-transmit the image every
      # frame and flicker under continuous animation; half-block doesn't.
      render_mode: :half_block,
      block: %Block{
        title: " live ",
        borders: [:all],
        border_type: :rounded,
        border_style: Ui.violet_style()
      }
    }
  end
end
