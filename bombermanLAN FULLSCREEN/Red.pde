
void lanzarConexion(int modo) {
  modoElegido = modo;
  pantalla = BUSCANDO;
  thread("conectar");
}

void conectar() {
  mensajeMenu = "";
  String ip = null;

  if (modoElegido == 0) {
    // AUTOMÁTICO: preguntamos a toda la red si hay un servidor
    println("Buscando servidor en la red local...");
    ip = buscarServidorEnRed();
  } else if (modoElegido == 2) {
    // Con IP escrita a mano
    ip = ipEscrita;
  }
  // modoElegido == 1 -> "Crear partida": ip queda en null y seremos servidor

  if (ip != null) {
    iniciarComoCliente(ip);
  } else {
    iniciarComoServidor();
  }
}


void iniciarComoCliente(String ip) {
  esServidor = false;
  miId = 1;
  serverIP = ip;

  // new Client(...) abre la conexión TCP con el servidor
  c = new Client(this, ip, PUERTO_TCP);

  if (!c.active()) {
    mensajeMenu = "No se pudo conectar a " + ip + ". ¿Está abierto el servidor?";
    c = null;
    pantalla = MENU;
    return;
  }

  println("Modo: CLIENTE (jugador 2). Conectado a: " + ip);
  surface.setTitle("Bomberman LAN - CLIENTE (jugador 2)");

  partida = new Partida();
  ultimoEstadoRecibido = millis();
  rivalDesconectado = false;
  corriendo = true;

  // El cliente usa 2 hilos: uno que escucha y otro que envía
  hiloRed = new HiloRed();
  hiloRed.start();
  hiloEnvio = new HiloEnvio();
  hiloEnvio.start();

  enviarAlServidor("HOLA\n");
  pantalla = PARTIDA;
}


void iniciarComoServidor() {
  esServidor = true;
  miId = 0;

  // new Server(...) abre el puerto TCP y espera conexiones
  s = new Server(this, PUERTO_TCP);

  if (!s.active()) {
    mensajeMenu = "No se pudo crear el servidor (¿ya hay otro abierto en esta PC?).";
    s = null;
    pantalla = MENU;
    return;
  }

  println("Modo: SERVIDOR (jugador 1). Esperando conexiones...");
  surface.setTitle("Bomberman LAN - SERVIDOR (jugador 1)");

  partida = new Partida();      // empieza en fase LOBBY
  clienteRemoto = null;
  rivalDesconectado = false;
  corriendo = true;

  // El servidor usa 4 hilos
  hiloDescubrimiento = new HiloDescubrimiento();   // responde "ESTOY" a los que buscan
  hiloDescubrimiento.start();
  hiloRed = new HiloRed();                         // escucha al cliente
  hiloRed.start();
  hiloSimulacion = new HiloSimulacion();           // calcula el juego
  hiloSimulacion.start();
  hiloEnvio = new HiloEnvio();                     // manda el estado al cliente
  hiloEnvio.start();

  pantalla = PARTIDA;
}


String buscarServidorEnRed() {
  try {
    DatagramSocket socket = new DatagramSocket();
    socket.setBroadcast(true);     // permite "gritar" a toda la red

    byte[] mensaje = "HAY_SERVER?".getBytes();

    // 255.255.255.255 = broadcast: le llega a todas las PCs de la red
    try {
      DatagramPacket paqueteEnvio = new DatagramPacket(mensaje, mensaje.length, InetAddress.getByName("255.255.255.255"), PUERTO_UDP);
      socket.send(paqueteEnvio);
    } catch (Exception e) {
      // Algunas redes no permiten broadcast: seguimos igual
    }

    // Extra (para probar con 2 programas en la MISMA computadora):
    // también le preguntamos a "esta misma PC" (127.0.0.1)
    try {
      DatagramPacket paqueteLocal = new DatagramPacket(mensaje, mensaje.length, InetAddress.getByName("127.0.0.1"), PUERTO_UDP);
      socket.send(paqueteLocal);
    } catch (Exception e) {
    }

    // Esperamos la respuesta máximo 1,5 segundos
    socket.setSoTimeout(1500);
    byte[] bufferRecepcion = new byte[1024];
    DatagramPacket paqueteRespuesta = new DatagramPacket(bufferRecepcion, bufferRecepcion.length);
    socket.receive(paqueteRespuesta);   // si nadie responde, salta al catch

    String ipDescubierta = paqueteRespuesta.getAddress().getHostAddress();
    socket.close();
    return ipDescubierta;

  } catch (Exception e) {
    // Pasó el tiempo y nadie respondió: no hay servidor en la red
    return null;
  }
}



