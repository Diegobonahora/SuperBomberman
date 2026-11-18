
//  HILOS (THREADS): Separan el dibujo de la lógica y la red


class HiloDescubrimiento extends Thread {
  public void run() {
    DatagramSocket socket;
    try {
      socket = new DatagramSocket(PUERTO_UDP);
      socket.setSoTimeout(500);
    } catch (Exception e) {
      return;
    }

    byte[] buffer = new byte[1024];
    while (corriendo) {
      try {
        DatagramPacket paquete = new DatagramPacket(buffer, buffer.length);
        socket.receive(paquete);
        String msg = new String(paquete.getData(), 0, paquete.getLength());
        if (msg.equals("HAY_SERVER?")) {
          byte[] resp = "ESTOY".getBytes();
          DatagramPacket envio = new DatagramPacket(resp, resp.length, paquete.getAddress(), paquete.getPort());
          socket.send(envio);
        }
      } catch (Exception e) {}
    }
    socket.close();
  }
}

class HiloRed extends Thread {
  public void run() {
    while (corriendo) {
      if (esServidor) leerComoServidor();
      else leerComoCliente();
      delay(5);
    }
  }
}

class HiloSimulacion extends Thread {
  public void run() {
    int anterior = millis();
    while (corriendo) {
      int ahora = millis();
      float dt = constrain((ahora - anterior) / 1000.0, 0, 0.05);
      anterior = ahora;

      synchronized(candado) {
        partida.jugadores[0].dirX = miDx;
        partida.jugadores[0].dirY = miDy;
        revisarDesconexionRival();
        partida.actualizar(dt);
      }
      delay(10);
    }
  }
}

void revisarDesconexionRival() {
  if (clienteRemoto != null && millis() - ultimoMensajeRemoto > 3000) {
    s.disconnect(clienteRemoto);
    clienteRemoto = null;
    idClienteRegistrado = -1;
    partida.jugadores[1].dirX = 0;
    partida.jugadores[1].dirY = 0;

    if (partida.fase != LOBBY && partida.fase != FIN_PARTIDA) {
      partida.fase = FIN_PARTIDA;
      partida.ganadorPartida = 0;
      partida.desconexion = true;
    }
  }
}

class HiloEnvio extends Thread {
  public void run() {
    while (corriendo) {
      if (esServidor) enviarEstadoAlCliente();
      else enviarInputAlServidor();
      delay(33);
    }
  }
}
