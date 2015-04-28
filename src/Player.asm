;-----------------------------------------------------------------------------------;

init_player:
	LDA #$07
    STA OAM_RAM_ADDR + 1
    LDA #$03
    STA OAM_RAM_ADDR + 2

    RTS

;-----------------------------------------------------------------------------------;

update_player:
	CALL handle_player_movement
	CALL handle_player_collision

    RTS

;-----------------------------------------------------------------------------------;

handle_player_movement:
	;clamp speed_x
    CALL clamp_signed, speed_x, #$FE, #$02
    LDA rt_val_1
    STA speed_x

    ;clamp gravity
    CALL clamp_signed, gravity, #$FB, #$04
    LDA rt_val_1
    STA gravity
	
	;if speed_x is >= 1, then apply friction and slow it down by 64
    IF_SIGNED_GT_OR_EQU speed_x, #$01, posxgtelse
        CALL sub_short, speed_x, speed_x + 1, #$40
        ST_RT_VAL_IN speed_x, speed_x + 1
		
    posxgtelse:
	
	;if speed_x is <= 255, then apply friction and slow it down by 64
    IF_SIGNED_LT_OR_EQU speed_x, #$FF, posxltelse
        CALL add_short, speed_x, speed_x + 1, #$40
        ST_RT_VAL_IN speed_x, speed_x + 1
    posxltelse:

    LEFT_BUTTON_DOWN lbnotdown
        CALL sub_short, speed_x, speed_x + 1, #$80
        ST_RT_VAL_IN speed_x, speed_x + 1
    lbnotdown:

    RIGHT_BUTTON_DOWN rbnotdown
        CALL add_short, speed_x, speed_x + 1, #$80
        ST_RT_VAL_IN speed_x, speed_x + 1
    rbnotdown:

    CALL add_short, gravity, gravity + 1, #$40
    ST_RT_VAL_IN gravity, gravity + 1

    ;add gravity to pos_y and set it as the player's y sprite position
    ADD pos_y, gravity
    STA pos_y
    STA OAM_RAM_ADDR

    RTS

;-----------------------------------------------------------------------------------;