void enviarAlServidor(String mensaje) {
  synchronized(candadoEnvio) {
    if (c != null) c.write(mensaje);
  }
}

void enviarAlRemoto(String mensaje) {
  synchronized(candadoEnvio) {
    if (s != null) s.write(mensaje);
  }
}

// El cliente avisa hacia dónde se quiere mover
void enviarInputAlServidor() {
  enviarAlServidor("INPUT " + miDx + " " + miDy + "\n");
}

// El servidor manda el estado completo al cliente
void enviarEstadoAlCliente() {
  if (clienteRemoto == null) return;
  String texto;
  synchronized(candado) {
    texto = construirEstado();
  }
  enviarAlRemoto(texto);
}

// Arma el texto con TODO el estado del juego. Se llama dentro de un
// synchronized(candado) para que nadie cambie los datos a la mitad.
String construirEstado() {
  Partida p = partida;
  StringBuilder sb = new StringBuilder();
  sb.append("E");

  // H = encabezado
  sb.append(";H").append(p.fase).append(" ").append(p.ronda).append(" ");
  sb.append(p.victorias[0]).append(" ").append(p.victorias[1]).append(" ");
  sb.append(ceil(p.tiempo)).append(" ").append(p.ganadorRonda).append(" ");
  sb.append(p.ganadorPartida).append(" ").append(p.desconexion ? 1 : 0);

  // M = mapa
  sb.append(";M").append(p.mapa.comoTexto());

  // J = jugadores   x:y:vivo:alcance:maxBombas:nivelVel:remoto:mirada
  sb.append(";J");
  for (int i = 0; i < 2; i++) {
    Jugador j = p.jugadores[i];
    if (i > 0) sb.append(",");
    sb.append((int) j.pos.x).append(":").append((int) j.pos.y).append(":");
    sb.append(j.vivo ? 1 : 0).append(":").append(j.alcance).append(":");
    sb.append(j.maxBombas).append(":").append(j.nivelVel).append(":");
    sb.append(j.remoto ? 1 : 0).append(":").append(j.mirada);
  }

  // B = bombas   columna:fila:dueño:remota
  sb.append(";B");
  for (int i = 0; i < p.bombas.size(); i++) {
    Bomba b = p.bombas.get(i);
    if (i > 0) sb.append(",");
    sb.append(b.col).append(":").append(b.fila).append(":");
    sb.append(b.duenio).append(":").append(b.remota ? 1 : 0);
  }

  // X = celdas con fuego   columna:fila
  sb.append(";X");
  boolean primero = true;
  for (Explosion e : p.explosiones) {
    for (int[] celda : e.celdas) {
      if (!primero) sb.append(",");
      sb.append(celda[0]).append(":").append(celda[1]);
      primero = false;
    }
  }

  // P = power-ups   columna:fila:tipo
  sb.append(";P");
  for (int i = 0; i < p.powerUps.size(); i++) {
    PowerUp pu = p.powerUps.get(i);
    if (i > 0) sb.append(",");
    sb.append(pu.col).append(":").append(pu.fila).append(":").append(pu.tipo);
  }

  // V = eventos para los efectos (se mandan una sola vez y se borran)
  sb.append(";V");
  for (int i = 0; i < eventosRemotos.size(); i++) {
    int[] ev = eventosRemotos.get(i);
    if (i > 0) sb.append(",");
    sb.append(ev[0]).append(":").append(ev[1]).append(":").append(ev[2]);
  }
  eventosRemotos.clear();

  sb.append("\n");
  return sb.toString();
}


void leerComoServidor() {
  Client entrante = s.available();
  if (entrante != null) {
    while (entrante.available() > 0) {
      String linea = entrante.readStringUntil('\n');
      if (linea == null) break;
      procesarMensajeServidor(entrante, trim(linea));
    }
  }
}

void procesarMensajeServidor(Client quien, String linea) {
  if (linea.length() == 0) return;

  // El primero que dice HOLA es el jugador 2. Si aparece un tercero, lo echamos.
  if (linea.equals("HOLA")) {
    if (clienteRemoto == null) {
      clienteRemoto = quien;
      ultimoMensajeRemoto = millis();
      println("Jugador 2 conectado.");
    } else if (clienteRemoto != quien) {
      s.disconnect(quien);
    }
    return;
  }

  // Ignoramos a cualquiera que no sea el jugador 2
  if (quien != clienteRemoto) return;
  ultimoMensajeRemoto = millis();

  String[] partes = split(linea, ' ');

  if (partes[0].equals("INPUT") && partes.length == 3) {
    int dx = constrain(int(partes[1]), -1, 1);
    int dy = constrain(int(partes[2]), -1, 1);
    synchronized(candado) {
      partida.jugadores[1].dirX = dx;
      partida.jugadores[1].dirY = dy;
    }
  } else if (partes[0].equals("BOMBA")) {
    synchronized(candado) {
      partida.jugadores[1].pideBomba = true;
    }
  } else if (partes[0].equals("DETONAR")) {
    synchronized(candado) {
      partida.jugadores[1].pideDetonar = true;
    }
  }
}

