extends Node
## Global signal bus. ALL cross-feature communication goes through here.
## Never call sibling nodes directly — emit a signal and let listeners react.
## TEMPLATE: Add game-specific signals below.

# --- Game state ---
signal game_started
signal game_over(won: bool)

# --- Player ---
signal player_health_changed(current: int, maximum: int)
signal player_died

# --- Scoring ---
signal score_changed(new_score: int)
