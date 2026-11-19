
//  DIBUJO: todo lo que se ve en pantalla.
//  Solo el hilo principal (draw) llama a estas funciones.



//  MENÚ

void dibujarBoton(String texto, int x, int y) {
  boolean encima = sobre(x, y, BTN_W, BTN_H);
  noStroke();
  fill(encima ? color(255, 190, 40) : color(70, 110, 200));
  rect(x, y, BTN_W, BTN_H, 10);
  fill(encima ? color(30) : color(255));
  textAlign(CENTER, CENTER);
  textSize(18);
  text(texto, x + BTN_W / 2, y + BTN_H / 2);
}

void dibujarMenu() {
  noStroke();
  fill(25, 30, 50);
  rect(0, 0, ANCHO_CANVAS, ALTO_CANVAS);

  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(52);
  text("BOMBERMAN LAN", ANCHO_CANVAS / 2, 100);
  fill(200);
  textSize(16);
  text("Juego de 2 jugadores en red local", ANCHO_CANVAS / 2, 150);

  dibujarBoton("JUGAR (automático)", BTN_X, 220);
  dibujarBoton("CREAR PARTIDA (ser servidor)", BTN_X, 290);

  // Campo para escribir la IP
  stroke(campoIPActivo ? color(255, 190, 40) : color(120));
  strokeWeight(2);
  fill(255);
  rect(BTN_X, 365, BTN_W, 44, 6);
  noStroke();
  textAlign(LEFT, CENTER);
  textSize(18);
  if (ipEscrita.length() == 0 && !campoIPActivo) {
    fill(150);
    text("Escribí la IP del servidor (ej: 192.168.1.5)", BTN_X + 12, 387);
  } else {
    fill(20);
    String cursor = (campoIPActivo && (millis() / 500) % 2 == 0) ? "|" : "";
    text(ipEscrita + cursor, BTN_X + 12, 387);
  }
  dibujarBoton("UNIRSE A ESTA IP", BTN_X, 420);

  textAlign(CENTER, CENTER);
  if (mensajeMenu.length() > 0) {
    fill(255, 110, 110);
    textSize(16);
    text(mensajeMenu, ANCHO_CANVAS / 2, 500);
  }

  fill(170);
  textSize(14);
  text("JUGAR (automático): el primero que abre el programa es el servidor,", ANCHO_CANVAS / 2, 550);
  text("el segundo lo encuentra solo y se conecta como cliente.", ANCHO_CANVAS / 2, 570);
  fill(130);
  text("Mover: W A S D o flechas   |   Bomba: ESPACIO   |   Detonar (control remoto): E", ANCHO_CANVAS / 2, 620);
}

void dibujarBuscando() {
  noStroke();
  fill(25, 30, 50);
  rect(0, 0, ANCHO_CANVAS, ALTO_CANVAS);

  textAlign(CENTER, CENTER);
  fill(255);
  textSize(26);
  String puntos = "";
  for (int i = 0; i < (millis() / 400) % 4; i++) puntos += ".";
  text("Buscando partida en la red" + puntos, ANCHO_CANVAS / 2, ALTO_CANVAS / 2 - 10);
  fill(170);
  textSize(15);
  text("Si no hay ninguna, vas a ser el servidor.", ANCHO_CANVAS / 2, ALTO_CANVAS / 2 + 30);
}



//  PARTIDA 

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
  noStroke();
  fill(25, 30, 50);
  rect(0, 0, ANCHO_CANVAS, ALTO_CANVAS);

  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(40);
  text("SALA DE ESPERA", ANCHO_CANVAS / 2, 150);

  fill(255);
  textSize(20);
  String puntos = "";
  for (int i = 0; i < (millis() / 400) % 4; i++) puntos += ".";

  if (esServidor) {
    text("Sos el SERVIDOR (jugador 1)", ANCHO_CANVAS / 2, 240);
    fill(120, 220, 140);
    textSize(24);
    text("Tu IP: " + Server.ip(), ANCHO_CANVAS / 2, 290);
    fill(255);
    textSize(20);
    text("Esperando al jugador 2" + puntos, ANCHO_CANVAS / 2, 360);
    fill(170);
    textSize(15);
    text("En la otra PC (o en otra ventana) abrí el programa y tocá JUGAR.", ANCHO_CANVAS / 2, 420);
    text("Si no te encuentra solo, usá \"UNIRSE A ESTA IP\" con la IP de arriba.", ANCHO_CANVAS / 2, 445);
  } else {
    text("Sos el CLIENTE (jugador 2)", ANCHO_CANVAS / 2, 240);
    fill(120, 220, 140);
    text("Conectado a " + serverIP, ANCHO_CANVAS / 2, 290);
    fill(255);
    text("Esperando que empiece la partida" + puntos, ANCHO_CANVAS / 2, 360);
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
    rect(0, OFFSET_Y, ANCHO_CANVAS, ALTO_CANVAS - OFFSET_Y);
    fill(255, 220, 60);
    textAlign(CENTER, CENTER);
    textSize(110);
    text(max(1, ceil(partida.tiempo)), ANCHO_CANVAS / 2, ALTO_CANVAS / 2);
    textSize(22);
    fill(255);
    text("¡Prepárate!", ANCHO_CANVAS / 2, ALTO_CANVAS / 2 + 90);
  } else if (partida.fase == FIN_RONDA) {
    fill(0, 150);
    noStroke();
    rect(0, ALTO_CANVAS / 2 - 60, ANCHO_CANVAS, 120);
    textAlign(CENTER, CENTER);
    fill(255, 220, 60);
    textSize(36);
    if (partida.ganadorRonda == 2) {
      text("¡EMPATE! Se repite la ronda", ANCHO_CANVAS / 2, ALTO_CANVAS / 2);
    } else {
      text("Gana la ronda el JUGADOR " + (partida.ganadorRonda + 1), ANCHO_CANVAS / 2, ALTO_CANVAS / 2);
    }
  }
}