handle_player_collision:
	DIV8 pos_x, #$00, #$00, coord_x
    DIV8 pos_x, #$00, #$02, coord_x + 1
    DIV8 pos_x, #$02, #$00, coord_x + 2

    DIV8 pos_y, #$00, #$00, coord_y
    DIV8 pos_y, #$08, #$00, coord_y + 1
    DIV8 pos_y, #$00, #$04, coord_y + 2

    SET_POINTER_TO_VAL current_room, leftc_pointer + 1, leftc_pointer
    CALL mul_short, leftc_pointer + 1, coord_y, #$20
    ST_RT_VAL_IN leftc_pointer + 1, leftc_pointer
    ST_RT_VAL_IN rightc_pointer + 1, rightc_pointer

    SET_POINTER_TO_VAL current_room, downc_pointer + 1, downc_pointer
    CALL mul_short, downc_pointer + 1, coord_y + 1, #$20
    ST_RT_VAL_IN downc_pointer + 1, downc_pointer

    SET_POINTER_TO_VAL current_room, upc_pointer + 1, upc_pointer
    CALL mul_short, upc_pointer + 1, coord_y + 2, #$20
    ST_RT_VAL_IN upc_pointer + 1, upc_pointer

    CALL check_collide_down
    LDA rt_val_1
    BEQ cte0_
        IF_SIGNED_GT_OR_EQU gravity, #$00, cte0_
        	IF_SIGNED_GT_OR_EQU gravity, #$00, cte0_
	    		LDA rt_val_1
	            CMP #$0A
	            BNE hpcnsc_
	                MUL8 c_coord_y
	                STA pos_y

	                LDA #$EF
	                STA gravity
	                LDA #$00
	                STA gravity + 1
					
					CALL create_tile_animation, #HIGH(SPRING_ANI), #LOW(SPRING_ANI), #$01, #$00, c_coord_x, c_coord_y, current_VRAM_addr, current_VRAM_addr + 1

				hpcnsc_:
				LDA rt_val_1
	            CMP #$0B
	            BNE hpcrei_
	                CALL respawn

                    RTS
	            hpcrei_:
    cte0_:

    DIV8 pos_y, #$04, #$00, coord_y + 1

    SET_POINTER_TO_VAL current_room, downc_pointer + 1, downc_pointer
    CALL mul_short, downc_pointer + 1, coord_y + 1, #$20
    CALL add_short, rt_val_1, rt_val_2, #$20
    ST_RT_VAL_IN downc_pointer + 1, downc_pointer
    
    CALL check_collide_down
    LDA rt_val_1
    IS_SOLID_TILE hpcdownendif_
        IF_SIGNED_GT_OR_EQU gravity, #$00, hpcdownendif_
            MUL8 c_coord_y
            CLC
            ADC #$03
            STA pos_y

            LDA #$FC
            STA gravity
            LDA #$7F
            STA gravity + 1
    hpcdownendif_:

    CALL check_collide_up
    IS_SOLID_TILE hpcupendif_
        IF_SIGNED_LT_OR_EQU gravity, #$00, hpcupendif_
            MUL8 c_coord_y
            SEC
            SBC #$01
            STA pos_y

            LDA #$01
            STA gravity
    hpcupendif_:

    IF_UNSIGNED_GT pos_x, #$04, hpcleftendif_
    CALL check_collide_left
    IS_SOLID_TILE hpcleftendif_
        IF_SIGNED_LT_OR_EQU speed_x, #$00, hpcleftendif_
            MUL8 c_coord_x, #$01, #$00, pos_x

            LDA #$00
            STA speed_x
    hpcleftendif_:

    IF_UNSIGNED_LT pos_x, #$FB, hpcrightendif_
    CALL check_collide_right
    IS_SOLID_TILE hpcrightendif_
        IF_SIGNED_GT_OR_EQU speed_x, #$00, hpcrightendif_
            MUL8 c_coord_x, #$00, #$01, pos_x

            LDA #$00
            STA speed_x
    hpcrightendif_:

    ADD pos_x, speed_x
    STA pos_x

    RTS

;-----------------------------------------------------------------------------------;

respawn:
    SET_POINTER_TO_VAL respawn_room, current_room, current_room + 1
    SET_POINTER_TO_VAL respawn_VRAM_addr, current_VRAM_addr, current_VRAM_addr + 1
    LDA respawn_scroll_x_type
    STA scroll_x_type
    
    MUL8 player_spawn
    STA OAM_RAM_ADDR
    STA pos_x

    SEC
    SBC #$7F
    STA scroll_x

    MUL8 player_spawn + 1
    STA OAM_RAM_ADDR + 3
    STA pos_y

    RTS

set_respawn:
    LDA param_1
    STA player_spawn
    DIV8 param_1
    STA OAM_RAM_ADDR + 3
    STA pos_x
    
    LDA param_2
    STA player_spawn + 1
    DIV8 param_2
    STA OAM_RAM_ADDR + 3
    STA pos_y

    SET_POINTER_TO_VAL current_room, respawn_room + 1, respawn_room
    SET_POINTER_TO_VAL current_VRAM_addr, respawn_VRAM_addr + 1, respawn_VRAM_addr
    
    LDA room_load_id
    STA respawn_scroll_x_type
    STA respawn_scroll_y_type

    RTS

;-----------------------------------------------------------------------------------;

