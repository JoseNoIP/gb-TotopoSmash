# Documento de Diseño de Juego Avanzado (GDD)
**Proyecto:** Totopo Smash  
**Estudio:** GuacamoleBit  
**Plataforma:** iOS / Android (Mobile)  
**Género:** Puzzle / Arcade / Física de Rebotes (Brick Breaker)  

---

## 1. Visión General del Juego

**Totopo Smash** es un juego de lógica y física hipercasual donde el jugador lanza ráfagas de semillas desde un molcajete mecánico para destruir filas de totopos y bloques de comida basura que descienden en cada turno. El juego destaca por su alta cantidad de proyectiles simultáneos en pantalla y efectos de sonido crujientes y relajantes.

### Pilares de Diseño
* **Cálculo de Ángulos:** Apuntar con precisión usando una guía de trayectoria elástica.
* **Satisfacción del Crujido:** Cada impacto genera físicas de partículas (migajas) y sonidos ASMR muy marcados.
* **Caos Controlado:** Ver cientos de proyectiles rebotando al mismo tiempo en la parte superior del escenario.

---

## 2. Mecánicas Core (Gameplay)

### El Bucle de Juego (Gameplay Loop)
1. **Fase de Apuntado:** El jugador arrastra el dedo en la pantalla. Una línea de puntos muestra la trayectoria del primer rebote.
2. **Fase de Disparo:** Al soltar el dedo, el molcajete dispara **todas** las semillas acumuladas en una ráfaga continua (una detrás de otra rápidamente, no todas juntas en un solo bloque).
3. **Fase de Rebote:** Las semillas rebotan con física elástica perfecta ($e = 1.0$) contra las paredes laterales, el techo y los bloques. Cada impacto en un bloque reduce su contador en 1.
4. **Fase de Retorno:** Al caer al suelo, las semillas regresan automáticamente al molcajete. La primera semilla en tocar el suelo define la nueva posición horizontal del molcajete para el siguiente turno.
5. **Fase de Avance:** Una vez que la última semilla regresa, todos los bloques sobrevivientes bajan una fila. Aparece una nueva fila de bloques en la parte superior.

### Condiciones de Fin de Juego (Game Over)
El tablero tiene una rejilla invisible de $7 \times 9$ casillas. Si cualquier bloque toca la fila inferior (donde se ubica el molcajete) al final de un turno, la partida termina.

---

## 3. Elementos del Tablero y Potenciadores

Los bloques e iconos ocupan casillas cuadradas o triangulares en la rejilla. Se activan inmediatamente al ser golpeados por una semilla:

| Elemento / Icono | Comportamiento Mecánico | Efecto Visual / Feedback |
| :--- | :--- | :--- |
| **Bloque Totopo** | Ladrillo estándar. Tiene un número de vida $N$. | Se va agrietando conforme baja su vida. Explota en migajas al llegar a 0. |
| **Bloque de Queso** | Ladrillo pesado. Absorbe el doble de daño por impacto ($N-2$), pero reduce la velocidad de la semilla un 15% al rebotar. | Visualmente viscoso y denso. Sonido sordo (*thud*). |
| **Frasco de Salsa** | Bloque explosivo. Al llegar a 0, explota y causa 10 puntos de daño a todos los bloques adyacentes en cruz. | Parpadea en rojo antes de estallar en una ola de salsa. |
| **Limón Ácido** | Ícono circular estático. Al tocarlo, la semilla actual se duplica temporalmente en dos semillas con ángulos opuestos. | Destello verde brillante. |
| **Semilla Extra (+1)** | Ícono de semilla brillante. Al tocarlo, se añade permanentemente $+1$ semilla al inventario del jugador para el resto de la nivel. | El ícono vuela hacia el contador del molcajete. |

---

## 4. Curva de Complejidad y Evolución de Niveles

Para mantener al jugador atrapado sin aburrirlo ni frustrarlo, el juego utiliza un sistema de **progresión infinita basada en oleadas** (Turnos) con escalado matemático:

### 4.1. Escalado de la Resistencia de los Bloques
La vida inicial ($N$) de los nuevos bloques que aparecen en la fila superior está directamente ligada al número de la oleada actual ($O$):

*   **Bloques Normales (Totopos):** $N = O$
*   **Bloques Pesados (Queso):** $N = O \times 1.5$ (redondeado hacia arriba)

*Ejemplo en la Oleada 10: Los totopos aparecen con 10 de vida y los bloques de queso con 15.*

### 4.2. Introducción Gradual de Complejidad (Dificultad Dinámica)

*   **Nivel / Oleadas 1-5 (Introducción):** Tablero limpio. Solo aparecen bloques cuadrados de totopos con vida baja ($1$ a $5$). El jugador empieza con 10 semillas. Abundantes íconos de Semilla Extra (+1).
*   **Nivel / Oleadas 6-15 (Geometría):** Se introducen **bloques triangulares**. Estos bloques cambian por completo los ángulos de rebote habituales (enviar las semillas a $45^\circ$ o cambiar la dirección vertical). Aparecen los primeros bloques de Queso.
*   **Nivel / Oleadas 16-30 (Obstáculos Estáticos):** Aparecen bloques indestructibles de "Piedra de Molcajete" que no tienen número. No se pueden eliminar; actúan como deflectores fijos que el jugador debe usar a su favor o rodear para alcanzar los bloques traseros.
*   **Nivel / Oleadas 31+ (Estrangulamiento del Espacio):** El patrón de aparición de bloques deja menos huecos libres, obligando al jugador a buscar "huecos de aguja" geométricos. Si logra meter una semilla por un espacio pequeño hacia la parte superior, se genera el efecto satisfactorio de atrapamiento, destruyendo todo desde arriba.

### 4.3. Ritmo de Compensación (Evolución del Jugador)
El jugador nunca se siente indefenso porque su arsenal crece a la par:
*   Cada turno exitoso recolecta las semillas extra tocadas en el tablero.
*   Al final de la oleada 50, el jugador puede estar disparando ráfagas de más de 60 semillas simultáneamente, manteniendo el equilibrio de poder y la sensación de control absoluto.

---

## 5. Estética, Animación e Identidad (Juice ASMR)

*   **Arte:** Estilo caricaturesco (*vector art toony*) limpio y moderno. Los colores de los bloques son altamente contrastantes: Totopos crujientes amarillos/naranjas, bloques de queso amarillo pastel, frascos de salsa rojo brillante. El fondo del tablero es oscuro (azul noche o gris pizarra) para que resalten las trayectorias de las semillas verdes.
*   **Efectos de Sonido (SFX):**
    *   Rebotes normales: Tonos musicales cortos en escala ascendente (estilo xilófono o gotas de agua) para que las ráfagas largas suenen como una melodía rítmica y relajante.
    *   Impacto Totopo: Un crujido nítido e hiperrealista (*¡crunch!*).
*   **Feedback Háptico:** Vibración muy sutil en el teléfono únicamente cuando un bloque es destruido por completo (llegando a 0) o cuando explota un Frasco de Salsa, evitando saturar la mano del jugador durante los rebotes normales.