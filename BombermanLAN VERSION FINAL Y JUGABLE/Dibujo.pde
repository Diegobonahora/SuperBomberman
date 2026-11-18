
//  DIBUJO Y SPRITES: recorta los personajes, medio mal pero andaa


class GestorSprites {
  PImage hoja;
  boolean cargado = false;

  // [jugador: 0=Blanco, 1=Negro][direccion: 0=arriba, 1=abajo, 2=izq, 3=der][cuadro: 0..2]
  PImage[][][] caminar = new PImage[2][4][3];
  PImage[][] derrota = new PImage[2][4];

  void cargar(String archivo) {
    hoja = loadImage(archivo);
    if (hoja == null) {
      println("Aviso: no se encontró data/" + archivo + ", se usarán figuras geométricas.");
      return;
    }

    int[] colsJ1 = {3, 20, 37};       // Bomberman Blanco
    int[] colsJ2 = {196, 213, 230};   // Bomberman Negro
    
    //  0=Arriba, 1=Abajo, 2=Izquierda, 3=Derecha
    // Y: 122=Arriba, 47=Abajo, 72=Izquierda, 97=Derecha
    int[] filasImg = {122, 47, 72, 97}; 

    for (int dir = 0; dir < 4; dir++) {
      for (int f = 0; f < 3; f++) {
        caminar[0][dir][f] = recortarTransparente(colsJ1[f], filasImg[dir], 16, 24);
        caminar[1][dir][f] = recortarTransparente(colsJ2[f], filasImg[dir], 16, 24);
      }
    }

    int[] colsKO1 = {3, 20, 37, 54};
    int[] colsKO2 = {196, 213, 230, 247};
    for (int f = 0; f < 4; f++) {
      derrota[0][f] = recortarTransparente(colsKO1[f], 171, 16, 24);
      derrota[1][f] = recortarTransparente(colsKO2[f], 171, 16, 24);
    }

    cargado = true;
  }

  PImage recortarTransparente(int x, int y, int w, int h) {
    PImage recorte = hoja.get(x, y, w, h);
    PImage limpio = createImage(w, h, ARGB);
    recorte.loadPixels();
    limpio.loadPixels();

    color fondo = recorte.pixels[0];

    for (int i = 0; i < recorte.pixels.length; i++) {
      if (recorte.pixels[i] == fondo) {
        limpio.pixels[i] = color(0, 0, 0, 0);
      } else {
        limpio.pixels[i] = recorte.pixels[i];
      }
    }
    limpio.updatePixels();
    return limpio;
  }
}

//PANTALLA DE BÚSQUEDA INICIAL 
void dibujarBuscando() {
  background(25, 30, 50);
  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(44);
  text("BOMBERMAN LAN", width / 2, height / 2 - 80);

  fill(255);
  textSize(24);
  String puntos = "";
  for (int i = 0; i < (millis() / 400) % 4; i++) puntos += ".";
  text("Buscando partida en la red" + puntos, width / 2, height / 2);

  fill(170);
  textSize(15);
  text("Si no hay ninguna partida abierta, vas a crear una automáticamente.", width / 2, height / 2 + 45);
}

void dibujarPartida() {
  synchronized(candado) {
    procesarEventosVisuales();
    particulas.actualizar();

    if (partida.fase == LOBBY) {
      dibujarLobby();
    } else {
      dibujarJuego();
      if (partida.fase == FIN_PARTIDA) dibujarFin();
    }
  }
}

void procesarEventosVisuales() {
  for (int i = 0; i < eventosLocales.size(); i++) {
    int[] ev = eventosLocales.get(i);
    if (ev[0] == 0) particulas.fuego(ev[1], ev[2]);
    else if (ev[0] == 1) particulas.escombros(ev[1], ev[2]);
    else if (ev[0] == 2) particulas.brillo(ev[1], ev[2]);
    else if (ev[0] == 3) particulas.muerte(ev[1], ev[2]);
  }
  eventosLocales.clear();
}

void dibujarLobby() {
  background(25, 30, 50);
  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(40);
  text("SALA DE ESPERA", width / 2, 160);

  fill(255);
  textSize(20);
  String puntos = "";
  for (int i = 0; i < (millis() / 400) % 4; i++) puntos += ".";

  if (esServidor) {
    text("Sos el JUGADOR 1 (Bomberman Blanco - Servidor)", width / 2, 245);
    fill(120, 220, 140);
    textSize(22);
    text("IP local: " + Server.ip(), width / 2, 290);
    fill(255);
    textSize(20);
    text("Esperando que se conecte el Jugador 2" + puntos, width / 2, 355);
    fill(170);
    textSize(15);
    text("Abrí el programa en la otra compu (o en otra ventana) para empezar.", width / 2, 415);
    text("Controles: W A S D / Flechas = Mover  |  ESPACIO = Bomba  |  E = Detonar", width / 2, 460);
  } else {
    text("Sos el JUGADOR 2 (Bomberman Negro - Cliente)", width / 2, 245);
    fill(120, 220, 140);
    text("Conectado a " + serverIP, width / 2, 290);
    fill(255);
    text("Entrando a la partida" + puntos, width / 2, 355);
  }
}

