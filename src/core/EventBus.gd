extends Node
## Bus de señales global. TODA comunicación entre features NO relacionadas pasa por aquí.
## Nunca llamar nodos hermanos directamente — emitir señal y dejar que los listeners reaccionen.

# --- Game State ---
signal game_started
signal game_over(final_score: int, wave_reached: int)
signal game_paused
signal game_resumed

# --- Oleadas / Turnos ---
signal wave_advanced(wave_number: int)
## fase del turno: ver TurnManager.Phase (AIMING, FIRING, RESOLVING, RETURNING, ADVANCING)
signal turn_phase_changed(phase: int)

# --- Apuntado y disparo (Molcajete) ---
signal aim_updated(origin: Vector2, aim_points: PackedVector2Array)
signal aim_cancelled
## Emitida por Mortar al soltar el dedo. TurnManager la escucha para iniciar la ráfaga.
signal fire_requested(direction: Vector2, origin: Vector2)
signal burst_fired(seed_count: int)
signal all_seeds_returned(landing_x: float)
signal molcajete_position_changed(new_x: float)
signal seed_count_changed(new_count: int)

# --- Audio (GDD sección 5) ---
## Emitida por Seed en cada colisión (pared o bloque). `block_type` es "" si rebotó contra
## el mundo (pared/techo) o el `block_type` del bloque golpeado (para elegir el SFX
## correcto: crujido de totopo, thud de queso, etc. — ver AudioManager).
signal seed_bounced(block_type: String)

# --- Bloques ---
signal block_damaged(grid_pos: Vector2i, current_hp: int, max_hp: int)
signal block_destroyed(grid_pos: Vector2i, block_type: String, score_value: int)
signal salsa_exploded(grid_pos: Vector2i)
signal board_reached_bottom

# --- Íconos de poder en el tablero ---
signal lemon_triggered(origin: Vector2)
## Emitida por el ícono al ser tocado (antes de que TurnManager sepa el nuevo total).
signal seed_extra_touched(origin: Vector2)
signal seed_extra_collected(new_total: int)

# --- Score ---
signal score_changed(new_score: int)
signal high_score_updated(new_high_score: int)
