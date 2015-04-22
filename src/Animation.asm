;creates a tile animation set with specified animation parameters
;input - (ani_label_hi, ani_label_lo, animation rate, loop (0 or > 0), tile_x, tile_y)
create_tile_animation:
	LDY ani_num_running

	;LDA \1
	STA ani_num_frames, y

	;LDA \3
	STA ani_rate, y
	
	;LDA \4
	STA ani_loop, y

	LDA ani_num_running
	ASL a
	TAY

	;LDA #HIGH(\2)
	STA ani_frames + 1, y

	;LDA #LOW(\2)
	STA ani_frames, y

	;LDA \7
	STA ani_VRAM_pointer, y

	;LDA \7 + 1
	STA ani_VRAM_pointer + 1, y

	;CALL_3 mul_short, ani_VRAM_pointer, \6, #$20
	;SET_RT_VAL_2 ani_VRAM_pointer, ani_VRAM_pointer + 1

	;CALL_3 add_short, ani_VRAM_pointer, ani_VRAM_pointer + 1, \5
	;SET_RT_VAL_2 ani_VRAM_pointer, ani_VRAM_pointer + 1

	LDA #$00
	STA ani_frame_counter
	STA ani_current_frame

	INC ani_num_running

	;debugging stuff
	;DEBUG_BRK
	;LDA ani_frames
	;LDA ani_frames + 1
	;LDY #$01
	;LDA ani_VRAM_pointer
	;LDA ani_VRAM_pointer + 1
	;LDY #$02
	;LDA ani_rate
	;LDY #$04
	;LDA ani_frame_counter
	;LDY #$08
	;LDA ani_current_frame
	;LDY #$10
	;LDA ani_loop
	;LDY #$20
	;LDA ani_num_frames
	;LDY #$40
	;LDA ani_num_running

	RTS

update_animations:
	LDX ani_num_running
	DEX
	ani_update_loop:
		INC ani_frame_counter, x
		LDA ani_frame_counter, x
		CMP ani_rate, x              	;sets carry flag if val_1 >= val_2
		BEQ fcgtrate     				;success if val_1 = val_2
		BCC nfcgtrate              		;fail if no carry flag set
		fcgtrate:
			LDA #$00
			STA ani_frame_counter, x

			INC ani_current_frame, x
			LDA ani_current_frame, x
			CMP ani_num_frames, x       ;sets carry flag if val_1 >= val_2
			BEQ cfgtnf     				;success if val_1 = val_2
			BCC nfcgtrate              	;fail if no carry flag set
			cfgtnf:
				LDA #$00
				STA ani_current_frame, x
		nfcgtrate:

		INX
		DEX
		BEQ ani_update_loop_end
		JMP ani_update_loop
	ani_update_loop_end:
	
    RTS