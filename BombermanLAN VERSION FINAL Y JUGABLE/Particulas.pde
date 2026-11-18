
//  PARTÍCULAS: Efectos visuales con PVector (fuego, escombros, brillo, muerte)


class Particula {
  PVector pos, vel, acc;
  float vida, vidaMax, tam;
  color col;

  Particula(float x, float y, float vx, float vy, float ax, float ay, color col, float vida, float tam) {
    pos = new PVector(x, y);
    vel = new PVector(vx, vy);
    acc = new PVector(ax, ay);
    this.col = col;
    this.vida = vida;
    this.vidaMax = vida;
    this.tam = tam;
  }

  void actualizar() {
    vel.add(acc);
    pos.add(vel);
    vida -= 1;
  }

  boolean muerta() {
    return vida <= 0;
  }

  void dibujar() {
    float transparencia = map(vida, 0, vidaMax, 0, 255);
    fill(red(col), green(col), blue(col), transparencia);
    noStroke();
    float t = tam * (0.4 + 0.6 * vida / vidaMax);
    rect(pos.x - t / 2, pos.y - t / 2, t, t);
  }
}

class SistemaParticulas {
  ArrayList<Particula> lista = new ArrayList<Particula>();

  void fuego(int col, int fila) {
    float cx = (col + 0.5) * TAM;
    float cy = (fila + 0.5) * TAM;
    for (int i = 0; i < 6; i++) {
      lista.add(new Particula(cx + random(-12, 12), cy + random(-12, 12),
                              random(-1.5, 1.5), random(-2.5, 0.5), 0, 0.03,
                              color(255, random(90, 230), 20), random(15, 30), random(5, 10)));
    }
  }

  void escombros(int col, int fila) {
    float cx = (col + 0.5) * TAM;
    float cy = (fila + 0.5) * TAM;
    for (int i = 0; i < 12; i++) {
      lista.add(new Particula(cx + random(-14, 14), cy + random(-14, 14),
                              random(-3, 3), random(-4, -1), 0, 0.25,
                              color(random(120, 190), random(70, 110), 40), random(25, 45), random(5, 9)));
    }
  }

  void brillo(int col, int fila) {
    float cx = (col + 0.5) * TAM;
    float cy = (fila + 0.5) * TAM;
    for (int i = 0; i < 14; i++) {
      lista.add(new Particula(cx, cy, random(-2.5, 2.5), random(-3.5, -0.5), 0, 0.05,
                              color(255, 240, random(80, 200)), random(20, 40), random(4, 8)));
    }
  }

  void muerte(int col, int fila) {
    float cx = (col + 0.5) * TAM;
    float cy = (fila + 0.5) * TAM;
    for (int i = 0; i < 24; i++) {
      lista.add(new Particula(cx, cy, random(-4, 4), random(-5, 1), 0, 0.2,
                              color(255, random(0, 120), random(0, 120)), random(30, 55), random(5, 11)));
    }
  }

  void actualizar() {
    for (int i = lista.size() - 1; i >= 0; i--) {
      Particula p = lista.get(i);
      p.actualizar();
      if (p.muerta()) lista.remove(i);
    }
  }

  void dibujar() {
    for (Particula p : lista) {
      p.dibujar();
    }
  }
}
