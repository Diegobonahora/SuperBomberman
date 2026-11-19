
class HiloDescubrimiento extends Thread {

  public void run() {
    DatagramSocket socket;
    try {
      socket = new DatagramSocket(PUERTO_UDP);
      // Cada 0,5 s deja de esperar para poder revisar la bandera 'corriendo'
      socket.setSoTimeout(500);
    } catch (Exception e) {
      println("No se pudo abrir el puerto UDP " + PUERTO_UDP + ": " + e);
      return;
    }

    byte[] bufferRecepcion = new byte[1024];

    while (corriendo) {
      try {
        DatagramPacket paqueteEntrante = new DatagramPacket(bufferRecepcion, bufferRecepcion.length);
        socket.receive(paqueteEntrante);

        String mensaje = new String(paqueteEntrante.getData(), 0, paqueteEntrante.getLength());
        if (mensaje.equals("HAY_SERVER?")) {
          byte[] respuesta = "ESTOY".getBytes();
          DatagramPacket paqueteRespuesta = new DatagramPacket(respuesta, respuesta.length, paqueteEntrante.getAddress(), paqueteEntrante.getPort());
          socket.send(paqueteRespuesta);
        }
      } catch (SocketTimeoutException e) {
        // Normal: pasó medio segundo sin mensajes. Volvemos a revisar 'corriendo'.
      } catch (Exception e) {
        // Cualquier otro error de red lo ignoramos
      }
    }
    socket.close();
  }
}



class HiloRed extends Thread {

  public void run() {
    while (corriendo) {
      if (esServidor) {
        leerComoServidor();
      } else {
        leerComoCliente();
      }
      delay(5);    
    }
  }
}



class HiloSimulacion extends Thread {

  public void run() {
    int anterior = millis();

    while (corriendo) {
      int ahora = millis();
      float dt = (ahora - anterior) / 1000.0;   
      anterior = ahora;
      dt = constrain(dt, 0, 0.05);

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
    println("El jugador 2 se desconectó.");
    s.disconnect(clienteRemoto);
    clienteRemoto = null;
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
      if (esServidor) {
        enviarEstadoAlCliente();
      } else {
        enviarInputAlServidor();
      }
      delay(33);
    }
  }
}
