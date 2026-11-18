
//  RED: Descubrimiento UDP y comunicación Cliente-Servidor por TCP


void lanzarConexion(int modo) {
  modoElegido = modo;
  pantalla = BUSCANDO;
  thread("conectar");
}

void conectar() {
  mensajeMenu = "";
  String ip = null;

  if (modoElegido == 0) {
    ip = buscarServidorEnRed();
  } else if (modoElegido == 2) {
    ip = ipEscrita;
  }

  if (ip != null) {
    iniciarComoCliente(ip);
  } else {
    iniciarComoServidor();
  }
}

void iniciarComoCliente(String ip) {
  esServidor = false;
  miId = 1;
  idCliente = int(random(1, 1000000));
  serverIP = ip;

  c = new Client(this, ip, PUERTO_TCP);

  if (!c.active()) {
    println("No se pudo conectar al servidor, iniciando como servidor...");
    c = null;
    iniciarComoServidor();
    return;
  }

  surface.setTitle("Bomberman LAN - CLIENTE (Jugador 2)");
  partida = new Partida();
  ultimoEstadoRecibido = millis();
  rivalDesconectado = false;
  corriendo = true;

  hiloRed = new HiloRed();
  hiloRed.start();
  hiloEnvio = new HiloEnvio();
  hiloEnvio.start();

  enviarAlServidor(Protocolo.armarHola(idCliente));
  pantalla = PARTIDA;
}

void iniciarComoServidor() {
  esServidor = true;
  miId = 0;
  idCliente = 0;

  s = new Server(this, PUERTO_TCP);

  if (!s.active()) {
    println("No se pudo crear el servidor (puerto ocupado).");
    s = null;
    return;
  }

  surface.setTitle("Bomberman LAN - SERVIDOR (Jugador 1)");
  partida = new Partida();
  clienteRemoto = null;
  idClienteRegistrado = -1;
  rivalDesconectado = false;
  corriendo = true;

  hiloDescubrimiento = new HiloDescubrimiento();
  hiloDescubrimiento.start();
  hiloRed = new HiloRed();
  hiloRed.start();
  hiloSimulacion = new HiloSimulacion();
  hiloSimulacion.start();
  hiloEnvio = new HiloEnvio();
  hiloEnvio.start();

  pantalla = PARTIDA;
}

