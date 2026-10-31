# Plano: Game Feel (Gamejam+)

## Contexto
O combate funciona, mas quase não dá feedback: não há áudio (`assets/audio/` não existe), o inimigo não reage ao dano, a morte é um `queue_free()` seco, o player não tem i-frames, não há screen shake nem hitstop, e o HUD é só texto. O sistema de sinergias é rico, mas o jogador não *vê* o que está acontecendo.

**Princípio:** o máximo possível é feito **por código** (shaders, `_draw()`, `CPUParticles2D`, tweens, `Line2D`, `Label`). A equipe de artes entra só onde um sprite melhora muito o resultado. Tudo da Fase 1 funciona sem nenhum asset novo e depois aceita o sprite "por cima", sem reescrever código.

## Arquitetura
- **Novo autoload `Juice`** (`autoloads/juice.gd`): centraliza screen shake (por trauma), hitstop e slow-motion. Escuta o EventBus e nunca é chamado direto pelas features.
- **Novos sinais no `EventBus`:**
  - `screen_shake_requested(trauma: float)`
  - `hitstop_requested(duration: float)`
  - `slowmo_requested(scale: float, duration: float)`
  - `damage_dealt(position: Vector2, amount: int, is_crit: bool, color: Color)`
  - `player_hurt(position: Vector2)`
  - `bullet_hit_wall(position: Vector2, color: Color)`
  - `room_locked()`, `room_cleared()`
  - `item_collected(item_id: StringName, position: Vector2)`
  - `potion_brewed(color: Color, position: Vector2)`
- **Novo componente `HitFeedback`** (`components/hit_feedback.gd`): nó filho reutilizável que escuta o `HealthComponent.damaged` do dono e aplica flash branco, squash e knockback. Serve para inimigos e player.
- **Constantes** em `combat/feel_constants.gd` (no estilo do `combat_constants.gd`). O que é por entidade fica em `@export`.
- **Convenções do projeto:** tipagem forte, prints `[Juice] - mensagem`, comunicação via EventBus.
- **Cenas `.tscn`:** só um agente por vez edita `player.tscn`, `enemy_base.tscn` e `hud.tscn` (ver a ordem abaixo).

---

## Fase 1: agora, sem assets (100% programático)

### F1.1 Base: autoload Juice + sinais
- Screen shake por trauma: `trauma` entre 0 e 1, offset = `trauma²` × amplitude máxima, ruído (`FastNoiseLite`) e decaimento por segundo. Aplica no `offset` da Camera2D do player.
- Hitstop: `Engine.time_scale = 0.0` por N ms, contados em tempo real (`Time.get_ticks_msec`, timer com `ignore_time_scale`). Hitstops simultâneos usam o maior, sem empilhar.
- Slow-motion: `Engine.time_scale` reduzido, com volta suave por tween.
- Opção "Reduzir tremida de tela" (bool no GameManager) para acessibilidade.

### F1.2 Câmera
- `position_smoothing` leve.
- Look-ahead: offset na direção da mira (~25% da distância até o crosshair, com limite em px).
- Recuo de câmera de 1 a 2 px no tiro.

### F1.3 Feedback de acerto no inimigo (`HitFeedback`)
- **Flash branco:** shader `canvas_item` com `uniform float flash` (mix até branco), de 0,06 a 0,1 s. É um shader só para todos os sprites.
- **Squash:** escala (1,25; 0,8), voltando com tween elástico em ~0,12 s.
- **Knockback:** impulso na direção da bala, decaindo por atrito. O `EnemyBase._physics_process` passa a somar `velocity_externa` em vez de sobrescrever `velocity`. Usar `@export var knockback_resistance` (elite e boss resistem mais).
- Partículas pequenas na cor da poção no ponto do acerto (o `ImpactEffect` já cobre isso; só ajustar a intensidade).

### F1.4 Morte do inimigo
- Antes do `queue_free()`: flash branco, pop de escala (cresce e some em ~0,15 s), burst de partículas quadradas na cor do inimigo e alguns "pedaços" (fragmentos do próprio sprite usados como textura das partículas).
- Shake de trauma 0,15 (básico) a 0,5 (elite), mais um hitstop de 40 ms (só para elite e boss, ou em multi-kill).
- Para não quebrar as sinergias, a lógica de `enemy_died` continua sendo emitida na hora; só o visual fica com atraso, em um nó "cadáver" separado.

