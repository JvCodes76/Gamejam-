extends Node

# Morte do jogador
signal player_died()
# Boss do último cemitério derrotado (fim do loop atual)
signal boss_defeated()
# Run terminou: mostra o sumário (victory = boss derrotado, pode seguir para o modo infinito)
signal run_ended(victory: bool)
# Vida atual do jogador alterada
signal player_health_changed(current: int, max_value: int)
# Inimigo derrotado, concede pontos
signal enemy_killed(points: int)
# Pontuação alterada
signal score_changed(score: int)
# Jogo pausado ou despausado
signal game_paused(paused: bool)
# Pedido de troca de cena
signal scene_change_requested(path: String)
# Pedido para tocar um efeito sonoro
signal play_sfx_requested(sfx_name: String)
# Pedido para tocar uma música
signal play_music_requested(music_name: String)
# Item usado no caldeirão (reservado para o caldeirão)
signal item_brewed(item_id: StringName)
# Efeitos ativos mudaram
signal active_effects_changed()
# Pedido para abrir o inventário
signal inventory_open_requested()
# Inventário fechado
signal inventory_closed()
# Itens no chão mudaram
signal ground_items_changed()
# Pedido de drop de item (source = LootManager.Source); o LootManager sorteia e solta no chão
signal item_drop_requested(source: int, position: Vector2)
# Item recolhido do chão
signal item_picked_up(item_id: StringName)
# Slots de poção mudaram (conteúdo)
signal potion_slots_changed()
# Slot de poção ativo mudou
signal potion_selected(index: int)
# Andar mudou (nível atual)
signal floor_changed(level: int)
# Pedido para abrir o menu do caldeirão
signal cauldron_open_requested(cauldron: Node)
# Sala mudou (índice da sala atual)
signal room_changed(index: int)
# Cemitério carregado (índice a partir de 1 e total de cemitérios)
signal cemetery_changed(index: int, total: int)
# Tempo restante da sala de horda (valor negativo = esconder)
signal horde_timer_changed(seconds_left: float)
# Inimigo morreu: posição, estava marcado, é básico
signal enemy_died(position: Vector2, was_marked: bool, is_basic: bool)
# Tick de dano ao longo do tempo num inimigo: fonte e dano causado
signal enemy_dot_ticked(enemy: Node, source: StringName, amount: int)
# Raiva (sinergia Evil) mudou: bônus de dano (0.05 = +5%)
signal rage_changed(bonus: float)
# Inimigo enfeitiçado morreu: o inimigo (ainda válido durante o sinal) e o tempo restante do charm
signal charmed_enemy_died(enemy: Node2D, charm_time_left: float)

# --- Game feel (escutados pelo autoload Juice, pela UI e pelo áudio) ---
# Pedido de tremida de tela (trauma de 0 a 1, soma com o atual)
signal screen_shake_requested(trauma: float)
# Pedido de congelar o jogo por "duration" segundos reais (o maior vence, não empilha)
signal hitstop_requested(duration: float)
# Pedido de câmera lenta: escala de tempo por "duration" segundos reais
signal slowmo_requested(scale: float, duration: float)
# Dano direto causado a um inimigo (números de dano)
signal damage_dealt(position: Vector2, amount: int, is_crit: bool, color: Color)
# Dano negado (sinergia Darkness): mostra "BLOCK"
signal damage_blocked(position: Vector2)
# Player tomou dano
signal player_hurt(position: Vector2)
# Bala destruída numa parede
signal bullet_hit_wall(position: Vector2, color: Color)
# Sala trancou / foi limpa
signal room_locked()
signal room_cleared()
# Item recolhido do chão (com a posição de onde estava)
signal item_collected(item_id: StringName, position: Vector2)
# Poção preparada no caldeirão
signal potion_brewed(color: Color, position: Vector2)
