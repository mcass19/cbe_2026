# Generates the placeholder theatre background painting.
# Run once: mix run priv/scripts/gen_placeholder_scene.exs
# The painting logic lives in LobbyTui.Scripts.PlaceholderScene (lib/lobby_tui/scripts/placeholder_scene.ex)
# so its palette is available to LobbyTui.SceneTest without this script's paint running as a side effect.
LobbyTui.Scripts.PlaceholderScene.run()
