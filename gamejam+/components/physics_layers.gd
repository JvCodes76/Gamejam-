class_name PhysicsLayers
extends RefCounted
## Camadas de fisica 2D (valores de bitmask) e mascaras compostas, num unico lugar.
## Altos (arvore, muro, poste, arco, paredes da arena): WORLD (bloqueia movimento e projeteis).
## Baixos (lapide, banco, arbusto, tronco, caldeirao): LOW_OBSTACLE (so movimento; projeteis passam por cima).
## BULLET_BLOCKER e o volume (altura) dos obstaculos altos: so os projeteis enxergam essa camada.

const WORLD: int = 1
const PLAYER: int = 2
const ENEMY: int = 4
const PLAYER_BULLET: int = 8
const ENEMY_BULLET: int = 16
const LOW_OBSTACLE: int = 32
const BULLET_BLOCKER: int = 64

# O que bloqueia o movimento de player, inimigos e fantasmas
const MOVE_MASK: int = WORLD | LOW_OBSTACLE
# O que destroi (ou ricocheteia) um projetil
const PROJECTILE_WALL_MASK: int = WORLD | BULLET_BLOCKER