void dibujarJuego() {
  if (!esServidor) suavizarJugadores();

  dibujarHUD();

  pushMatrix();
  translate(0, OFFSET_Y);
  dibujarMapa();
  dibujarPowerUps();
  dibujarExplosiones();
  dibujarBombas();
  dibujarJugadores();
  particulas.dibujar();
  popMatrix();

  if (partida.fase == CUENTA) {
    fill(0, 120);
    noStroke();
    rect(0, OFFSET_Y, width, height - OFFSET_Y);
    fill(255, 220, 60);
    textAlign(CENTER, CENTER);
    textSize(110);
    text(max(1, ceil(partida.tiempo)), width / 2, height / 2);
    textSize(22);
    fill(255);
    text("¡Prepárate!", width / 2, height / 2 + 90);
  } else if (partida.fase == FIN_RONDA) {
    fill(0, 150);
    noStroke();
    rect(0, height / 2 - 60, width, 120);
    textAlign(CENTER, CENTER);
    fill(255, 220, 60);
    textSize(36);
    if (partida.ganadorRonda == 2) {
      text("¡EMPATE! Se repite la ronda", width / 2, height / 2);
    } else {
      text("Gana la ronda el JUGADOR " + (partida.ganadorRonda + 1), width / 2, height / 2);
    }
  }
}

void suavizarJugadores() {
  for (int i = 0; i < 2; i++) {
    Jugador j = partida.jugadores[i];
    float d = dist(j.pos.x, j.pos.y, j.destino.x, j.destino.y);
    if (d > 120) {
      j.pos.set(j.destino.x, j.destino.y);
      j.caminando = false;
    } else {
      j.caminando = (d > 0.8);
      j.pos.x = lerp(j.pos.x, j.destino.x, 0.4);
      j.pos.y = lerp(j.pos.y, j.destino.y, 0.4);
    }
  }
}

void dibujarFin() {
  fill(0, 190);
  noStroke();
  rect(0, 0, width, height);
  textAlign(CENTER, CENTER);

  fill(255, 220, 60);
  textSize(44);
  text("FIN DE LA PARTIDA", width / 2, 200);

  textSize(60);
  if (partida.ganadorPartida == miId) {
    fill(120, 255, 140);
    text("¡GANASTE!", width / 2, 290);
  } else {
    fill(255, 110, 110);
    text("PERDISTE", width / 2, 290);
  }

  fill(255);
  textSize(22);
  if (partida.desconexion) {
    text("El rival se desconectó.", width / 2, 360);
  } else {
    text("Rondas ganadas:  Jugador 1 = " + partida.victorias[0] + "   |   Jugador 2 = " + partida.victorias[1], width / 2, 360);
  }

  fill(190);
  textSize(18);
  if (esServidor) {
    text("Apretá ENTER para jugar de nuevo", width / 2, 430);
  } else if (rivalDesconectado) {
    text("Cerrá el programa y volvé a abrirlo para jugar otra vez.", width / 2, 430);
  } else {
    text("Esperando que el servidor empiece otra partida...", width / 2, 430);
  }
}

void dibujarHUD() {
  noStroke();
  fill(25, 28, 45);
  rect(0, 0, width, OFFSET_Y);

  dibujarDatosJugador(0, 10, false);
  dibujarDatosJugador(1, width - 10, true);

  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(22);
  text("RONDA " + partida.ronda, width / 2, 22);
  fill(180);
  textSize(12);
  text("mejor de 3", width / 2, 44);
}

void dibujarDatosJugador(int id, float x, boolean alineadoDerecha) {
  Jugador j = partida.jugadores[id];
  textAlign(alineadoDerecha ? RIGHT : LEFT, CENTER);

  if (id == 0) fill(240, 245, 255);
  else fill(255, 120, 120);
  textSize(16);
  String nombre = (id == 0) ? "J1 BLANCO" : "J2 NEGRO";
  if (id == miId) nombre += " (VOS)";
  text(nombre + "   Rondas: " + partida.victorias[id], x, 18);

  fill(210);
  textSize(12);
  String datos = "Bombas " + j.maxBombas + "  Alcance " + j.alcance + "  Vel " + (j.nivelVel + 1);
  if (j.remoto) datos += "  REMOTO";
  text(datos, x, 40);
}