handle_camera_scroll:
    IF_EQU scroll_x_type, #$00, right_scroll_x_map
        IF_UNSIGNED_GT_OR_EQU pos_x, #$7F, scrxleftstartelse
            LDA pos_x
            SEC
            SBC #$7F
            STA scroll_x

            LDA #$7F
            STA OAM_RAM_ADDR + 3

            JMP scroll_x_endif
        scrxleftstartelse:
            LDA pos_x
            STA OAM_RAM_ADDR + 3

            LDA #$00
            STA scroll_x

            JMP scroll_x_endif
    right_scroll_x_map:
        IF_UNSIGNED_LT_OR_EQU pos_x, #$7F, scrxrightstartelse
            LDA pos_x
            SEC
            SBC #$80
            STA scroll_x

            LDA #$80
            STA OAM_RAM_ADDR + 3

            JMP scroll_x_endif
        scrxrightstartelse:
            LDA pos_x
            STA OAM_RAM_ADDR + 3

            LDA #$FF
            STA scroll_x
    scroll_x_endif:

    IF_UNSIGNED_GT scroll_y_type, #$01, up_scroll_y_map
        IF_UNSIGNED_GT_OR_EQU pos_y, #$7F, scryleftstartelse
            LDA pos_y
            SEC
            SBC #$7F
            STA scroll_y

            LDA #$7F
            STA OAM_RAM_ADDR

            JMP scroll_y_endif
        scryleftstartelse:
            LDA pos_y
            STA OAM_RAM_ADDR

            LDA #$00
            STA scroll_y

            JMP scroll_y_endif
    up_scroll_y_map:
        IF_UNSIGNED_LT_OR_EQU pos_y, #$7F, scryupstartelse
            LDA pos_y
            SEC
            SBC #$80
            STA scroll_y

            LDA #$80
            STA OAM_RAM_ADDR

            JMP scroll_y_endif
        scryupstartelse:
            LDA pos_y
            STA OAM_RAM_ADDR

            LDA #$FF
            STA scroll_y
    scroll_y_endif:

    RTS

handle_room_intersect:
    IF_NOT_EQU scroll_x_type, #$00, ntransleft
        IF_SIGNED_LT speed_x, #$00, ntransleft
            IF_UNSIGNED_GT_OR_EQU pos_x, #$FB, ntransleft
                SET_POINTER_TO_VAL room_1, current_room, current_room + 1
                SET_POINTER_TO_VAL VRAM_room_addr_1, current_VRAM_addr, current_VRAM_addr + 1

                LDA #$FB
                STA pos_x

                LDA #$00
                STA scroll_x_type
                JMP ntransright
    ntransleft:
        IF_SIGNED_GT speed_x, #$00, ntransright
            IF_UNSIGNED_GT_OR_EQU pos_x, #$FB, ntransright
                SET_POINTER_TO_VAL room_2, current_room, current_room + 1
                SET_POINTER_TO_VAL VRAM_room_addr_2, current_VRAM_addr, current_VRAM_addr + 1

                LDA #$00
                STA pos_x

                LDA #$01
                STA scroll_x_type
    ntransright:

    IF_UNSIGNED_GT scroll_y_type, #$01, ntransup
        IF_SIGNED_LT gravity, #$00, ntransup
            IF_UNSIGNED_GT_OR_EQU pos_y, #$FB, ntransup
                SET_POINTER_TO_VAL room_2, current_room, current_room + 1
                SET_POINTER_TO_VAL VRAM_room_addr_2, current_VRAM_addr, current_VRAM_addr + 1

                LDA #$FB
                STA pos_y

                LDA #$00
                STA scroll_y_type

                JMP ntransdown
    ntransup:
        IF_SIGNED_GT gravity, #$00, ntransdown
            IF_UNSIGNED_GT_OR_EQU pos_y, #$e0, ntransdown
                SET_POINTER_TO_VAL room_4, current_room, current_room + 1
                SET_POINTER_TO_VAL VRAM_room_addr_4, current_VRAM_addr, current_VRAM_addr + 1

                LDA #$00
                STA pos_y

                LDA #$02
                STA scroll_y_type
    ntransdown:
    
    RTS

;------------------------------------------------------------------------------------;
