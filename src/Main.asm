    .inesprg 1   ;1 16kb PRG code
    .ineschr 1   ;1 8kb CHR data
    .inesmap 0   ;mapper 0 = NROM, no bank swapping
    .inesmir 1   ;background mirroring

;------------------------------------------------------------------------------------;

    .bank 3                           ;uses the fourth bank, which is a 8kb ROM memory region
    .org $8000                        ;places graphics tiles at the beginning of ROM (8000 - a000, offset: 0kb)
	
;------------------------------------------------------------------------------------;

    .bank 2                           ;uses the third bank, which is a 8kb ROM memory region
    .org $a000                        ;places graphics tiles in the first quarter of ROM (a000 - e000, offset: 8kb)
	.incbin "assets/tileset1.chr"     ;includes 8kb graphics file from SMB1
	
;------------------------------------------------------------------------------------;

    .bank 1                           ;uses the second bank, which is a 8kb ROM memory region
    
    .org $fffa                        ;places the address of NMI, reset and BRK handlers at the very end of the ROM
    .dw NMI                           ;address for NMI (non maskable interrupt). when an NMI happens (once per frame if enabled) the 
                                      ;processor will jump to the label NMI and return to the point where it was interrupted
    .dw RESET                         ;when the processor first turns on or is reset, it will jump to the RESET label
    .dw IQR                           ;external interrupts are not used

    .org $e000                        ;place all program code at the third quarter of ROM (e000 - fffa, offset: 24kb)

LEVEL_1_MAP_0:
	.incbin "assets/level-1/chamber1_room1.nam"
LEVEL_1_MAP_1:
	.incbin "assets/level-1/chamber1_room2.nam"

PALETTE:
	.incbin "assets/level-palette.pal"
	.incbin "assets/sprite-palette.pal"

SPRITES:
	;y, tile index, attribs (palette 4 to 7, priority, flip), x
	.db $2a, $07, %00000000, $80

NUM_SPRITES         = 1
SPRITES_DATA_LEN    = NUM_SPRITES * 4

	;store function params, return values and temporary values in the first 16 bytes of zero page
    .rsset $0000
	
;local params used to store inputs from functions - note that these params may be modified when a function with a input is called
param_1                 .rs     1
param_2                 .rs     1
param_3                 .rs     1
param_4                 .rs     1
param_5                 .rs     1
param_6                 .rs     1
param_7                 .rs     1
param_8                 .rs     1

;return values used for functions that have an output / multiple outputs
rt_val_1                .rs     1
rt_val_2                .rs     1
rt_val_3                .rs     1
rt_val_4                .rs     1

;temporary value that can be modified at any time
temp                    .rs     6

	;store game variables in zero page with a 16 byte offset
	.rsset $0010
	
vblank_counter      	.rs     1
button_bits         	.rs     1
nt_pointer          	.rs     2
leftc_pointer       	.rs     2
rightc_pointer      	.rs     2
downc_pointer       	.rs     2
upc_pointer         	.rs     2
pos_x               	.rs     1
pos_y               	.rs     1
speed_x             	.rs     2
gravity             	.rs     2
coord_x             	.rs     3
coord_y             	.rs     3
current_tile        	.rs     1
scroll_x            	.rs     1
scroll_y            	.rs     1
current_room        	.rs     2
current_VRAM            .rs     2
scroll_x_type       	.rs     1
player_spawn        	.rs     2

ani_frames 				.rs 	16 		;store hi + lo byte pointer to pre-built animation, 2 bytes per animation
ani_VRAM_pointer 		.rs 	16 		;stores hi + lo byte pointers to a nametable which tile animations will use, 2 bytes per animation

	;store animation array with a 256 byte offset with a max amount of 8 running animations
	.rsset $0100
	