### F1.5 Dano no player
- **I-frames** de 0,8 s, configurável com `@export`: o `Hurtbox` ignora dano durante esse tempo. Isso resolve vários inimigos causando dano no mesmo frame.
- Piscar: alterna `visible` ou alpha a cada 0,06 s durante os i-frames.
- Flash vermelho no sprite (mesmo shader, com cor parametrizada), shake de 0,4, hitstop de 70 ms e knockback no player.
- Vinheta vermelha na tela: shader em `ColorRect` (CanvasLayer), com alpha caindo em 0,3 s. Fica mais forte com vida baixa (pulsando quando a vida é 1).

### F1.6 Tiro
- **Muzzle flash:** desenhado por `_draw()` (círculo e estrela de 4 pontas na cor da poção) durante 2 frames no `Muzzle`.
- Recuo do sprite: −1 a 2 px na direção da mira, voltando em 0,05 s.
- **Bala:** spawn com escala 1,5 que encolhe para 1,0 em 0,05 s. Rastro com `Line2D` de poucos pontos e alpha decaindo na cor da bala.
- **Bala na parede:** emitir `bullet_hit_wall` com um mini burst e um anel (reusar `ImpactEffect.spawn_burst` em escala menor).

### F1.7 Números de dano flutuantes
- `Label` com fonte pixel do projeto e contorno (outline). Sobe em arco, com um leve espalhamento aleatório em x, e some em 0,6 s.
- Crítico: maior, amarelo/laranja, com "!" e pop de escala, mais hitstop de 30 ms e shake de 0,1.
- DoT: menor, na cor da fonte (veneno verde, raiz marrom...). Agrupar ticks próximos para não poluir a tela.
- Dano negado (Darkness): texto "BLOCK" cinza.
- Pool de labels (máx. ~30) para não pesar com hordas.

### F1.8 Indicadores de status (sinergias visíveis)
- Por código no `StatusEffects` (`_draw()` sobre a cabeça ou partículas contínuas):
  - **Stun:** 3 pontos girando em órbita sobre a cabeça (estrelinhas desenhadas).
  - **Slow:** tinta azulada e partículas caindo.
  - **Marked:** losango vermelho pulsando acima da cabeça.
  - **Veneno/DoT:** bolhas verdes subindo.
  - **Raiz:** linhas marrons no pé.
  - **Charm:** já tem cor; adicionar coraçõezinhos (desenhados com 2 círculos e um triângulo).
- Na Fase 2 viram ícones de sprite (ver requisições de arte).

### F1.9 Spawn com aviso
- No `room_encounter`: antes de instanciar, desenhar um círculo/cruz pulsando no chão por 0,5 s. Depois, spawn com escala de 0 a 1, um pequeno burst e um shake de 0,05.
- O inimigo não causa dano nos primeiros 0,3 s.

### F1.10 Salas
- Ao trancar: tween das portas/barreiras (escala ou queda com bounce), shake de 0,2 e o som "lock".
- Ao limpar: slow-motion de 0,3 por 0,4 s no último kill, flash suave e o texto "SALA LIMPA" que sobe (reusar o estilo do `synergy_announcement`).
- Timer de horda: o label pulsa e fica vermelho nos últimos 5 s.

### F1.11 HUD
- Vida: desenhar corações/blocos por `_draw()` em vez de texto. Ao perder vida, o bloco perdido estoura (partículas), o HUD treme e pisca.
- Pontos: pop de escala a cada ganho e contagem animada (tween do número).
- Rage: barra que enche, com cor pulsando conforme a intensidade.
- Troca de poção: o frasco ativo cresce para 1,2 com bounce, mais um brilho (anel desenhado) e um flash de cor no crosshair.

### F1.12 Interações
- **Pickup:** o item é "sugado" até o player (tween de curva), seguido de um pop, partículas da cor do item e o nome flutuando.
- **Item no chão:** brilho pulsante por shader (já existe outline; adicionar pulso no alpha/brilho).
- **Mímico acordando:** pulo (tween em y), squash, shake de 0,3 e "!" sobre a cabeça.
- **Caldeirão:** bolhas (`CPUParticles2D`) na cor da mistura atual e vapor. Ao criar a poção, um "puff" com `spawn_burst`, flash e shake leve.

