# Plano: setup do projeto Gamejam+ (Godot 4.7, top-down twin-stick)

## Contexto
Projeto Godot 4.7 vazio, para um jogo top-down 2D de tiro twin-stick em uma gamejam de 48-72h, com time de 2-5 pessoas. O setup deve entregar uma base rodável (menu → jogo → pause) com player, tiro, autoloads e convenções, minimizando conflitos de merge em cenas.

## Decisões
- 2D pixel art, sprites 32x32, resolução base **640x360** (ajustável), filtro `Nearest`
- Combate: tiro twin-stick (mouse + analógico direito)
- Pastas **por feature**
- Strings **diretas** (sem tr()/CSV)
- Sistemas: player 8 direções, autoloads EventBus + GameManager, menu/pause/troca de cenas, AudioManager
- Tipagem forte, `@export` para valores de balanceamento, prints `[Area] - mensagem`

## Estrutura de pastas
```
res://
  autoloads/   event_bus.gd, game_manager.gd, scene_manager.gd, audio_manager.gd
  player/      player.tscn/.gd (CharacterBody2D), weapon (spawn de projéteis)
  projectiles/ bullet.tscn/.gd (Area2D)
  enemies/     enemy_base.tscn/.gd (placeholder, persegue o player)
  components/  health_component, hitbox/hurtbox (reutilizáveis)
  ui/          main_menu, pause_menu, hud (cena+script juntos)
  levels/      main_level.tscn (TileMapLayer + câmera + spawn)
  assets/      sprites/, audio/ (música e sfx), fonts/
```

## Passos
1. **project.godot**: viewport 640x360, stretch `canvas_items`, filtro `Nearest`, main scene = menu, autoloads, physics layers nomeadas (world, player, enemy, player_bullet, enemy_bullet), Input Map: `move_*` (WASD+setas+analógico esquerdo), `shoot` (mouse esquerdo + RT), `aim_*` (analógico direito), `pause` (Esc/Start).
2. **Autoloads**:
   - `EventBus`: apenas sinais tipados (`player_died`, `enemy_killed(points)`, `game_paused(bool)`, `scene_change_requested(path)`, `play_sfx_requested(name)`).
   - `GameManager`: estado (MENU/PLAYING/PAUSED/GAME_OVER), pontuação, pausa via `get_tree().paused`.
   - `SceneManager`: troca de cena com fade (CanvasLayer + ColorRect + Tween).
   - `AudioManager`: buses Music/SFX, `play_music()`, `play_sfx()` com pool de AudioStreamPlayer.
3. **Player**: movimento 8 direções com `Input.get_vector`, aceleração/atrito via `@export`, mira por mouse ou analógico, tiro com cooldown instanciando `bullet.tscn`; sprite placeholder 32x32.
4. **Componentes**: `HealthComponent` (sinais `died`, `damaged`), `Hitbox`/`Hurtbox` por Area2D com layers.
5. **Inimigo base** placeholder + spawner simples no level.
6. **UI**: menu principal (Jogar/Sair), pause menu (`PROCESS_MODE_ALWAYS`), HUD com vida/pontuação, ligados por EventBus.
7. **Repositório**: ajustar `.gitignore`, `README.md` curto com convenções (commits `[Tipo] - Título`, branches por feature, não editar a mesma `.tscn` em paralelo), primeiro commit.

## Delegação de modelos e esforço (foco em custo-benefício de tokens)
Princípio: o modelo mais barato que resolve a tarefa; subagentes recebem contexto mínimo (caminhos + contrato do arquivo), sem reler o repo; a sessão principal (Sonnet 5.5) coordena e integra.

| # | Tarefa | Modelo | Esforço | Por quê |
|---|--------|--------|---------|---------|
| 1 | `project.godot` (resolução, filtro, layers, Input Map), `.gitignore`, README | Haiku 5.5 | low | Config declarativa, sem lógica |
| 2 | Autoloads `EventBus`, `AudioManager` | Haiku 5.5 | low | Sinais tipados e pool de players, padrão conhecido |
| 3 | `GameManager`, `SceneManager` (fade com Tween) | Sonnet 5.5 | low | Pouca lógica, mas interdependente com pausa/árvore |
| 4 | Player (movimento, mira, tiro, cooldown) + `bullet` | Sonnet 5.5 | medium | Núcleo do game feel; precisa acertar de primeira |
| 5 | `HealthComponent`, `Hitbox`/`Hurtbox`, inimigo base + spawner | Sonnet 5.5 | low | Padrão simples, bem especificado |
| 6 | UI: menu, pause, HUD | Haiku 5.5 | low | Cenas e sinais diretos; Sonnet só se a pausa der bug |
| 7 | Verificação (run_project + debug output) e correções | Haiku 5.5 → Sonnet 5.5 se falhar | low | Escala só em caso de falha |
| 8 | Revisão final de arquitetura/guideline (opcional) | Opus 5.5 | medium | Uma única passada no diff final |

Regras de economia:
- Fable 5.1 não é usado (custo sem ganho para um setup).
- Opus apenas na revisão final, ou se houver bug de arquitetura que Sonnet não resolva.
- Tarefas 1, 2 e 6 são independentes e podem rodar em paralelo; 3→4→5 em sequência.
- Cada subagente recebe só: arquivos a criar, sinais do EventBus que usa e convenções (tipagem forte, `@export`, `[Area] - msg`).
- Não reler arquivos já escritos; verificar via `get_debug_output` em vez de ler cenas inteiras.
- Evitar editar `.tscn` à mão em paralelo; criar cenas via MCP Godot (`create_scene`, `add_node`).

## Verificação
- `get_project_info` e `run_project` para abrir o jogo; `get_debug_output` sem erros/warnings.
- Manual: menu → Jogar (fade) → mover em 8 direções, atirar com mouse e gamepad, Esc pausa/retoma, inimigo toma dano e morre, pontuação sobe no HUD, voltar ao menu.
