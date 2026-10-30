# Gamejam+

Jogo 2D pixel art top-down twin-stick (sprites 32x32), feito em Godot 4.7.

## Como abrir

1. Instale o Godot 4.7.
2. Abra o Godot e clique em **Importar**.
3. Selecione a pasta `project.godot` deste repositório.
4. Pressione **F5** para rodar.

## Estrutura de pastas

Organização por feature:

```
autoloads/    Singletons globais (EventBus, GameManager, SceneManager, AudioManager)
player/       Player e seus componentes de controle
projectiles/  Balas e projéteis
enemies/      Inimigos
components/   Componentes reutilizáveis (vida, hitbox, etc.)
ui/           Menus e HUD
levels/       Fases
assets/       Sprites, sons, fontes e demais recursos
```

## Convenções

- **Commits:** `[Tipo] - Título` (ex.: `[Feat] - Adiciona dash do player`).
- **Branches:** uma branch por feature, criada a partir de `main`.
- **Cenas `.tscn`:** não editar a mesma cena em paralelo com outra pessoa, para evitar conflitos de merge.
- **GDScript:** tipagem forte em variáveis, parâmetros e retornos.
- **Balanceamento:** valores de balanceamento (velocidade, dano, cooldown, etc.) expostos com `@export`.
- **Debug:** prints no formato `[Area] - mensagem` (ex.: `print("[Player] - dash iniciado")`).
- **Comunicação entre sistemas:** via `EventBus`, evitando referências diretas entre features.