ani_rate 				.rs 	8 		;frame rate byte that defines how often the animation will run per frame, 1 byte per animation
ani_frame_counter 		.rs 	8 		;frame counter that increases every frame, 1 byte per animation
ani_current_frame 		.rs 	8 		;byte that defines the current frame of the animation, 1 byte per animation
ani_loop 				.rs 	8 		;defines whether the animation will loop or not, 1 byte per animation
ani_num_frames 			.rs 	8 		;the amount of frames in the current animation, 1 byte per animation
ani_num_running 		.rs 	1 		;defines the current amount of animations running for all animations

SPRING_ANI:
	.db $02
	SPRING_FRAMES:
		.db $01, $02
		
	.include "src/SystemConstants.asm"
    .include "src/SystemMacros.asm"
    .include "src/Math.asm"
    .include "src/Map.asm"
	.include "src/Animation.asm"
	
;------------------------------------------------------------------------------------;
;map loading macros

;macro to load a nametable + attributes into specified PPU addressess
;(nametable_address (including attributes), PPU_nametable_address)
LOAD_MAP .macro
    BIT PPU_STATUS                  ;read PPU_STATUS to reset high/low latch so low byte can be stored then high byte (little endian)
    SET_POINTER_TO_LABEL \2, PPU_ADDR, PPU_ADDR
    SET_POINTER_TO_LABEL \1, nt_pointer + 1, nt_pointer
    JSR load_nametable

    .endm

;------------------------------------------------------------------------------------;

    .bank 0                         ;uses the first bank, which is a 8kb ROM memory region
    .org $c000                      ;place all program code in the middle of PGR_ROM memory (c000 - e000, offset: 16kb)

;wait for vertical blank to make sure the PPU is ready
vblank_wait:
    BIT PPU_STATUS                  ;reads PPU_STATUS and sets the negative flag if bit 7 is 1 (vblank)
    BPL vblank_wait                 ;continue waiting until the negative flag is not set which means bit 7 is positive (equal to 1)
    RTS

;RESET is called when the NES starts up
RESET:
    SEI                             ;disables external interrupt requests
    CLD                             ;the NES does not use decimal mode, so disable it
    LDX #$40
    STX $4017                       ;disables APU frame counter IRQ by writing 64 to the APU register (todo: better understanding)

    LDX #$FF
    TXS                             ;set the stack pointer to point to the end of the stack #$FF (e.g. $01FF)

    INX                             ;add 1 to the x register and overflow it which results in 0
    STX $4010                       ;disable DMC IRQ (APU memory access and interrupts) by writing 0 to the APU DMC register

    ;IF_SIGNED_LT #$01, #$01, t
    ;    DEBUG_BRK
    ;    LDY #$01
    ;t:
    ;    DEBUG_BRK
    ;    LDY #$02

    JSR vblank_wait                 ;first vblank wait to make sure the PPU is warming up

;------------------------------------------------------------------------------------;
;wait for the PPU to be ready and clear all mem from 0000 to 0800

;while waiting to make sure the PPU has properly stabalised, we will put the 
;zero page, stack memory and RAM into a known state by filling it with #$00
clr_mem_loop:
    LDA #$00
    STA $0000, x                    ;set the zero page to 0
    STA $0100, x                    ;set the stack memory to 0
    STA $0200, x                    ;set RAM to 0
    STA $0300, x                    ;set RAM to 0
    STA $0400, x                    ;set RAM to 0
    STA $0500, x                    ;set RAM to 0
    STA $0600, x                    ;set RAM to 0
    STA $0700, x                    ;set RAM to 0

    LDA #$FF
    STA OAM_RAM_ADDR, x             ;set OAM (object attribute memory) in RAM to #$FF so that sprites are off-screen

    INX                             ;increase x by 1
    CPX #$00                        ;check if x has overflowed into 0
    BNE clr_mem_loop                ;continue clearing memory if x is not equal to 0

    JSR vblank_wait                 ;second vblank wait to make sure the PPU has properly warmed up

;------------------------------------------------------------------------------------;

