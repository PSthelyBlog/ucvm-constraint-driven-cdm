#!/ucvm/sh
# Conversational ASCII RPG
# Ring: USER
# Size: 16KB

.text:
rpg_start:
   mov sp, 0xE000
   call init_game
   call draw_title
   call game_loop
   ret

init_game:
   ; Initialize game state
   mov word [player_hp], 20
   mov word [player_max_hp], 20
   mov byte [player_x], 5
   mov byte [player_y], 5
   mov word [gold], 0
   mov byte [current_map], MAP_VILLAGE
   ret

draw_title:
   call clear_screen
   mov si, title_art
   call print_string
   call wait_key
   ret

game_loop:
   call clear_screen
   call draw_map
   call draw_stats
   call get_input
   call process_input
   call check_encounters
   jmp game_loop

draw_map:
   mov al, [current_map]
   cmp al, MAP_VILLAGE
   je draw_village
   cmp al, MAP_FOREST
   je draw_forest
   cmp al, MAP_DUNGEON
   je draw_dungeon
   ret

draw_village:
   mov si, village_map
   call render_map
   ret

draw_forest:
   mov si, forest_map
   call render_map
   ret

draw_dungeon:
   mov si, dungeon_map
   call render_map
   ret

render_map:
   mov cx, MAP_HEIGHT
.row_loop:
   push cx
   mov cx, MAP_WIDTH
.col_loop:
   lodsb
   
   ; Check if player position
   mov bl, [player_x]
   mov bh, [player_y]
   ; If player pos, draw @
   cmp bl, cl
   jne .not_player
   cmp bh, ch
   jne .not_player
   mov al, '@'
.not_player:
   call putchar
   loop .col_loop
   
   mov al, 0x0A  ; newline
   call putchar
   pop cx
   loop .row_loop
   ret

process_input:
   ; Handle movement and actions
   cmp al, 'w'
   je move_up
   cmp al, 'a'
   je move_left
   cmp al, 's'
   je move_down
   cmp al, 'd'
   je move_right
   cmp al, 'i'
   je show_inventory
   cmp al, 't'
   je talk_npc
   cmp al, 'q'
   je quit_game
   ret

check_encounters:
   ; Random encounter logic
   call rand
   and al, 0x1F
   cmp al, 0x03
   jl start_battle
   ret

start_battle:
   call clear_screen
   mov si, battle_start_msg
   call print_string
   call draw_enemy
   call battle_loop
   ret

.data:
title_art:
   .asciz "╔═══════════════════════════════════╗"
   .asciz "║     THE QUEST OF UCVM REALM       ║"
   .asciz "║         An ASCII Adventure        ║"
   .asciz "╚═══════════════════════════════════╝"
   .asciz ""
   .asciz "    Press any key to begin..."

village_map:
   .db "#####################"
   .db "#.......#...........#"
   .db "#..INN..#...SHOP....#"
   .db "#.......#...........#"
   .db "#########...........#"
   .db "#...................#"
   .db "#.....T.....T.......#"
   .db "#...................#"
   .db "#...................#"
   .db "#####################"

forest_map:
   .db "TTTTTTTTTTTTTTTTTTTTT"
   .db "T....T....T....T....T"
   .db "..T....T....T....T..."
   .db "....T....^^....T....."
   .db "..T....^^^^^....T...."
   .db "T....T..^^^..T....T.."
   .db "..T....T....T....T..."
   .db "T....T....T....T....T"
   .db "....................>"
   .db "TTTTTTTTTTTTTTTTTTTTT"

dungeon_map:
   .db "#####################"
   .db "#...................#"
   .db "#.###.###...###.###.#"
   .db "#...................#"
   .db "#.#.#.#.#.#.#.#.#.#.#"
   .db "#...................#"
   .db "#.###.###.X.###.###.#"
   .db "#...................#"
   .db "#<..................#"
   .db "#####################"

enemy_goblin:
   .asciz "    ,      ,"
   .asciz "   /\\ .~. /\\"
   .asciz "  ( o'...`o )"
   .asciz "   > -==- <"
   .asciz "  /|\\    /|\\"
   .asciz " / |     | \\"

battle_start_msg:
   .asciz "A wild goblin appears!"
   .asciz ""

stats_template:
   .asciz "HP: %d/%d  Gold: %d  Location: %s"

; Game state variables
.bss:
player_hp: .word 0
player_max_hp: .word 0
player_x: .byte 0
player_y: .byte 0
gold: .word 0
current_map: .byte 0
inventory: .space 32

; Constants
MAP_WIDTH equ 21
MAP_HEIGHT equ 10
MAP_VILLAGE equ 0
MAP_FOREST equ 1
MAP_DUNGEON equ 2