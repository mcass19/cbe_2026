defmodule TuisEverywhere.Slides.AdvancedWidgets do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.{Layout, Style, Subscription}
  alias ExRatatui.ThreeD.{Camera, Light, Material, Mesh, Object, Scene, Transform}
  alias ExRatatui.Widgets.{Block, Paragraph, Viewport3D}
  alias SlidesTui.Layout, as: SlidesLayout
  alias TuisEverywhere.Slides.Ui

  @bullets [
    "images — Kitty / Sixel / iTerm2, halfblock fallback",
    "3D — lit scenes rasterized into cells (live, over there)",
    "copy & paste — bracketed paste, one event per paste",
    "markdown & code — syntect-highlighted, straight from strings",
    "custom — cells are data; compose and ship new widgets"
  ]

  def title, do: "Advanced widgets"

  def notes do
    """
    ## Advanced widgets

    - the cube is rendering live right now: a Subscription.interval
      nudges the angle, render/2 rebuilds the scene — and the
      subscription is torn down the moment we leave this slide
    - images: protocol auto-probe picks Kitty/Sixel/iTerm2 on capable
      terminals, halfblocks anywhere else
    - 3D: primitives, meshes, Phong materials, lights, camera —
      software-rasterized into half-block cells here (cell modes don't
      flicker under animation; pixel modes re-transmit per frame)
    - paste arrives as one %Event.Paste{} instead of shredded
      keystrokes; OSC 52 covers clipboard copy
    - markdown and code blocks share syntect highlighting — the notes
      popup in this deck is the markdown widget
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
        border_style: %Style{fg: {:rgb, 34, 206, 222}}
      }
    }
  end
end
