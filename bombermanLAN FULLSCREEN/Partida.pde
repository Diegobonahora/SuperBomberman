
class Mapa {
  int[][] celdas = new int[COLS][FILAS];

  // Arma un mapa nuevo: bordes y pilares fijos + bloques al azar
  void generar() {
    for (int col = 0; col < COLS; col++) {
      for (int fila = 0; fila < FILAS; fila++) {
        if (col == 0 || fila == 0 || col == COLS - 1 || fila == FILAS - 1) {
          celdas[col][fila] = MURO;                       // borde
        } else if (col % 2 == 0 && fila % 2 == 0) {
          celdas[col][fila] = MURO;                       // pilares fijos
        } else if (esZonaInicial(col, fila)) {
          celdas[col][fila] = VACIO;                      // espacio para escapar
        } else if (random(100) < 70) {
          celdas[col][fila] = BLOQUE;
        } else {
          celdas[col][fila] = VACIO;
        }
      }
    }
  }

  // Las 3 celdas libres al lado de cada esquina donde empieza un jugador
  boolean esZonaInicial(int col, int fila) {
    boolean esquinaArriba = (col <= 2 && fila <= 2 && col + fila <= 3);
    int dc = COLS - 1 - col;
    int df = FILAS - 1 - fila;
    boolean esquinaAbajo = (dc <= 2 && df <= 2 && dc + df <= 3);
    return esquinaArriba || esquinaAbajo;
  }

  // Lo que hay en una celda (fuera del mapa cuenta como muro)
  int get(int col, int fila) {
    if (col < 0 || col >= COLS || fila < 0 || fila >= FILAS) return MURO;
    return celdas[col][fila];
  }

  boolean esSolido(int col, int fila) {
    return get(col, fila) != VACIO;
  }

  void destruir(int col, int fila) {
    if (get(col, fila) == BLOQUE) celdas[col][fila] = VACIO;
  }

  // El mapa como texto de 195 caracteres (para mandarlo por la red)
  String comoTexto() {
    StringBuilder sb = new StringBuilder();
    for (int fila = 0; fila < FILAS; fila++) {
      for (int col = 0; col < COLS; col++) {
        sb.append(celdas[col][fila]);
      }
    }
    return sb.toString();
  }

  // Lo contrario: arma el mapa a partir del texto recibido
  void desdeTexto(String texto) {
    if (texto.length() < COLS * FILAS) return;
    for (int fila = 0; fila < FILAS; fila++) {
      for (int col = 0; col < COLS; col++) {
        celdas[col][fila] = texto.charAt(fila * COLS + col) - '0';
      }
    }
  }
}


// ---------------------------------------------------------------------
//  JUGADOR
// ---------------------------------------------------------------------
class Jugador {
  int id;                              // 0 = servidor, 1 = cliente
  PVector pos = new PVector();         // posición (centro del jugador, en píxeles)
  PVector vel = new PVector();         // velocidad (píxeles por segundo)
  PVector destino = new PVector();     // (solo cliente) hacia dónde suavizar el dibujo

  boolean vivo = true;
  int alcance = 2;                     // cuántas celdas llega la explosión
  int maxBombas = 1;                   // cuántas bombas puede tener a la vez
  int nivelVel = 0;                    // 0 a 3
  boolean remoto = false;              // control remoto de bombas

  int dirX = 0;                        // hacia dónde pide moverse (-1, 0, 1)
  int dirY = 0;
  int mirada = 1;                      // 0 arriba, 1 abajo, 2 izquierda, 3 derecha
  boolean pideBomba = false;
  boolean pideDetonar = false;

  Jugador(int id) {
    this.id = id;
    reiniciar();
  }

  // Vuelve a la esquina inicial y a las habilidades básicas
  void reiniciar() {
    if (id == 0) {
      pos.set((1 + 0.5) * TAM, (1 + 0.5) * TAM);
    } else {
      pos.set((COLS - 2 + 0.5) * TAM, (FILAS - 2 + 0.5) * TAM);
    }
    destino.set(pos.x, pos.y);
    vel.set(0, 0);
    vivo = true;
    alcance = 2;
    maxBombas = 1;
    nivelVel = 0;
    remoto = false;
    dirX = 0;
    dirY = 0;
    mirada = 1;
    pideBomba = false;
    pideDetonar = false;
  }

  float velocidad() {
    return 110 + 30 * nivelVel;    // píxeles por segundo
  }

  int col() {
    return floor(pos.x / TAM);
  }

  int fila() {
    return floor(pos.y / TAM);
  }