void dibujarMapa() {
  noStroke();
  for (int col = 0; col < COLS; col++) {
    for (int fila = 0; fila < FILAS; fila++) {
      int x = col * TAM;
      int y = fila * TAM;
      int contenido = partida.mapa.celdas[col][fila];

      if ((col + fila) % 2 == 0) fill(60, 145, 75);
      else fill(52, 133, 67);
      rect(x, y, TAM, TAM);

      if (contenido == MURO) {
        fill(95, 95, 112);
        rect(x, y, TAM, TAM);
        fill(150, 150, 170);
        rect(x + 4, y + 4, TAM - 8, TAM - 8, 4);
        fill(120, 120, 140);
        rect(x + 10, y + 10, TAM - 20, TAM - 20, 3);
      } else if (contenido == BLOQUE) {
        fill(120, 66, 30);
        rect(x, y, TAM, TAM);
        fill(184, 108, 54);
        rect(x + 2, y + 2, TAM - 4, TAM - 4, 3);
        stroke(125, 70, 32);
        strokeWeight(2);
        line(x + 2, y + TAM / 2, x + TAM - 2, y + TAM / 2);
        line(x + TAM / 2, y + 2, x + TAM / 2, y + TAM / 2);
        line(x + TAM / 4, y + TAM / 2, x + TAM / 4, y + TAM - 2);
        line(x + 3 * TAM / 4, y + TAM / 2, x + 3 * TAM / 4, y + TAM - 2);
        noStroke();
      }
    }
  }
}

void dibujarPowerUps() {
  for (PowerUp p : partida.powerUps) {
    float cx = (p.col + 0.5) * TAM;
    float cy = (p.fila + 0.5) * TAM;
    float flota = sin(millis() * 0.008 + p.col) * 2;

    if (p.tipo == 0) fill(235, 80, 60);
    else if (p.tipo == 1) fill(70, 120, 235);
    else if (p.tipo == 2) fill(60, 200, 90);
    else fill(170, 80, 220);

    stroke(255);
    strokeWeight(2);
    rect(cx - 15, cy - 15 + flota, 30, 30, 7);
    noStroke();
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(18);
    String letra = "A";
    if (p.tipo == 1) letra = "B";
    if (p.tipo == 2) letra = "V";
    if (p.tipo == 3) letra = "R";
    text(letra, cx, cy + flota - 1);
  }
}

void dibujarExplosiones() {
  noStroke();
  for (Explosion e : partida.explosiones) {
    for (int[] celda : e.celdas) {
      int x = celda[0] * TAM;
      int y = celda[1] * TAM;
      fill(255, 120, 20);
      rect(x + 2, y + 2, TAM - 4, TAM - 4, 10);
      fill(255, 210, 60);
      rect(x + 9, y + 9, TAM - 18, TAM - 18, 8);
      fill(255, 255, 200);
      rect(x + 17, y + 17, TAM - 34, TAM - 34, 4);
    }
  }
}

void dibujarBombas() {
  for (Bomba b : partida.bombas) {
    float cx = (b.col + 0.5) * TAM;
    float cy = (b.fila + 0.5) * TAM;
    float pulso = 1 + 0.1 * sin(millis() * 0.012 + b.col);
    noStroke();
    fill(15);
    ellipse(cx, cy + 3, 34 * pulso, 32 * pulso);
    fill(80);
    ellipse(cx - 6, cy - 4, 8, 8);
    if (b.remota) {
      fill(190, 90, 240);
      ellipse(cx + 5, cy + 6, 8, 8);
    }
    stroke(200, 160, 60);
    strokeWeight(3);
    line(cx + 6, cy - 12, cx + 12, cy - 19);
    noStroke();
    if ((millis() / 120) % 2 == 0) fill(255, 220, 40);
    else fill(255, 120, 20);
    ellipse(cx + 12, cy - 20, 8, 8);
  }
}

void dibujarJugadores() {
  for (int i = 0; i < 2; i++) {
    Jugador j = partida.jugadores[i];
    float x = j.pos.x;
    float y = j.pos.y;

    noStroke();
    fill(0, 75);
    ellipse(x, y + 15, 28, 10);

    if (sprites.cargado) {
      imageMode(CENTER);
      noSmooth();
      PImage imgActual;

      if (!j.vivo) {
        int cuadroKO = (millis() / 150) % 4;
        imgActual = sprites.derrota[i][cuadroKO];
      } else {
        int[] secuencia = {0, 1, 0, 2};
        int cuadro = j.caminando ? secuencia[(millis() / 120) % 4] : 0;
        imgActual = sprites.caminar[i][j.mirada][cuadro];
      }

      pushMatrix();
      translate(x, y - 6);
      if (j.vivo && j.mirada == 2) {
        scale(-1, 1);
      }
      image(imgActual, 0, 0, 34, 51);
      popMatrix();

      imageMode(CORNER);
    } else if (j.vivo) {
      color casco = (i == 0) ? color(240, 240, 255) : color(50, 50, 60);
      fill(casco);
      ellipse(x, y + 6, 26, 24);
      fill(255, 225, 190);
      ellipse(x, y - 3, 28, 26);
      fill(casco);
      arc(x, y - 6, 30, 28, PI, TWO_PI);
    }

    if (i == miId && j.vivo) {
      fill(255, 255, 0);
      triangle(x - 6, y - 36, x + 6, y - 36, x, y - 28);
    }
  }
}