### F1.13 Morte do player
- Slow-motion de 0,2, flash branco e câmera parada. O player fica como "cadáver" visual por ~1 s, com burst grande, antes da transição.
- Sem `queue_free()` imediato do visual. `player_died` continua sendo emitido na hora.

### F1.14 Áudio (programadores, sem artes)
- Gerar os SFX com **jsfxr / sfxr** (exportar `.wav` ou `.ogg`) e colocá-los em `assets/audio/sfx/`. O `AudioManager` já carrega por nome.
- `AudioManager.play_sfx`: **variação de pitch aleatória** (±8%), volume por nome e um limite de instâncias do mesmo som por frame (evita estourar em hordas).
- Lista de SFX: `shoot`, `hit`, `crit`, `enemy_die`, `elite_die`, `player_hurt`, `player_die`, `wall_hit`, `pickup`, `potion_swap`, `brew`, `room_lock`, `room_clear`, `mimic_wake`, `synergy`, `ui_click`, `ui_hover`.
- Ducking simples: abaixar a música por 0,2 s em hitstop e morte.
- Música: fora do escopo dos agentes (pedir para quem for compor, ou usar uma faixa livre CC0).

---

## Fase 2: depois dos sprites da arte
Só **troca de visual**. A lógica, os sinais e o timing já existem desde a Fase 1.

| Item | O que muda | Depende de (requisição de arte) |
|------|------------|---------------------------------|
| F2.1 Muzzle flash | `_draw()` vira um sprite animado de 2 a 3 frames | A1 |
| F2.2 Impacto da bala | Anel desenhado + sprite de "splash" | A2 |
| F2.3 Morte de inimigo | Burst + animação de morte por inimigo (se a arte fizer) | A3 |
| F2.4 Ícones de status | Indicadores desenhados viram ícones 8x8 | A4 |
| F2.5 HUD de vida | Blocos desenhados viram corações/frascos em sprite | A5 |
| F2.6 Fonte de números | Fonte pixel própria (se a arte quiser) | A6 |
| F2.7 Spawn de inimigo | Marcador desenhado vira uma runa/cova no chão | A7 |
| F2.8 Portas da sala | Tween em barreira genérica vira sprite de grade/lápide | A8 |
| F2.9 Player | Frame de "dano" e de morte | A9 |
| F2.10 Caldeirão | Bolhas desenhadas viram sprite de bolha/vapor | A10 |
| F2.11 Boss | Telegraph dos ataques (laser e explosão) com as sheets que **já existem** em `assets/sprites/Enemies/Boss_*` | já entregue |

---

## Requisições para a equipe de artes
Tudo em pixel art, filtro Nearest, paleta do tileset halloween. **Prioridade: A1–A5 primeiro**, o resto é opcional: o jogo já funciona com a versão programática.

| ID | Asset | Tamanho / frames | Observações | Prioridade |
|----|-------|------------------|-------------|------------|
| A1 | Muzzle flash | 16x16, 3 frames | **Branco/cinza**: o código tinge na cor da poção | Alta |
| A2 | Impacto da bala ("splash") | 16x16, 4 frames | Branco, tingido por código | Alta |
| A3 | Morte de inimigo (genérica: "poof" de fumaça/alma) | 32x32, 5–6 frames | Uma genérica para todos. Por inimigo só se sobrar tempo | Alta |
| A4 | Ícones de status | 8x8, 1 frame cada | Stun, slow, marked, veneno, raiz, charm, rage | Alta |
| A5 | HUD de vida | 16x16 | Coração (ou frasco) cheio, meio e vazio | Alta |
| A6 | Fonte pixel para números | Altura 5–7 px, dígitos 0–9 + "!" | Opcional: pode ser uma fonte CC0 | Baixa |
| A7 | Marcador de spawn | 32x32, 2–4 frames em loop | Runa ou terra mexendo, combinando com o cemitério | Média |
| A8 | Barreira de porta da sala | Tamanho do vão da porta, 1 frame + 3 frames abrindo | Grade de ferro ou lápides | Média |
| A9 | Player: frame de dano e de morte | 32x32, nas 4 direções (dano) + 4–6 frames (morte) | Mesma folha do `SpritesPlayer.png` | Média |
| A10 | Bolha/vapor do caldeirão | 8x8, 3–4 frames | Branco, tingido por código | Baixa |
| A11 | Partículas genéricas | 4x4 ou 8x8: faísca, fumaça, estrela | Branco; substituem os quadrados 2x2 atuais | Baixa |