  // Mueve al jugador. 'dt' son los segundos que pasaron.
  void mover(float dt) {
    if (dirX != 0) mirada = (dirX < 0) ? 2 : 3;
    if (dirY != 0) mirada = (dirY < 0) ? 0 : 1;

    if (dirX == 0 && dirY == 0) {
      vel.set(0, 0);
      return;
    }

    vel.set(dirX, dirY);
    vel.mult(velocidad());
    float paso = velocidad() * dt;

    // Ayuda para doblar en las esquinas: mientras camina en un sentido,
    // lo vamos acomodando al centro del pasillo.
    if (dirX != 0) {
      float centroY = (floor(pos.y / TAM) + 0.5) * TAM;
      float mov = constrain(centroY - pos.y, -paso, paso);
      if (!colisiona(pos.x, pos.y + mov)) pos.y += mov;
    }
    if (dirY != 0) {
      float centroX = (floor(pos.x / TAM) + 0.5) * TAM;
      float mov = constrain(centroX - pos.x, -paso, paso);
      if (!colisiona(pos.x + mov, pos.y)) pos.x += mov;
    }

    // Movemos primero en X y después en Y (así puede "deslizarse" por las paredes)
    float nx = pos.x + vel.x * dt;
    if (!colisiona(nx, pos.y)) pos.x = nx;
    float ny = pos.y + vel.y * dt;
    if (!colisiona(pos.x, ny)) pos.y = ny;
  }

  // ¿Chocaría la caja del jugador si su centro estuviera en (x, y)?
  // Revisamos las 4 esquinas de la caja.
  boolean colisiona(float x, float y) {
    return celdaBloqueada(x - MEDIO_HITBOX, y - MEDIO_HITBOX)
        || celdaBloqueada(x + MEDIO_HITBOX, y - MEDIO_HITBOX)
        || celdaBloqueada(x - MEDIO_HITBOX, y + MEDIO_HITBOX)
        || celdaBloqueada(x + MEDIO_HITBOX, y + MEDIO_HITBOX);
  }

  boolean celdaBloqueada(float px, float py) {
    int col = floor(px / TAM);
    int fila = floor(py / TAM);
    if (partida.mapa.esSolido(col, fila)) return true;
    return partida.bombaBloquea(col, fila, id);
  }
}


// ---------------------------------------------------------------------
//  BOMBA
// ---------------------------------------------------------------------
class Bomba {
  int col;
  int fila;
  int duenio;               // id del jugador que la puso
  int alcance;
  boolean remota;           // si es de control remoto no explota sola
  float restante = 3.0;     // segundos que faltan para explotar
  boolean explotada = false;

  // Un jugador puede atravesar su bomba mientras todavía está parado
  // encima de ella (recién la puso). Apenas sale, ya es un obstáculo.
  boolean[] pasa = new boolean[2];

  Bomba(int col, int fila, int duenio, int alcance, boolean remota) {
    this.col = col;
    this.fila = fila;
    this.duenio = duenio;
    this.alcance = alcance;
    this.remota = remota;
  }
}


// ---------------------------------------------------------------------
//  EXPLOSIÓN: una lista de celdas que están en llamas
// ---------------------------------------------------------------------
class Explosion {
  ArrayList<int[]> celdas = new ArrayList<int[]>();
  float restante = 0.5;     // segundos que dura el fuego

  void agregar(int col, int fila) {
    celdas.add(new int[] {col, fila});
  }

  boolean contiene(int col, int fila) {
    for (int[] celda : celdas) {
      if (celda[0] == col && celda[1] == fila) return true;
    }
    return false;
  }
}


// ---------------------------------------------------------------------
//  POWER-UP
//  tipo 0 = Alcance (+), 1 = Bombas (+), 2 = Velocidad (+), 3 = Control remoto
// ---------------------------------------------------------------------
class PowerUp {
  int col;
  int fila;
  int tipo;

  PowerUp(int col, int fila, int tipo) {
    this.col = col;
    this.fila = fila;
    this.tipo = tipo;
  }
}


// ---------------------------------------------------------------------
//  PARTIDA: el estado completo del juego
// ---------------------------------------------------------------------
class Partida {
  int fase = LOBBY;
  int ronda = 1;
  int[] victorias = new int[2];
  float tiempo = 0;            // segundos que faltan en la fase actual
  int ganadorRonda = -1;       // 0 o 1 = ese jugador, 2 = empate, -1 = nadie todavía
  int ganadorPartida = -1;
  boolean desconexion = false; // true si la partida terminó porque alguien se fue

  Mapa mapa = new Mapa();
  Jugador[] jugadores = new Jugador[2];
  ArrayList<Bomba> bombas = new ArrayList<Bomba>();
  ArrayList<Explosion> explosiones = new ArrayList<Explosion>();
  ArrayList<PowerUp> powerUps = new ArrayList<PowerUp>();