String buscarServidorEnRed() {
  try {
    DatagramSocket socket = new DatagramSocket();
    socket.setBroadcast(true);
    byte[] mensaje = "HAY_SERVER?".getBytes();

    try {
      DatagramPacket pRed = new DatagramPacket(mensaje, mensaje.length, InetAddress.getByName("255.255.255.255"), PUERTO_UDP);
      socket.send(pRed);
    } catch (Exception e) {}

    try {
      DatagramPacket pLocal = new DatagramPacket(mensaje, mensaje.length, InetAddress.getByName("127.0.0.1"), PUERTO_UDP);
      socket.send(pLocal);
    } catch (Exception e) {}

    socket.setSoTimeout(1500);
    byte[] buffer = new byte[1024];
    DatagramPacket respuesta = new DatagramPacket(buffer, buffer.length);
    socket.receive(respuesta);

    String textoResp = new String(respuesta.getData(), 0, respuesta.getLength());
    String ipDescubierta = respuesta.getAddress().getHostAddress();
    socket.close();

    if (textoResp.equals("ESTOY")) return ipDescubierta;
    return null;
  } catch (Exception e) {
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

void enviarInputAlServidor() {
  enviarAlServidor(Protocolo.armarInput(idCliente, miDx, miDy));
}

void enviarEstadoAlCliente() {
  if (clienteRemoto == null) return;
  String texto;
  synchronized(candado) {
    texto = construirEstado();
  }
  enviarAlRemoto(texto);
}

String construirEstado() {
  Partida p = partida;
  StringBuilder sb = new StringBuilder();
  sb.append("ESTADO;").append(idClienteRegistrado).append(";0;");

  sb.append(p.fase).append(":").append(p.ronda).append(":");
  sb.append(p.victorias[0]).append(":").append(p.victorias[1]).append(":");
  sb.append(ceil(p.tiempo)).append(":").append(p.ganadorRonda).append(":");
  sb.append(p.ganadorPartida).append(":").append(p.desconexion ? 1 : 0).append(";");

  sb.append(p.mapa.comoTexto()).append(";");

  for (int i = 0; i < 2; i++) {
    Jugador j = p.jugadores[i];
    if (i > 0) sb.append(",");
    sb.append((int) j.pos.x).append(":").append((int) j.pos.y).append(":");
    sb.append(j.vivo ? 1 : 0).append(":").append(j.alcance).append(":");
    sb.append(j.maxBombas).append(":").append(j.nivelVel).append(":");
    sb.append(j.remoto ? 1 : 0).append(":").append(j.mirada);
  }
  sb.append(";");

  for (int i = 0; i < p.bombas.size(); i++) {
    Bomba b = p.bombas.get(i);
    if (i > 0) sb.append(",");
    sb.append(b.col).append(":").append(b.fila).append(":");
    sb.append(b.duenio).append(":").append(b.remota ? 1 : 0);
  }
  sb.append(";");

  boolean primero = true;
  for (Explosion e : p.explosiones) {
    for (int[] celda : e.celdas) {
      if (!primero) sb.append(",");
      sb.append(celda[0]).append(":").append(celda[1]);
      primero = false;
    }
  }
  sb.append(";");

  for (int i = 0; i < p.powerUps.size(); i++) {
    PowerUp pu = p.powerUps.get(i);
    if (i > 0) sb.append(",");
    sb.append(pu.col).append(":").append(pu.fila).append(":").append(pu.tipo);
  }
  sb.append(";");

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
  String[] partes = split(linea, ';');
  if (partes.length < 3) return;

  String tipo = partes[0];
  int idCliMsg = int(partes[1]);

  if (tipo.equals("HOLA")) {
    if (clienteRemoto == null) {
      clienteRemoto = quien;
      idClienteRegistrado = idCliMsg;
      ultimoMensajeRemoto = millis();
    } else if (clienteRemoto != quien) {
      s.disconnect(quien);
    }
    return;
  }

  if (quien != clienteRemoto || idCliMsg != idClienteRegistrado) return;
  ultimoMensajeRemoto = millis();

  if (tipo.equals("INPUT") && partes.length >= 5) {
    int dx = constrain(int(partes[3]), -1, 1);
    int dy = constrain(int(partes[4]), -1, 1);
    synchronized(candado) {
      partida.jugadores[1].dirX = dx;
      partida.jugadores[1].dirY = dy;
    }
  } else if (tipo.equals("BOMBA")) {
    synchronized(candado) {
      partida.jugadores[1].pideBomba = true;
    }
  } else if (tipo.equals("DETONAR")) {
    synchronized(candado) {
      partida.jugadores[1].pideDetonar = true;
    }
  }
}

void leerComoCliente() {
  if (c.available() > 0) {
    String linea = c.readStringUntil('\n');
    while (linea != null) {
      procesarMensajeCliente(trim(linea));
      linea = c.readStringUntil('\n');
    }
  }

  if (!rivalDesconectado && millis() - ultimoEstadoRecibido > 3000) {
    rivalDesconectado = true;
    synchronized(candado) {
      partida.fase = FIN_PARTIDA;
      partida.ganadorPartida = miId;
      partida.desconexion = true;
    }
  }
}

void procesarMensajeCliente(String linea) {
  if (linea.length() == 0) return;
  String[] sec = linea.split(";", -1);
  if (sec.length < 10 || !sec[0].equals("ESTADO")) return;

  int idDestino = int(sec[1]);
  if (idDestino != idCliente) return;

  ultimoEstadoRecibido = millis();

  synchronized(candado) {
    int[] h = int(split(sec[3], ':'));
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

    partida.mapa.desdeTexto(sec[4]);

    String[] js = split(sec[5], ',');
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

    partida.bombas.clear();
    if (sec[6].length() > 0) {
      String[] items = split(sec[6], ',');
      for (int k = 0; k < items.length; k++) {
        int[] f = int(split(items[k], ':'));
        if (f.length >= 4) partida.bombas.add(new Bomba(f[0], f[1], f[2], 0, f[3] == 1));
      }
    }

    partida.explosiones.clear();
    if (sec[7].length() > 0) {
      Explosion e = new Explosion();
      String[] items = split(sec[7], ',');
      for (int k = 0; k < items.length; k++) {
        int[] f = int(split(items[k], ':'));
        if (f.length >= 2) e.agregar(f[0], f[1]);
      }
      partida.explosiones.add(e);
    }

    partida.powerUps.clear();
    if (sec[8].length() > 0) {
      String[] items = split(sec[8], ',');
      for (int k = 0; k < items.length; k++) {
        int[] f = int(split(items[k], ':'));
        if (f.length >= 3) partida.powerUps.add(new PowerUp(f[0], f[1], f[2]));
      }
    }

    if (sec[9].length() > 0) {
      String[] items = split(sec[9], ',');
      for (int k = 0; k < items.length; k++) {
        int[] f = int(split(items[k], ':'));
        if (f.length >= 3) eventosLocales.add(new int[] {f[0], f[1], f[2]});
      }
    }
  }
}

void evento(int tipo, int col, int fila) {
  int[] ev = {tipo, col, fila};
  eventosLocales.add(ev);
  if (clienteRemoto != null) eventosRemotos.add(ev);
}
