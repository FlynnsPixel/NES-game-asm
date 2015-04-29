;------------------------------------------------------------------------------------;
;map macros

;macro to load a nametable + attributes into a specified PPU VRAM address
;input - (nametable_address (including attributes), PPU_nametable_address)
LOAD_ROOM .macro
    LDA \1
    STA current_room
    STA nt_pointer + 1

    LDA \1 + 1
    STA current_room + 1
    STA nt_pointer

    LDA \2
    STA PPU_ADDR
    STA VRAM_pointer
    STA current_VRAM_addr

    LDA \2 + 1
    STA PPU_ADDR
    STA VRAM_pointer + 1
    STA current_VRAM_addr + 1
    
    LDA #$00
    STA nt_row_x
    STA nt_row_y

    CALL load_room

	INC room_load_id

    LDA NT_CHAMBER_LOADING_STATE
    STA current_state

    .endm

IS_SOLID_TILE .macro
    CMP #$02
    BEQ .success\@
    CMP #$05
    BEQ .success\@
    CMP #$06
    BEQ .success\@
    CMP #$15
    BEQ .success\@
    CMP #$16
    BEQ .success\@
    CMP #$0F
    BEQ .success\@
    CMP #$1F
    BEQ .success\@
    CMP #$1D
    BEQ .success\@
    CMP #$1C
    BEQ .success\@

    JMP \1
    .success\@:

    .endm

SET_ROOM_POINTERS .macro
    .IF \?1 = 6                 ;if the param 2 is a label, set pointers, otherwise set pointers to #$00
        SET_POINTER_TO_ADDR \1, room_1, room_1 + 1
        SET_POINTER_TO_ADDR VRAM_NT_0, VRAM_room_addr_1, VRAM_room_addr_1 + 1
    .ELSE
        SET_POINTER #$00, #$00, room_1, room_1 + 1
        SET_POINTER #$00, #$00, VRAM_room_addr_1, VRAM_room_addr_1 + 1
    .ENDIF

    .IF \?2 = 6                 ;if the param 1 is a label, set pointers, otherwise set pointers to #$00
        SET_POINTER_TO_ADDR \2, room_2, room_2 + 1
        SET_POINTER_TO_ADDR VRAM_NT_1, VRAM_room_addr_2, VRAM_room_addr_2 + 1
    .ELSE
        SET_POINTER #$00, #$00, room_2, room_2 + 1
        SET_POINTER #$00, #$00, VRAM_room_addr_2, VRAM_room_addr_2 + 1
    .ENDIF

    .IF \?3 = 6                 ;if the param 3 is a label, set pointers, otherwise set pointers to #$00
        SET_POINTER_TO_ADDR \3, room_3, room_3 + 1
        SET_POINTER_TO_ADDR VRAM_NT_2, VRAM_room_addr_3, VRAM_room_addr_3 + 1
    .ELSE
        SET_POINTER #$00, #$00, room_3, room_3 + 1
        SET_POINTER #$00, #$00, VRAM_room_addr_3, VRAM_room_addr_3, + 1
    .ENDIF

    .IF \?4 = 6                 ;if the param 4 is a label, set pointers, otherwise set pointers to #$00
        SET_POINTER_TO_ADDR \4, room_4, room_4 + 1
        SET_POINTER_TO_ADDR VRAM_NT_3, VRAM_room_addr_4, VRAM_room_addr_4 + 1
    .ELSE
        SET_POINTER #$00, #$00, room_4, room_4 + 1
        SET_POINTER #$00, #$00, VRAM_room_addr_4, VRAM_room_addr_4, + 1
    .ENDIF

    .endm

;-----------------------------------------------------------------------------------;

load_chamber_1:
    CALL init_chamber

    SET_ROOM_POINTERS CHAMBER_1_ROOM_0, CHAMBER_1_ROOM_1, CHAMBER_1_ROOM_2, CHAMBER_1_ROOM_3
    CALL load_next_room

    RTS

init_chamber:
    LDA #$00
    STA enemy_len
    STA room_load_id
    CALL init_enemies
    CALL init_animations
    CALL init_player

    LDA #$00
    STA speed_x
    STA speed_x + 1
    STA gravity

    RTS

load_next_room:
    LDA #$00
    STA row_index
    STA row_index + 1

    IF_EQU room_load_id, #$00, lnrne0_
        LOAD_ROOM room_1, VRAM_room_addr_1
        JMP lnrlns_
    lnrne0_:

    IF_EQU room_load_id, #$01, lnrne1_
        LOAD_ROOM room_2, VRAM_room_addr_2
        JMP lnrlns_
    lnrne1_:

    IF_EQU room_load_id, #$02, lnrne2_
        LOAD_ROOM room_3, VRAM_room_addr_3
        JMP lnrlns_
    lnrne2_:

    IF_EQU room_load_id, #$03, lnrne3_
        LOAD_ROOM room_4, VRAM_room_addr_4
        JMP lnrlns_
    lnrne3_:

    ;no more rooms to load, so complete the loading process
    CALL room_loading_complete
    RTS

    lnrlns_:
        ;LOAD_ROOM has been called so change the state to a chamber loading state
        LDA NT_CHAMBER_LOADING_STATE
        STA current_state

        RTS

room_loading_complete:
    CALL respawn

    RTS