// CLIENTE: lee lo que mandó el servidor
void leerComoCliente() {
  if (c.available() > 0) {
    String linea = c.readStringUntil('\n');
    while (linea != null) {
      procesarMensajeCliente(trim(linea));
      linea = c.readStringUntil('\n');
    }
  }

  // Si pasan 3 segundos sin noticias del servidor, asumimos que se cayó
  if (!rivalDesconectado && millis() - ultimoEstadoRecibido > 3000) {
    rivalDesconectado = true;
    println("El servidor dejó de responder.");
    synchronized(candado) {
      partida.fase = FIN_PARTIDA;
      partida.ganadorPartida = miId;
      partida.desconexion = true;
    }
  }
}

void procesarMensajeCliente(String linea) {
  if (linea.length() == 0) return;
  if (linea.charAt(0) == 'E') {
    procesarEstado(linea);
  }
}

// Desarma el texto del estado y actualiza la copia del juego del cliente
void procesarEstado(String linea) {
  ultimoEstadoRecibido = millis();
  String[] secciones = linea.split(";", -1);

  synchronized(candado) {
    for (int i = 0; i < secciones.length; i++) {
      String sec = secciones[i];
      if (sec.length() == 0) continue;
      char tipo = sec.charAt(0);
      String datos = sec.substring(1);

      if (tipo == 'H') {
        int[] h = int(split(datos, ' '));
        if (h.length >= 8) {
          partida.fase = h[0];
          partida.ronda = h[1];
          partida.victorias[0] = h[2];
          partida.victorias[1] = h[3];
          partida.tiempo = h[4];
          partida.ganadorRonda = h[5];
          partida.ganadorPartida = h[6];
          partida.desconexion = (h[7] == 1);
        }

      } else if (tipo == 'M') {
        partida.mapa.desdeTexto(datos);

      } else if (tipo == 'J') {
        String[] js = split(datos, ',');
        for (int k = 0; k < js.length && k < 2; k++) {
          int[] f = int(split(js[k], ':'));
          if (f.length >= 8) {
            Jugador j = partida.jugadores[k];
            j.destino.set(f[0], f[1]);
            j.vivo = (f[2] == 1);
            j.alcance = f[3];
            j.maxBombas = f[4];
            j.nivelVel = f[5];
            j.remoto = (f[6] == 1);
            j.mirada = f[7];
          }
        }

      } else if (tipo == 'B') {
        partida.bombas.clear();
        if (datos.length() > 0) {
          String[] items = split(datos, ',');
          for (int k = 0; k < items.length; k++) {
            int[] f = int(split(items[k], ':'));
            if (f.length >= 4) {
              partida.bombas.add(new Bomba(f[0], f[1], f[2], 0, f[3] == 1));
            }
          }
        }

      } else if (tipo == 'X') {
        partida.explosiones.clear();
        if (datos.length() > 0) {
          Explosion e = new Explosion();
          String[] items = split(datos, ',');
          for (int k = 0; k < items.length; k++) {
            int[] f = int(split(items[k], ':'));
            if (f.length >= 2) e.agregar(f[0], f[1]);
          }
          partida.explosiones.add(e);
        }

      } else if (tipo == 'P') {
        partida.powerUps.clear();
        if (datos.length() > 0) {
          String[] items = split(datos, ',');
          for (int k = 0; k < items.length; k++) {
            int[] f = int(split(items[k], ':'));
            if (f.length >= 3) partida.powerUps.add(new PowerUp(f[0], f[1], f[2]));
          }
        }

      } else if (tipo == 'V') {
        if (datos.length() > 0) {
          String[] items = split(datos, ',');
          for (int k = 0; k < items.length; k++) {
            int[] f = int(split(items[k], ':'));
            if (f.length >= 3) eventosLocales.add(new int[] {f[0], f[1], f[2]});
          }
        }
      }
    }
  }
}

// Guarda un evento para los efectos visuales (se llama con el candado ya tomado)
void evento(int tipo, int col, int fila) {
  int[] ev = {tipo, col, fila};
  eventosLocales.add(ev);                         // para mis propias partículas
  if (clienteRemoto != null) eventosRemotos.add(ev);   // y para las del cliente
}
