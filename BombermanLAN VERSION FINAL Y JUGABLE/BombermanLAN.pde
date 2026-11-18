
import processing.net.*;
import java.net.*;

// CONSTANTES DEL MAPA Y VENTANA
final int COLS = 15;
final int FILAS = 13;
final int TAM = 48;         
final int OFFSET_Y = 60;  

final int VACIO = 0;
final int MURO = 1;          
final int BLOQUE = 2;       

//cONSTANTES DE RED 
final int PUERTO_TCP = 12345;
final int PUERTO_UDP = 8888;

//  ESTADOS DE PANTALLA Y FASES DE PARTIDA 
final int BUSCANDO = 1;
final int PARTIDA = 2;

final int LOBBY = 0;
final int CUENTA = 1;
final int JUEGO = 2;
final int FIN_RONDA = 3;
final int FIN_PARTIDA = 4;

final float MEDIO_HITBOX = 15; // Caja de colisión de 30x30 px

// VARIABLES GLOBALES
volatile int pantalla = BUSCANDO;
volatile String mensajeMenu = "";
int modoElegido = 0;           // 0 = automático siempre
String ipEscrita = "";

boolean esServidor = false;
int miId = 0;                  // 0 = Jugador 1 (Servidor), 1 = Jugador 2 (Cliente)
int idCliente = 0;             // Número al azar entre 1 y 1.000.000
String serverIP = "";

Server s = null;
Client c = null;

//VARIABLES COMPARTIDAS ENTRE HILOS 
volatile Client clienteRemoto = null;
volatile int idClienteRegistrado = -1;
volatile int ultimoMensajeRemoto = 0;
volatile int ultimoEstadoRecibido = 0;
volatile boolean rivalDesconectado = false;
volatile boolean corriendo = true;

// Candados para evitar que dos hilos lean/escriban al mismo tiempo
Object candado = new Object();
Object candadoEnvio = new Object();


Partida partida;
SistemaParticulas particulas;
GestorSprites sprites;


ArrayList<int[]> eventosLocales = new ArrayList<int[]>();
ArrayList<int[]> eventosRemotos = new ArrayList<int[]>();

// Hilos
HiloDescubrimiento hiloDescubrimiento;
HiloRed hiloRed;
HiloSimulacion hiloSimulacion;
HiloEnvio hiloEnvio;

// Control de teclado
volatile int miDx = 0;
volatile int miDy = 0;
boolean[] teclaDir = new boolean[4]; // 0:arriba, 1:abajo, 2:izq, 3:der
int ultimaDir = -1;
boolean espacioApretado = false;
boolean eApretada = false;

void setup() {
  size(720, 684); 
  frameRate(60);
  surface.setTitle("Bomberman LAN - Conectando...");

  partida = new Partida();
  particulas = new SistemaParticulas();
  sprites = new GestorSprites();
  sprites.cargar("sprites.png");

  // Arranca directamente buscando partida o creando el servidor
  lanzarConexion(0);
}

void draw() {
  background(20);
  if (pantalla == BUSCANDO) {
    dibujarBuscando();
  } else {
    dibujarPartida();
  }
}

void exit() {
  corriendo = false;
  delay(200);
  if (c != null) c.stop();
  if (s != null) s.stop();
  super.exit();
}

// --- CONTROL DE TECLADO ---
void keyPressed() {
  if (pantalla != PARTIDA) return;

  if (key == ' ') {
    if (!espacioApretado) pedirBomba();
    espacioApretado = true;
  } else if (key == 'e' || key == 'E') {
    if (!eApretada) pedirDetonar();
    eApretada = true;
  } else if (key == ENTER || key == RETURN) {
    reiniciarPartida();
  }

  int d = direccionDeTecla();
  if (d >= 0) {
    teclaDir[d] = true;
    ultimaDir = d;
    actualizarDireccion();
  }
}

void keyReleased() {
  if (key == ' ') espacioApretado = false;
  if (key == 'e' || key == 'E') eApretada = false;

  int d = direccionDeTecla();
  if (d >= 0) {
    teclaDir[d] = false;
    if (ultimaDir == d) {
      ultimaDir = -1;
      for (int i = 0; i < 4; i++) {
        if (teclaDir[i]) ultimaDir = i;
      }
    }
    actualizarDireccion();
  }
}

int direccionDeTecla() {
  if (key == CODED) {
    if (keyCode == UP) return 0;
    if (keyCode == DOWN) return 1;
    if (keyCode == LEFT) return 2;
    if (keyCode == RIGHT) return 3;
  } else {
    if (key == 'w' || key == 'W') return 0;
    if (key == 's' || key == 'S') return 1;
    if (key == 'a' || key == 'A') return 2;
    if (key == 'd' || key == 'D') return 3;
  }
  return -1;
}

void actualizarDireccion() {
  int nuevoDx = 0;
  int nuevoDy = 0;
  if (ultimaDir == 0) nuevoDy = -1;
  if (ultimaDir == 1) nuevoDy = 1;
  if (ultimaDir == 2) nuevoDx = -1;
  if (ultimaDir == 3) nuevoDx = 1;
  miDx = nuevoDx;
  miDy = nuevoDy;
}

void pedirBomba() {
  if (esServidor) {
    synchronized(candado) {
      partida.jugadores[0].pideBomba = true;
    }
  } else {
    enviarAlServidor(Protocolo.armarBomba(idCliente));
  }
}

void pedirDetonar() {
  if (esServidor) {
    synchronized(candado) {
      partida.jugadores[0].pideDetonar = true;
    }
  } else {
    enviarAlServidor(Protocolo.armarDetonar(idCliente));
  }
}

void reiniciarPartida() {
  if (!esServidor) return;
  synchronized(candado) {
    if (partida.fase == FIN_PARTIDA) {
      if (clienteRemoto != null) {
        partida.nuevaPartida();
      } else {
        partida.irALobby();
      }
    }
  }
}
