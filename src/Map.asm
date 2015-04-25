IS_SOLID_TILE .macro
    CMP #$02
    BEQ \1
    CMP #$05
    BEQ \1
    CMP #$06
    BEQ \1
    CMP #$15
    BEQ \1
    CMP #$16
    BEQ \1

    .endm

handle_camera_scroll:
    IF_EQU scroll_x_type, #$00, right_scroll_map
        IF_UNSIGNED_GT_OR_EQU pos_x, #$7F, scrleftstartelse
            LDA pos_x
            SEC
            SBC #$7F
            STA scroll_x

            LDA #$7F
            STA OAM_RAM_ADDR + 3

            IF_SIGNED_LT_OR_EQU scroll_x, #$00, scroll_x_endif
                IF_SIGNED_GT scroll_x, #$F8, scroll_x_endif
                    LDA #$00
                    STA scroll_x
                    JMP scroll_x_endif
        scrleftstartelse:
            LDA pos_x
            STA OAM_RAM_ADDR + 3

            LDA #$00
            STA scroll_x

            JMP scroll_x_endif
    right_scroll_map:
        IF_UNSIGNED_LT_OR_EQU pos_x, #$7F, scrrightstartelse
            LDA pos_x
            SEC
            SBC #$7F
            STA scroll_x

            LDA #$7F
            STA OAM_RAM_ADDR + 3

            IF_SIGNED_GT_OR_EQU scroll_x, #$FF, scroll_x_endif
                IF_SIGNED_LT scroll_x, #$08, scroll_x_endif
                    LDA #$FF
                    STA scroll_x
                    JMP scroll_x_endif
        scrrightstartelse:
            LDA pos_x
            STA OAM_RAM_ADDR + 3

            LDA #$FF
            STA scroll_x
    scroll_x_endif:

    RTS

handle_room_intersect:
    IF_NOT_EQU scroll_x_type, #$00, ntransleft
        IF_SIGNED_LT speed_x, #$00, ntransleft
            IF_SIGNED_GT speed_x, #$80, ntransleft
                IF_UNSIGNED_GT_OR_EQU pos_x, #$FB, ntransleft
                    SET_POINTER_TO_ADDR LEVEL_1_MAP_0, current_room, current_room + 1
                    SET_POINTER_TO_ADDR VRAM_NT_0, current_VRAM, current_VRAM + 1

                    LDA #$FF
                    STA pos_x

                    LDA #$7F
                    STA scroll_x

                    LDA #$00
                    STA scroll_x_type
                    JMP ntransright
    ntransleft:
        IF_SIGNED_GT speed_x, #$00, ntransright
            IF_SIGNED_LT speed_x, #$7F, ntransright
                IF_UNSIGNED_GT_OR_EQU pos_x, #$FB, ntransright
                    SET_POINTER_TO_ADDR LEVEL_1_MAP_1, current_room, current_room + 1
                    SET_POINTER_TO_ADDR VRAM_NT_1, current_VRAM, current_VRAM + 1

                    LDA #$00
                    STA pos_x

                    LDA #$80
                    STA scroll_x

                    LDA #$01
                    STA scroll_x_type
    ntransright:
    RTS

handle_respawn:
    LDA rt_val_1
    CMP #$0B
    BNE respawn_endif
        SET_POINTER_TO_ADDR LEVEL_1_MAP_1, current_room, current_room + 1
        LDA #$01
        STA scroll_x_type

        LDA player_spawn
        STA OAM_RAM_ADDR + 3
        STA pos_x

        SEC
        SBC #$7F
        STA scroll_x

        LDA player_spawn + 1
        STA OAM_RAM_ADDR + 3
        STA pos_y
    respawn_endif:

    RTS

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
    CALL add_short, downc_pointer + 1, downc_pointer, #$20
    ST_RT_VAL_IN downc_pointer + 1, downc_pointer

    LDY coord_y + 2
    INY
    STY c_coord_y

    LDY coord_x
    LDA [downc_pointer], y
    BNE ncdown
        LDY coord_x + 1
        INY
        CPY #$FF
        BNE cdnoob
            LDY #$00
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
        CPY #$FF
        BNE cunoob
            LDY #$00
        cunoob:
        LDA [upc_pointer], y
    ncup:
    STY c_coord_x
    STA rt_val_1
    RTS