void suavizarJugadores() {
  for (int i = 0; i < 2; i++) {
    Jugador j = partida.jugadores[i];
    if (dist(j.pos.x, j.pos.y, j.destino.x, j.destino.y) > 120) {
      j.pos.set(j.destino.x, j.destino.y);
    } else {
      j.pos.x = lerp(j.pos.x, j.destino.x, 0.4);
      j.pos.y = lerp(j.pos.y, j.destino.y, 0.4);
    }
  }
}

void dibujarFin() {
  fill(0, 190);
  noStroke();
  rect(0, 0, ANCHO_CANVAS, ALTO_CANVAS);
  textAlign(CENTER, CENTER);

  fill(255, 220, 60);
  textSize(44);
  text("FIN DE LA PARTIDA", ANCHO_CANVAS / 2, 200);

  textSize(60);
  if (partida.ganadorPartida == miId) {
    fill(120, 255, 140);
    text("¡GANASTE!", ANCHO_CANVAS / 2, 290);
  } else {
    fill(255, 110, 110);
    text("PERDISTE", ANCHO_CANVAS / 2, 290);
  }

  fill(255);
  textSize(22);
  if (partida.desconexion) {
    text("El rival se desconectó.", ANCHO_CANVAS / 2, 360);
  } else {
    text("Rondas ganadas:  Jugador 1 = " + partida.victorias[0] + "   |   Jugador 2 = " + partida.victorias[1], ANCHO_CANVAS / 2, 360);
  }

  fill(190);
  textSize(18);
  if (esServidor) {
    text("Apretá ENTER para jugar de nuevo", ANCHO_CANVAS / 2, 430);
  } else if (rivalDesconectado) {
    text("Cerrá el programa y volvé a abrirlo para jugar otra vez.", ANCHO_CANVAS / 2, 430);
  } else {
    text("Esperando que el servidor empiece otra partida...", ANCHO_CANVAS / 2, 430);
  }
}



void dibujarHUD() {
  noStroke();
  fill(25, 28, 45);
  rect(0, 0, ANCHO_CANVAS, OFFSET_Y);

  dibujarDatosJugador(0, 10, false);
  dibujarDatosJugador(1, ANCHO_CANVAS - 10, true);

  textAlign(CENTER, CENTER);
  fill(255, 220, 60);
  textSize(22);
  text("RONDA " + partida.ronda, ANCHO_CANVAS / 2, 22);
  fill(180);
  textSize(12);
  text("mejor de 3", ANCHO_CANVAS / 2, 44);
}

void dibujarDatosJugador(int id, float x, boolean alineadoDerecha) {
  Jugador j = partida.jugadores[id];
  textAlign(alineadoDerecha ? RIGHT : LEFT, CENTER);

  if (id == 0) fill(110, 180, 255);
  else fill(255, 120, 120);
  textSize(16);
  String nombre = "JUGADOR " + (id + 1);
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
    if (!j.vivo) continue;

    color casco = (i == 0) ? color(70, 130, 255) : color(255, 80, 90);
    float x = j.pos.x;
    float y = j.pos.y;

    noStroke();
    fill(0, 70);
    ellipse(x, y + 14, 30, 10);

    fill(casco);
    ellipse(x, y + 6, 26, 24);
    fill(255, 225, 190);
    ellipse(x, y - 3, 28, 26);
    fill(casco);
    arc(x, y - 6, 30, 28, PI, TWO_PI);
    fill(255);
    ellipse(x, y - 19, 8, 8);

    float ox = 0;
    float oy = 0;
    if (j.mirada == 2) ox = -3;
    if (j.mirada == 3) ox = 3;
    if (j.mirada == 0) oy = -2;
    if (j.mirada == 1) oy = 2;
    fill(20);
    ellipse(x - 5 + ox, y - 2 + oy, 5, 7);
    ellipse(x + 5 + ox, y - 2 + oy, 5, 7);

    if (i == miId) {
      fill(255, 255, 0);
      triangle(x - 6, y - 32, x + 6, y - 32, x, y - 24);
    }
  }
}