;> writes bg and sprite palette data to the PPU
;write the PPU bg palette address VRAM_BG_PLT to the PPU register PPU_ADDR
;so whenever we write data to PPU_DATA, it will map to VRAM_BG_PLT + write offset in the PPU VRAM
;although we start at the BG palette, we also continue writing into the sprite palette
load_palettes:
    BIT PPU_STATUS                  ;read PPU_STATUS to reset high/low latch so low byte can be stored then high byte (little endian)
    SET_POINTER_TO_LABEL VRAM_BG_PLT, PPU_ADDR, PPU_ADDR

    LDX #$00                        ;set x counter register to 0
    load_palettes_loop:
        LDA PALETTE, x              ;load palette byte (palette + x byte offset)
        STA PPU_DATA                ;write byte to the PPU palette address
        INX                         ;add by 1 to move to next byte

        CPX #$20                    ;check if x is equal to 32
        BNE load_palettes_loop      ;keep looping if x is not equal to 32, otherwise continue

load_level_1:
    LOAD_MAP LEVEL_1_MAP_0, VRAM_NT_0
    LOAD_MAP LEVEL_1_MAP_1, VRAM_NT_1

    JMP init_PPU

;> writes nametable 0 into PPU VRAM
;write the PPU nametable address VRAM_NT_0 to the PPU register PPU_ADDR
;so whenever we write data to PPU_DATA, it will map to the VRAM_NT_0 + write offset address in the PPU VRAM
load_nametable:
    LDY #$00
    LDX #$00
    LDA #$00
    STA temp
    STA temp + 1
    nt_loop:
        nt_loop_nested:
            CPY #$C0
            BCC lt960
                CPX #$03
                BNE lt960
                    LDA [nt_pointer], y     ;get the value pointed to by nt_pointer_lo + nt_pointer_hi + y counter offset
                    JMP ntcmpendif
            lt960:
                LDA [nt_pointer], y         ;get the value pointed to by nt_pointer_lo + nt_pointer_hi + y counter offset
                CMP #$07
                BNE ntcmpendif
                    DEBUG_BRK
                    LDA temp
                    ASL a
                    ASL a
                    ASL a
                    STA OAM_RAM_ADDR + 3
                    STA pos_x
                    STA player_spawn

                    SEC
                    SBC #$7F
                    STA scroll_x

                    LDA temp + 1
                    ASL a
                    ASL a
                    ASL a
                    STA OAM_RAM_ADDR + 3
                    STA pos_y
                    STA player_spawn + 1

                    LDA #$00
            ntcmpendif:

            STA PPU_DATA                ;write byte to the PPU nametable address
            INY                         ;add by 1 to move to the next byte

            ADD temp, #$01
            STA temp
            IF_UNSIGNED_GT_OR_EQU temp, #$20, nrowreset
                LDA #$00
                STA temp

                ADD temp + 1, #$01
                STA temp + 1
            nrowreset:

            CPY #$00                    ;check if y is equal to 0 (it has overflowed)
            BNE nt_loop_nested          ;keep looping if y not equal to 0, otherwise continue

            INC nt_pointer + 1          ;increase the high byte of nt_pointer by 1 ((#$FF + 1) low bytes)
            INX                         ;increase x by 1

            CPX #$04                    ;check if x has looped and overflowed 4 times (1kb, #$04FF)
            BNE nt_loop                 ;go to the start of the loop if x is not equal to 0, otherwise continue
    RTS

;------------------------------------------------------------------------------------;

;initialises PPU settings
init_PPU:
    ;setup PPU_CTRL bits
    LDA #%10000000                  ;enable NMI calling and set sprite pattern table to $0000 (0)
    STA PPU_CTRL

    ;setup PPU_MASK bits
    LDA #%00011110                  ;enable sprite rendering
    STA PPU_MASK

    LDA #$00
    STA speed_x
    STA speed_x + 1
    STA gravity

;loads all sprite attribs into OAM_RAM_ADDR
load_sprites:
    LDX #$00                        ;start x register counter at 0
    
    load_sprites_loop:
        LDA SPRITES, x              ;load sprite attrib into register a (sprite + x)
        STA OAM_RAM_ADDR, x         ;store attrib in OAM on RAM(address + x)
        INX

        CPX #SPRITES_DATA_LEN       ;check if all attribs have been stored by comparing x to the data length of all sprites
        BNE load_sprites_loop       ;continue loop if x register is not equal to 0, otherwise move down

init_sprites:
    SET_POINTER_TO_LABEL LEVEL_1_MAP_1, current_room, current_room + 1
    SET_POINTER_TO_LABEL VRAM_NT_1, current_VRAM, current_VRAM + 1
    LDA #$01
    STA scroll_x_type
	
	CREATE_TILE_ANIMATION SPRING_ANI, SPRING_FRAMES, #$09, #$00, #$10, #$08, current_VRAM

    JMP game_loop

;------------------------------------------------------------------------------------;

game_loop:
    ;keep looping until NMI is called and changes the vblank counter
    LDA vblank_counter             ;load the vblank counter
    vblank_wait_main:
        CMP vblank_counter         ;compare register a with the vblank counter
        BEQ vblank_wait_main       ;keep looping if they are equal, otherwise continue if the vblank counter has changed
	
	;clamp speed_x
    CALL_3 clamp_signed, speed_x, #$FE, #$02
    LDA rt_val_1
    STA speed_x

    ;clamp gravity
    CALL_3 clamp_signed, gravity, #$FB, #$07
    LDA rt_val_1
    STA gravity
	
	;if speed_x is >= 1, then apply friction and slow it down by 64
    IF_SIGNED_GT_OR_EQU speed_x, #$01, posxgtelse
        CALL_3 sub_short, speed_x, speed_x + 1, #$40
        SET_RT_VAL_2 speed_x, speed_x + 1
		
    posxgtelse:
	
	;if speed_x is <= 255, then apply friction and slow it down by 64
    IF_SIGNED_LT_OR_EQU speed_x, #$FF, posxltelse
        CALL_3 add_short, speed_x, speed_x + 1, #$40
        SET_RT_VAL_2 speed_x, speed_x + 1
    posxltelse:
	
	;add gravity to pos_y and set it as the player's y sprite position
	ADD pos_y, gravity
    STA pos_y
    STA OAM_RAM_ADDR
	
	JSR read_controller
	JSR update_animations
	
    LDA pos_x
    LSR a
    LSR a
    LSR a
    STA coord_x

    LDX pos_x
    DEX
    TXA
    LSR a
    LSR a
    LSR a
    STA coord_x + 1

    LDX pos_x
    INX
    TXA
    LSR a
    LSR a
    LSR a
    STA coord_x + 2

    LDA OAM_RAM_ADDR
    LSR a
    LSR a
    LSR a
    STA coord_y

    LDX OAM_RAM_ADDR
    TXA
    LSR a
    LSR a
    LSR a
    STA coord_y + 1

    LDX OAM_RAM_ADDR
    INX
    INX
    INX
    INX
    TXA
    LSR a
    LSR a
    LSR a
    STA coord_y + 2
	
    SET_POINTER_HI_LO current_room, leftc_pointer + 1, leftc_pointer
    CALL_3 mul_short, leftc_pointer + 1, coord_y + 2, #$20
    SET_RT_VAL_2 leftc_pointer + 1, leftc_pointer
    SET_RT_VAL_2 rightc_pointer + 1, rightc_pointer

    SET_POINTER_HI_LO current_room, downc_pointer + 1, downc_pointer
    CALL_3 mul_short, downc_pointer + 1, coord_y, #$20
    SET_RT_VAL_2 downc_pointer + 1, downc_pointer

    SET_POINTER_HI_LO current_room, upc_pointer + 1, upc_pointer
    CALL_3 mul_short, upc_pointer + 1, coord_y + 1, #$20
    SET_RT_VAL_2 upc_pointer + 1, upc_pointer

    CALL_3 add_short, gravity, gravity + 1, #$40
    SET_RT_VAL_2 gravity, gravity + 1

    IF_UNSIGNED_GT pos_x, #$05, scleft
    JSR check_collide_left
    CMP #$00
    BNE nscleftelse
        scleft:
        LEFT_BUTTON_DOWN lbnotdown
            CALL_3 sub_short, speed_x, speed_x + 1, #$80
            SET_RT_VAL_2 speed_x, speed_x + 1
        lbnotdown:
        JMP nscleftendif
    nscleftelse:
        IF_SIGNED_LT_OR_EQU speed_x, #$00, nscleftendif
            IF_SIGNED_GT speed_x, #$80, nscleftendif
                LDX coord_x + 1
                INX
                TXA
                ASL a
                ASL a
                ASL a
                STA pos_x

                LDA #$00
                STA speed_x
    nscleftendif:

    IF_UNSIGNED_LT pos_x, #$F8, scright
    JSR check_collide_right
    CMP #$00
    BNE nscrightelse
        scright:
        RIGHT_BUTTON_DOWN rbnotdown
            CALL_3 add_short, speed_x, speed_x + 1, #$80
            SET_RT_VAL_2 speed_x, speed_x + 1
        rbnotdown:
        JMP nscrightendif
    nscrightelse:
        IF_SIGNED_GT_OR_EQU speed_x, #$00, nscrightendif
            IF_SIGNED_LT speed_x, #$7F, nscrightendif
                LDX coord_x
                TXA
                ASL a
                ASL a
                ASL a
                STA pos_x

                LDA #$00
                STA speed_x
    nscrightendif:

    JSR check_collide_down
    CMP #$00
    BNE nscdownelse
        DOWN_BUTTON_DOWN dbnotdown

        dbnotdown:
        JMP nscdownendif
    nscdownelse:
        IF_SIGNED_GT_OR_EQU gravity, #$00, nscdownendif
            IF_SIGNED_LT gravity, #$7F, nscdownendif
                LDA coord_y
                ASL a
                ASL a
                ASL a
                STA pos_y
				
                LDA rt_val_1
                CMP #$0A
                BNE elseif
                    LDA #$FA
                    STA gravity
                    LDA #$00
                    STA gravity + 1
                    JMP nscdownendif
                elseif:
                    LDA #$FD
                    STA gravity
                    LDA #$00
                    STA gravity + 1
				
				;respawn
                LDA rt_val_1
                CMP #$0B
                BNE welseif
                    SET_POINTER_TO_LABEL LEVEL_1_MAP_1, current_room, current_room + 1
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
                welseif:
    nscdownendif:

    JSR check_collide_up
    CMP #$00
    BNE nscupelse
        UP_BUTTON_DOWN ubnotdown

        ubnotdown:
        JMP nscupendif
    nscupelse:
        IF_SIGNED_LT_OR_EQU gravity, #$00, nscupendif
            IF_SIGNED_GT gravity, #$80, nscupendif
                LDX coord_y
                INX
                TXA
                ASL a
                ASL a
                ASL a
                STA pos_y

                LDA #$01
                STA gravity
    nscupendif:
	
	LDA pos_x
	STA OAM_RAM_ADDR + 3
	
	LDA pos_y
    STA OAM_RAM_ADDR
	
    LDA scroll_x_type
    BNE right_scroll_map
        IF_UNSIGNED_GT_OR_EQU pos_x, #$7F, scrleftstartelse
            ADD scroll_x, speed_x
            STA scroll_x
            ADD pos_x, speed_x
            STA pos_x
            LDA #$7F
            STA OAM_RAM_ADDR + 3
            IF_SIGNED_LT_OR_EQU scroll_x, #$00, scroll_x_endif
                IF_SIGNED_GT scroll_x, #$F8, scroll_x_endif
                    LDA #$00
                    STA scroll_x
					JMP scroll_x_endif
        scrleftstartelse:
            ADD pos_x, speed_x
            STA pos_x
            STA OAM_RAM_ADDR + 3
            LDA #$00
            STA scroll_x
            JMP scroll_x_endif
    right_scroll_map:
        IF_UNSIGNED_LT_OR_EQU pos_x, #$7F, scrrightstartelse
            ADD scroll_x, speed_x
            STA scroll_x
            ADD pos_x, speed_x
            STA pos_x
            LDA #$7F
            STA OAM_RAM_ADDR + 3
            IF_SIGNED_GT_OR_EQU scroll_x, #$FF, scroll_x_endif
                IF_SIGNED_LT scroll_x, #$08, scroll_x_endif
                    LDA #$FF
                    STA scroll_x
					JMP scroll_x_endif
        scrrightstartelse:
            ADD pos_x, speed_x
            STA pos_x
            STA OAM_RAM_ADDR + 3
            LDA #$FF
            STA scroll_x
    scroll_x_endif:
	
    IF_NOT_EQU scroll_x_type, #$00, ntransleft
    IF_SIGNED_LT speed_x, #$00, ntransleft
        IF_SIGNED_GT speed_x, #$80, ntransleft
            IF_UNSIGNED_GT_OR_EQU pos_x, #$F8, ntransleft
                SET_POINTER_TO_LABEL LEVEL_1_MAP_0, current_room, current_room + 1
				
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
            IF_UNSIGNED_GT_OR_EQU pos_x, #$F8, ntransright
                SET_POINTER_TO_LABEL LEVEL_1_MAP_1, current_room, current_room + 1
				
                LDA #$00
                STA pos_x

                LDA #$80
                STA scroll_x

                LDA #$01
                STA scroll_x_type
    ntransright:
	
    JMP game_loop                   ;jump back to game_loop, infinite loop

;------------------------------------------------------------------------------------;

read_controller:
    ;write $0100 to $4016 to tell the controllers to latch the current button positions (???)
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016
    ;read the button press bit of a, b, start, select, up, down, left, right and store all bits in button_bits

    LDX #$08
    read_loop:
        LDA $4016                   ;load input status byte into register a
        LSR a                       ;shift right by 1 and store what was bit 0 into the carry flag
        ROL button_bits             ;rotate left by 1 and store the previous carry flag in bit 0
        DEX                         ;decreases x by 1 and sets the zero flag if x is 0
        BNE read_loop               ;if the zero flag is not set, keep looping, otherwise end the function
        RTS

;NMI interrupts the cpu and is called once per video frame
;PPU is starting vblank time and is available for graphics updates
NMI:
    ;copies 256 bytes of OAM data in RAM (OAM_RAM_ADDR - OAM_RAM_ADDR + $FF) to the PPU internal OAM
    ;this takes 513 cpu clock cycles and the cpu is temporarily suspended during the transfer

    LDA #$00
    STA OAM_ADDR                   ;sets the low byte of OAM_ADDR to #$00 (the start of internal OAM memory on PPU)

    ;stores the #$02 high byte + #$00 sprite attribs memory address in OAM_DMA and then begins the transfer
    LDA #HIGH(OAM_RAM_ADDR)
    STA OAM_DMA                    ;stores OAM_RAM_ADDR to high byte of OAM_DMA
    ;CPU is now suspended and transfer begins

    ;pseudo
    ;loop through animations here
    ;can check if animation is updated or not by setting a value on the next animation frame change
    ;animation nt pointers are set to the nt position in VRAM + tile offset position
    ;change tile to the animation frames pointer + current frame

    LDA ani_num_running
    ASL a
    TAY
    ani_render_loop:
        ;decreases y by 2 and lazily checks if it has overflowed, if it has go to the end of the render loop
        DEY
        DEY
        CPY #$FE
        BEQ ani_render_loop_end

        SET_POINTER_HI_LO ani_VRAM_pointer, PPU_ADDR, PPU_ADDR
        DEBUG_BRK
        LDA [ani_frames], y
        STA PPU_DATA

        JMP ani_render_loop
    ani_render_loop_end:
    SET_POINTER_TO_LABEL VRAM_NT_0, PPU_ADDR, PPU_ADDR

    LDA scroll_x
    STA $2005
    LDA scroll_y
    STA $2005

    INC vblank_counter              ;increases the vblank counter by 1 so the game loop can check when NMI has been called
	
    RTI                             ;returns from the interrupt

IQR:
    RTI