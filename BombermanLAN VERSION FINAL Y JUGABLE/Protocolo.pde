
//  PROTOCOLO: Formato estándar de mensajes según la documentación
//  Estructura general: TIPO;idCliente;idServidor;d1;d2;...


static class Protocolo {
  static final int ID_SERVIDOR = 0;

  static String armarHola(int idCli) {
    return "HOLA;" + idCli + ";" + ID_SERVIDOR + "\n";
  }

  static String armarInput(int idCli, int dx, int dy) {
    return "INPUT;" + idCli + ";" + ID_SERVIDOR + ";" + dx + ";" + dy + "\n";
  }

  static String armarBomba(int idCli) {
    return "BOMBA;" + idCli + ";" + ID_SERVIDOR + "\n";
  }

  static String armarDetonar(int idCli) {
    return "DETONAR;" + idCli + ";" + ID_SERVIDOR + "\n";
  }
}
