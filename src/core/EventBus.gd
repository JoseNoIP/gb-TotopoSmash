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
## Emitida por BoardManager al terminar de procesar un turno SIN que la partida haya
## terminado (ni game over ni nivel despejado) — en AMBOS modos. Es la señal mode-agnostic
## que TurnManager escucha para volver de ADVANCING a AIMING; `wave_advanced` de arriba es
## específica de Modo Infinito (HUD/bono de score) y Modo Nivel nunca la emite, así que
## TurnManager no puede depender de ella para saber cuándo continuar.
signal turn_advanced
## fase del turno: ver TurnManager.Phase (AIMING, FIRING, RESOLVING, RETURNING, ADVANCING)
signal turn_phase_changed(phase: int)

# --- Apuntado y disparo (Molcajete) ---
signal aim_updated(origin: Vector2, aim_points: PackedVector2Array)
signal aim_cancelled
## Emitida por Mortar al soltar el dedo. TurnManager la escucha para iniciar la ráfaga.
signal fire_requested(direction: Vector2, origin: Vector2)
signal burst_fired(seed_count: int)
## Emitida por el botón de "recoger semillas" del HUD (pedido explícito del usuario: no
## esperar a que cada semilla termine su recorrido, sobre todo en niveles con cientos de
## semillas donde ni siquiera el boost de mantener presionado se siente suficiente).
## TurnManager la escucha y fuerza el aterrizaje de TODAS las semillas activas ya mismo.
signal recall_all_seeds_requested
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

# --- Modo Nivel (niveles finitos y deterministas, ver LevelManager/LevelLoader) ---
## Cruda: BoardManager la emite cuando ya no quedan bloques destructibles (piedra no
## cuenta) y no hay más filas en la cola del nivel. `turns_used` es cuántos turnos tomó
## limpiarlo — 0 si no aplica (Modo Infinito nunca la emite). GameManager la escucha y
## emite level_completed (enriquecida) — mismo patrón que board_reached_bottom -> game_over.
signal level_cleared(level_id: String, turns_used: int)
signal level_completed(level_id: String, final_score: int)

# --- Acelerar semillas mientras rebotan ---
## Mortar la emite fuera de la fase AIMING (mantener presionado = true, soltar = false).
## Seed multiplica su delta efectivo mientras está activa. Nunca durante el apuntado.
signal seed_boost_changed(active: bool)

# --- Íconos de poder en el tablero ---
signal lemon_triggered(origin: Vector2)
## Emitida por el ícono al ser tocado (antes de que TurnManager sepa el nuevo total).
## `amount` viaja con la señal en vez de leerse de Constants.SEED_EXTRA_AMOUNT directo —
## un nivel autorado (ver seed_extra_icon.gd::amount) puede pedir un ícono que otorgue más
## de 1 semilla (pedido explícito del usuario: niveles `static` de exhibición con muchas
## semillas iniciales necesitan bonos grandes para acumular cientos de semillas).
signal seed_extra_touched(origin: Vector2, amount: int)
signal seed_extra_collected(new_total: int)
## Power-up láser (ver laser_icon.gd) — BoardManager aplica Constants.LASER_DAMAGE a toda
## la fila, columna, o AMBAS de grid_pos según `orientation` ("horizontal"/"vertical"/
## "both"), mismo patrón que salsa_exploded pero en línea(s) recta(s) en vez de en cruz.
## Se emite CADA VEZ que una semilla toca el ícono — a diferencia de lemon/seed_extra, el
## láser es persistente (pedido explícito del usuario: "no debe desaparecer al primer
## toque... debe ejecutarse cada vez que una semilla lo toque").
signal laser_triggered(grid_pos: Vector2i, orientation: String)

# --- Score ---
signal score_changed(new_score: int)
signal high_score_updated(new_high_score: int)

# --- Mejoras / oro / personajes (ver src/features/meta/upgrade_shop.gd) ---
signal gold_changed(new_total: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal character_selected(character_id: String)
