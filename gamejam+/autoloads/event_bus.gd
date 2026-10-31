extends Node

# Morte do jogador
signal player_died()
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
# Item usado no caldeirão
signal item_brewed(item_id: StringName)
# Efeitos ativos mudaram
signal active_effects_changed()
# Pedido para abrir o inventário
signal inventory_open_requested()
# Inventário fechado
signal inventory_closed()
# Itens no chão mudaram
signal ground_items_changed()
# Item recolhido do chão
signal item_picked_up(item_id: StringName)