**Regra para a arte:** efeitos (A1, A2, A10, A11) em **branco/escala de cinza**, porque o código colore pela poção ativa. Assim um sprite só serve para todas as combinações de sinergia.

---

## Agentes e ordem de execução
Princípio igual ao do `PLANO.md`: o modelo mais barato que resolve. Cada agente recebe só os arquivos que toca, os sinais do EventBus que usa e as convenções. A verificação é feita com `run_project` + `get_debug_output`.

| # | Tarefa | Arquivos principais | Modelo | Esforço | Depende de |
|---|--------|---------------------|--------|---------|------------|
| 1 | F1.1 Autoload `Juice` + sinais + `feel_constants.gd` | `autoloads/juice.gd`, `event_bus.gd`, `project.godot` | Sonnet 5.5 | medium | — |
| 2 | F1.14 AudioManager (pitch, limite, ducking) + gerar SFX no jsfxr | `audio_manager.gd`, `assets/audio/sfx/` | Haiku 5.5 | low | — (áudio: humano gera os arquivos) |
| 3 | F1.2 Câmera (smoothing, look-ahead, recuo) | `player.gd`, `player.tscn` | Haiku 5.5 | low | 1 |
| 4 | F1.3 + F1.4 `HitFeedback`, shader de flash, knockback, morte do inimigo | `components/hit_feedback.gd`, `enemy_base.gd/.tscn`, shader | Sonnet 5.5 | medium | 1 |
| 5 | F1.5 + F1.13 I-frames, dano e morte do player, vinheta | `player.gd/.tscn`, `hurtbox.gd`, vinheta | Sonnet 5.5 | medium | 1, 3 (mesma cena) |
| 6 | F1.6 Tiro (muzzle, recuo, rastro, parede) | `bullet.gd/.tscn`, `player.gd` | Haiku 5.5 | low | 5 (mesma cena do player) |
| 7 | F1.7 Números de dano (com pool) | `ui/damage_numbers.gd`, `bullet.gd`, `health_component.gd` | Sonnet 5.5 | low | 4, 6 |
| 8 | F1.8 Indicadores de status | `enemies/status_effects.gd` | Haiku 5.5 | low | 4 |
| 9 | F1.9 + F1.10 Spawn com aviso e feedback de salas | `room_encounter.gd`, `dungeon_level.gd` | Sonnet 5.5 | low | 1 |
| 10 | F1.11 HUD (vida desenhada, pontos, rage, troca de poção) | `hud.gd/.tscn`, `potion_slot.gd` | Haiku 5.5 | low | 1 |
| 11 | F1.12 Interações (pickup, mímico, caldeirão) | `interactor.gd`, `ground_item.gd`, `pumpkin_mimic.gd`, `cauldron.gd` | Haiku 5.5 | low | 1, 4 |
| 12 | Revisão de tuning e performance (hordas, pools, time_scale) | diff completo | Opus 5.5 | medium | 1–11 |
| 13 | Fase 2: trocar o visual programático pelos sprites (por item) | conforme a tabela F2 | Haiku 5.5 | low | sprites entregues |

**Paralelismo:**
- **Onda 1:** 1 e 2 em paralelo.
- **Onda 2:** 3→5→6 em sequência (mesma cena do player). 4, 9 e 10 em paralelo com elas.
- **Onda 3:** 7, 8 e 11 em paralelo.
- **Onda 4:** 12.

**Regras:**
- Cena editada por um único agente por onda.
- Sem Fable 5.1. Opus só na revisão.
- Cada agente testa o próprio item com `run_project` antes de terminar.

## Verificação (manual, após a Fase 1)
- Atirar: flash no cano, recuo, rastro, som com pitch variando.
- Acertar o inimigo: pisca branco, recua, número aparece. O crítico é maior e tem hitstop.
- Matar: burst + pop + som, shake proporcional ao tipo de inimigo.
- Levar dano de 3 inimigos ao mesmo tempo: perde só 1 de vida e pisca durante os i-frames.
- Horda grande (30+ inimigos): sem queda de FPS, números de dano limitados pelo pool.
- Opção de reduzir tremida: desliga o shake.
- Morte do player e sala limpa: slow-motion volta ao normal (`Engine.time_scale == 1.0` depois).