;writes nametable bytes pointing from nt_pointer into PPU VRAM
;before this function is called, the VRAM_NT_ID address must be written to PPU_ADDR
;so whenever we write data to PPU_DATA, it will map to the VRAM_NT_ID + write offset address in the PPU VRAM
;this function also handles scanning each tile and checking if it is of another specific tile and performing
;an action. The following is a list of tiles with actions performed
;player ball tile - Sets the respawn point, room, ect at this position
;slime tile - Creates a slime enemy at this position
load_room:
    LDY #$00
    ntr_loop:
        IF_UNSIGNED_LT nt_row_y, #$1F, lrltnejmp_
            IF_UNSIGNED_LT nt_row_x, #$1F, lrltnejmp_
                IF_EQU [nt_pointer], y, #$07, lrnsr_
                    CALL set_respawn, nt_row_x, nt_row_y
                    LDA #$00
                    JMP lrltnei_
                lrnsr_:

                CMP #$0C
                BNE lrltneil_
                    INC enemy_len

                    ;push a, x and y onto the stack to save previous registers
                    TXA
                    PHA
                    TYA
                    PHA

                    CALL create_slime, nt_row_x, nt_row_y

                    ;pull a, x, y from the stack and put them back in their respective registers
                    PLA
                    TAY
                    PLA
                    TAX
                    LDA #$00

                    JMP lrltnei_
                ;used as a mid way point to jump to various places in the loop because it crosses page boundaries
                lrltnejmp_:
                    JMP lrltne_
                ntr_loop_jmp_:
                    JMP ntr_loop
                lrltneil_:

                CMP #$12
                BNE lrltnei_
                    ;push a, x and y onto the stack to save previous registers
                    TXA
                    PHA
                    TYA
                    PHA
                    
                    CALL create_tile_animation, nt_row_x, nt_row_y, current_VRAM_addr, current_VRAM_addr + 1
                    CALL set_animation_attribs, #HIGH(CHECK_POINT_DEACTIVE_ANI), #LOW(CHECK_POINT_DEACTIVE_ANI), #$04, #$01

                    ;pull a, x, y from the stack and put them back in their respective registers
                    PLA
                    TAY
                    PLA
                    TAX
                    LDA #$00

                    JMP lrltnei_
        lrltne_:
            LDA [nt_pointer], y     ;get the value pointed to by current_room_lo + current_room_hi + y counter offset
        lrltnei_:

        STA PPU_DATA                ;write byte to the PPU nametable address
        INY                         ;add by 1 to move to the next byte

        INC nt_row_x
        IF_UNSIGNED_GT_OR_EQU nt_row_x, #$20, nrowreset
            LDA #$00
            STA nt_row_x

            INC nt_row_y
        nrowreset:

        CPY NT_MAX_LOAD_TILES        ;check if y is equal to 0 (it has overflowed)
        BNE ntr_loop_jmp_                 ;keep looping if y not equal to 0, otherwise continue
    ntr_loop_end_:

    CALL add_short, row_index, row_index + 1, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN row_index, row_index + 1

    CALL add_short, nt_pointer + 1, nt_pointer, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN nt_pointer + 1, nt_pointer

    CALL add_short, VRAM_pointer, VRAM_pointer + 1, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN VRAM_pointer, VRAM_pointer + 1

    RTS

;writes nametable bytes pointing from nt_pointer into PPU VRAM
;before this function is called, the VRAM_NT_ID address must be written to PPU_ADDR
;so whenever we write data to PPU_DATA, it will map to the VRAM_NT_ID + write offset address in the PPU VRAM
load_nametable:
    LDY #$00
    nt_loop_:
        LDA [nt_pointer], y         ;get the value pointed to by nt_pointer_lo + nt_pointer_hi + y counter offset
        STA PPU_DATA                ;write byte to the PPU nametable address
        INY                         ;add by 1 to move to the next byte
        
        CPY NT_MAX_LOAD_TILES       ;check if y is equal to 0 (it has overflowed)
        BNE nt_loop_                ;keep looping if y not equal to 0, otherwise continue
    nt_loop_end_:

    CALL add_short, row_index, row_index + 1, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN row_index, row_index + 1

    CALL add_short, nt_pointer + 1, nt_pointer, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN nt_pointer + 1, nt_pointer

    CALL add_short, VRAM_pointer, VRAM_pointer + 1, NT_MAX_LOAD_TILES
    ST_RT_VAL_IN VRAM_pointer, VRAM_pointer + 1

    RTS

;------------------------------------------------------------------------------------;

check_collide_left:
    LDY coord_y
    STY c_coord_y

    LDY coord_x + 1
    LDA [leftc_pointer], y
    BNE ncleft
        CALL add_short, leftc_pointer + 1, leftc_pointer, #$20
        ST_RT_VAL_IN leftc_pointer + 1, leftc_pointer

        LDA [leftc_pointer], y
    ncleft:
    STY c_coord_x
    STA rt_val_1

    RTS

check_collide_right:
    LDY coord_y
    STY c_coord_y

    LDY coord_x + 2
    INY
    CPY #$20
    BNE crnoob
        LDY #$1F
    crnoob:

    LDA [rightc_pointer], y
    BNE ncright
        CALL add_short, rightc_pointer + 1, rightc_pointer, #$20
        ST_RT_VAL_IN rightc_pointer + 1, rightc_pointer

        LDA [rightc_pointer], y
    ncright:
    STY c_coord_x
    STA rt_val_1

    RTS

check_collide_down:
    LDY coord_y + 1
    STY c_coord_y

    LDY coord_x
    LDA [downc_pointer], y
    BNE ncdown
        LDY coord_x + 1
        INY
        CPY #$20
        BNE cdnoob
            LDY coord_x
        cdnoob:
        LDA [downc_pointer], y
    ncdown:
    STY c_coord_x
    STA rt_val_1
    RTS

check_collide_up:
    LDY coord_y
    STY c_coord_y

    LDY coord_x
    LDA [upc_pointer], y
    BNE ncup
        LDY coord_x + 1
        INY
        CPY #$20
        BNE cunoob
            LDY #$00
        cunoob:
        LDA [upc_pointer], y
    ncup:
    STY c_coord_x
    STA rt_val_1
    RTS