  Partida() {
    jugadores[0] = new Jugador(0);
    jugadores[1] = new Jugador(1);
  }

  // ---------- Empezar ----------

  void nuevaPartida() {
    victorias[0] = 0;
    victorias[1] = 0;
    ronda = 1;
    ganadorPartida = -1;
    desconexion = false;
    nuevaRonda();
  }

  void nuevaRonda() {
    mapa.generar();
    bombas.clear();
    explosiones.clear();
    powerUps.clear();
    jugadores[0].reiniciar();
    jugadores[1].reiniciar();
    ganadorRonda = -1;
    fase = CUENTA;
    tiempo = 3;
  }

  void irALobby() {
    bombas.clear();
    explosiones.clear();
    powerUps.clear();
    jugadores[0].reiniciar();
    jugadores[1].reiniciar();
    desconexion = false;
    ganadorPartida = -1;
    fase = LOBBY;
  }

  // ---------- Se llama cada vuelta del HiloSimulacion ----------

  void actualizar(float dt) {
    // Fuera de la ronda, ignoramos las bombas que pidan los jugadores
    if (fase != JUEGO) {
      for (int i = 0; i < 2; i++) {
        jugadores[i].pideBomba = false;
        jugadores[i].pideDetonar = false;
      }
    }

    if (fase == LOBBY) {
      // Apenas se conecta el jugador 2, empieza la partida
      if (clienteRemoto != null) nuevaPartida();

    } else if (fase == CUENTA) {
      tiempo -= dt;
      if (tiempo <= 0) fase = JUEGO;

    } else if (fase == JUEGO) {
      simularJuego(dt);

    } else if (fase == FIN_RONDA) {
      actualizarExplosiones(dt);
      tiempo -= dt;
      if (tiempo <= 0) {
        if (victorias[0] >= 2 || victorias[1] >= 2) {
          fase = FIN_PARTIDA;
          ganadorPartida = (victorias[0] >= 2) ? 0 : 1;
        } else {
          if (ganadorRonda != 2) ronda++;     // si fue empate, se repite la ronda
          nuevaRonda();
        }
      }
    }
  }

  // ---------- Una vuelta del juego en plena ronda ----------

  void simularJuego(float dt) {
    // 1) Jugadores: poner bombas, detonar y moverse
    for (int i = 0; i < 2; i++) {
      Jugador j = jugadores[i];
      if (!j.vivo) continue;
      if (j.pideBomba) {
        j.pideBomba = false;
        colocarBomba(j);
      }
      if (j.pideDetonar) {
        j.pideDetonar = false;
        detonar(j);
      }
      j.mover(dt);
    }

    // 2) Bombas: cuenta regresiva y explosión (también si las toca el fuego)
    for (int i = 0; i < bombas.size(); i++) {
      Bomba b = bombas.get(i);
      if (b.explotada) continue;
      if (!b.remota) b.restante -= dt;
      if (b.restante <= 0 || hayFuegoEn(b.col, b.fila)) {
        explotarBomba(b);
      }
    }
    // Sacamos las explotadas (recorriendo desde el final, como en el apunte de ArrayList)
    for (int i = bombas.size() - 1; i >= 0; i--) {
      if (bombas.get(i).explotada) bombas.remove(i);
    }

    // 3) Fuego: se va apagando
    actualizarExplosiones(dt);

    // 4) Jugadores que ya salieron de su bomba: ahora es un obstáculo
    for (Bomba b : bombas) {
      for (int i = 0; i < 2; i++) {
        if (b.pasa[i] && !solapa(jugadores[i], b)) b.pasa[i] = false;
      }
    }

    // 5) Recoger power-ups
    for (int i = 0; i < 2; i++) {
      Jugador j = jugadores[i];
      if (!j.vivo) continue;
      for (int k = powerUps.size() - 1; k >= 0; k--) {
        PowerUp p = powerUps.get(k);
        if (p.col == j.col() && p.fila == j.fila()) {
          aplicarPowerUp(j, p.tipo);
          evento(2, p.col, p.fila);
          powerUps.remove(k);
        }
      }
    }

    // 6) ¿Algún jugador está en una celda con fuego? Muere.
    for (int i = 0; i < 2; i++) {
      Jugador j = jugadores[i];
      if (j.vivo && hayFuegoEn(j.col(), j.fila())) {
        j.vivo = false;
        evento(3, j.col(), j.fila());
      }
    }

    // 7) ¿Terminó la ronda?
    int vivos = 0;
    int ultimoVivo = -1;
    for (int i = 0; i < 2; i++) {
      if (jugadores[i].vivo) {
        vivos++;
        ultimoVivo = i;
      }
    }
    if (vivos <= 1) {
      if (vivos == 1) {
        victorias[ultimoVivo]++;
        ganadorRonda = ultimoVivo;
      } else {
        ganadorRonda = 2;          // murieron los dos: empate
      }
      fase = FIN_RONDA;
      tiempo = 3;
    }
  }

