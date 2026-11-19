
//  BOMBERMAN LAN  -  Proyecto de Programación sobre Redes
//  Juego de 2 jugadores en red local (2 computadoras o 2 programas)


import processing.net.*;
import java.net.*;     // para el descubrimiento por UDP

final int ANCHO_CANVAS = 720;   // 15*48 = 720 de ancho fijo sin estirar
final int ALTO_CANVAS = 684;    // 13*48 + 60 = 684 de alto fijo sin estirar
int offsetX = 0;                // margen izquierdo para centrar el canvas
int offsetY = 0;                // margen superior para centrar el canvas

final int COLS = 15;        // columnas del mapa
final int FILAS = 13;       // filas del mapa
final int TAM = 48;         // tamaño de cada celda en píxeles
final int OFFSET_Y = 60;    // espacio arriba para el marcador (HUD)

// Contenido de una celda del mapa
final int VACIO = 0;
final int MURO = 1;         // muro fijo (no se rompe)
final int BLOQUE = 2;       // bloque destructible

final int PUERTO_TCP = 12345;   // puerto del juego (TCP)
final int PUERTO_UDP = 8888;    // puerto para buscar servidores (UDP)

// Pantallas del programa
final int MENU = 0;
final int BUSCANDO = 1;
final int PARTIDA = 2;

// Fases dentro de una partida
final int LOBBY = 0;        
final int CUENTA = 1;     
final int JUEGO = 2;       
final int FIN_RONDA = 3;   
final int FIN_PARTIDA = 4;  

final float MEDIO_HITBOX = 15;  

// Botones del menú
final int BTN_X = 180;
final int BTN_W = 360;
final int BTN_H = 50;


//  VARIABLES GLOBALES

volatile int pantalla = MENU;
volatile String mensajeMenu = "";
int modoElegido = 0;            
String ipEscrita = "";
boolean campoIPActivo = false;

boolean esServidor = false;
int miId = 0;                  
String serverIP = "";

Server s = null;                // objeto Server (solo si soy servidor)
Client c = null;                // objeto Client (solo si soy cliente)

// Datos de red compartidos entre hilos
volatile Client clienteRemoto = null;     
volatile int ultimoMensajeRemoto = 0;     
volatile int ultimoEstadoRecibido = 0;    
volatile boolean rivalDesconectado = false;


volatile boolean corriendo = true;


Object candado = new Object();        
Object candadoEnvio = new Object();   

Partida partida;                     
SistemaParticulas particulas;


ArrayList<int[]> eventosLocales = new ArrayList<int[]>(); 
ArrayList<int[]> eventosRemotos = new ArrayList<int[]>();  


HiloDescubrimiento hiloDescubrimiento;
HiloRed hiloRed;
HiloSimulacion hiloSimulacion;
HiloEnvio hiloEnvio;


volatile int miDx = 0;
volatile int miDy = 0;
boolean[] teclaDir = new boolean[4];  
int ultimaDir = -1;
boolean espacioApretado = false;   
boolean eApretada = false;        


void setup() {
  fullScreen();
  frameRate(60);
  surface.setTitle("Bomberman LAN");
  partida = new Partida();
  particulas = new SistemaParticulas();
}

void draw() {
  background(12, 14, 24); // Fondo oscuro que rellena toda la pantalla

  // Centramos el canvas de 720x684 sin estirarlo
  offsetX = (width - ANCHO_CANVAS) / 2;
  offsetY = (height - ALTO_CANVAS) / 2;

  pushMatrix();
  translate(offsetX, offsetY);

 
  clip(0, 0, ANCHO_CANVAS, ALTO_CANVAS);

  if (pantalla == MENU) {
    dibujarMenu();
  } else if (pantalla == BUSCANDO) {
    dibujarBuscando();
  } else {
    dibujarPartida();
  }

  noClip();

  // Borde exterior alrededor del canvas
  noFill();
  stroke(70, 110, 200);
  strokeWeight(4);
  rect(-2, -2, ANCHO_CANVAS + 4, ALTO_CANVAS + 4, 10);

  popMatrix();
}


void exit() {
  println("Cerrando el programa. Avisando a los hilos...");
  corriendo = false;
  delay(200);
  if (c != null) c.stop();
  if (s != null) s.stop();
  super.exit();
}


boolean sobre(int x, int y, int ancho, int alto) {
  int mx = mouseX - offsetX;
  int my = mouseY - offsetY;
  return mx >= x && mx <= x + ancho && my >= y && my <= y + alto;
}

void mousePressed() {
  if (pantalla != MENU) return;
  campoIPActivo = false;
  if (sobre(BTN_X, 220, BTN_W, BTN_H)) {
    lanzarConexion(0);
  } else if (sobre(BTN_X, 290, BTN_W, BTN_H)) {
    lanzarConexion(1);
  } else if (sobre(BTN_X, 365, BTN_W, 44)) {
    campoIPActivo = true;
  } else if (sobre(BTN_X, 420, BTN_W, BTN_H)) {
    if (ipEscrita.length() > 0) {
      lanzarConexion(2);
    } else {
      mensajeMenu = "Primero escribí la IP del servidor.";
    }
  }
}

void keyPressed() {
  if (pantalla == MENU) {
    teclasDelMenu();
    return;
  }
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
    enviarAlServidor("BOMBA\n");
  }
}

void pedirDetonar() {
  if (esServidor) {
    synchronized(candado) {
      partida.jugadores[0].pideDetonar = true;
    }
  } else {
    enviarAlServidor("DETONAR\n");
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

void teclasDelMenu() {
  if (campoIPActivo) {
    if (key == BACKSPACE) {
      if (ipEscrita.length() > 0) ipEscrita = ipEscrita.substring(0, ipEscrita.length() - 1);
    } else if ((key >= '0' && key <= '9') || key == '.') {
      if (ipEscrita.length() < 15) ipEscrita = ipEscrita + key;
    } else if (key == ENTER || key == RETURN) {
      if (ipEscrita.length() > 0) lanzarConexion(2);
    }
  } else if (key == ENTER || key == RETURN) {
    lanzarConexion(0);
  }
}