  // ---------- Bombas ----------

  void colocarBomba(Jugador j) {
    int col = j.col();
    int fila = j.fila();
    if (bombaEn(col, fila) != null) return;              // ya hay una bomba acá
    if (cantidadBombas(j.id) >= j.maxBombas) return;     // llegó a su límite

    Bomba b = new Bomba(col, fila, j.id, j.alcance, j.remoto);
    for (int i = 0; i < 2; i++) {
      if (solapa(jugadores[i], b)) b.pasa[i] = true;
    }
    bombas.add(b);
  }

  // Control remoto: explota todas las bombas "remotas" de ese jugador
  void detonar(Jugador j) {
    for (int i = 0; i < bombas.size(); i++) {
      Bomba b = bombas.get(i);
      if (b.duenio == j.id && b.remota) explotarBomba(b);
    }
  }

  // La explosión se propaga en cruz. Los muros la frenan; los bloques
  // se rompen y también la frenan; si toca otra bomba, esa explota
  // enseguida (reacción en cadena).
  void explotarBomba(Bomba b) {
    if (b.explotada) return;
    b.explotada = true;

    Explosion e = new Explosion();
    agregarFuego(e, b.col, b.fila);

    int[][] direcciones = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} };
    for (int d = 0; d < 4; d++) {
      for (int k = 1; k <= b.alcance; k++) {
        int col = b.col + direcciones[d][0] * k;
        int fila = b.fila + direcciones[d][1] * k;
        int contenido = mapa.get(col, fila);

        if (contenido == MURO) break;

        agregarFuego(e, col, fila);

        if (contenido == BLOQUE) {
          mapa.destruir(col, fila);
          evento(1, col, fila);
          // 30% de probabilidad de que aparezca un power-up
          if (random(100) < 30) {
            powerUps.add(new PowerUp(col, fila, (int) random(4)));
          }
          break;
        }

        Bomba otra = bombaEn(col, fila);
        if (otra != null) {
          explotarBomba(otra);    // reacción en cadena
          break;
        }
      }
    }
    explosiones.add(e);
  }

  void agregarFuego(Explosion e, int col, int fila) {
    e.agregar(col, fila);
    evento(0, col, fila);
    // el fuego destruye los power-ups que haya en esa celda
    for (int i = powerUps.size() - 1; i >= 0; i--) {
      PowerUp p = powerUps.get(i);
      if (p.col == col && p.fila == fila) powerUps.remove(i);
    }
  }

  void actualizarExplosiones(float dt) {
    for (int i = explosiones.size() - 1; i >= 0; i--) {
      Explosion e = explosiones.get(i);
      e.restante -= dt;
      if (e.restante <= 0) explosiones.remove(i);
    }
  }

  // ---------- Consultas ----------

  Bomba bombaEn(int col, int fila) {
    for (Bomba b : bombas) {
      if (!b.explotada && b.col == col && b.fila == fila) return b;
    }
    return null;
  }

  int cantidadBombas(int id) {
    int total = 0;
    for (Bomba b : bombas) {
      if (b.duenio == id && !b.explotada) total++;
    }
    return total;
  }

  boolean hayFuegoEn(int col, int fila) {
    for (Explosion e : explosiones) {
      if (e.contiene(col, fila)) return true;
    }
    return false;
  }

  // ¿Hay una bomba en esa celda que le impida el paso a este jugador?
  boolean bombaBloquea(int col, int fila, int idJugador) {
    for (Bomba b : bombas) {
      if (b.col == col && b.fila == fila && !b.pasa[idJugador]) return true;
    }
    return false;
  }

  // ¿La caja del jugador toca la celda de la bomba?
  boolean solapa(Jugador j, Bomba b) {
    float cx = (b.col + 0.5) * TAM;
    float cy = (b.fila + 0.5) * TAM;
    return abs(j.pos.x - cx) < TAM / 2.0 + MEDIO_HITBOX && abs(j.pos.y - cy) < TAM / 2.0 + MEDIO_HITBOX;
  }

  void aplicarPowerUp(Jugador j, int tipo) {
    if (tipo == 0) j.alcance = min(j.alcance + 1, 8);
    else if (tipo == 1) j.maxBombas = min(j.maxBombas + 1, 6);
    else if (tipo == 2) j.nivelVel = min(j.nivelVel + 1, 3);
    else j.remoto = true;
  }
}
