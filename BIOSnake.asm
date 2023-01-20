[ORG 0x7C00]
[BITS 16]

SETUP:
	XOR AX, AX
	MOV DS, AX
	MOV ES, AX
	MOV SS, AX
	MOV SP, 0x7C00
	MOV BP, SP ; Initialise the segments.

	MOV AX, 0x1003
	MOV BL, 0x00
	INT 0x10 ; Turn off blinking attribute.

	MOV BX, SNAKE_BODY
	MOV CX, 4000 
	CALL MEMINIT ; Initialises the snake body to a known value.

	MOV SI, ANY_KEY_MSG
	CALL PUTS

	MOV AH, 0x00
	INT 0x16 ; Wait for the user to start the game.

START_GAME:
	MOV AH, 0x00
	MOV AL, 0x01
	INT 0x10 ; Set display to 40x25 and 16 bits of colour.

	MOV AH, 0x01
	MOV CX, 0x2607
	INT 0x10 ; Make the cursor invisible.

GET_KEY:
	MOV AH, 0x01
	INT 0x16 ; Get the key status.

	MOV AL, BYTE[LAST_KEY] ; Load the last key pressed in case we don't have any keys to read.

	JZ DIRECTION_SWITCH ; If we don't have any keys to read.

	MOV AH, 0x00
	INT 0x16 ; We have keys to read so we read the key.

	OR AL, 0B00100000 ; Convert it to lowercase.

DIRECTION_SWITCH:
	MOV DX, WORD[HEAD_COORDS] ; Load the head coordinates for later.

	CMP AL, 'w'
	JE GO_UP

	CMP AL, 'a'
	JE GO_LEFT

	CMP AL, 's'
	JE GO_DOWN

	CMP AL, 'd'
	JE GO_RIGHT

	JMP GET_KEY ; This means none of the correct keys were pressed so we wait for more.

GO_LEFT:
	CMP BYTE[LAST_KEY], 'd'
	JE GET_KEY

	DEC DL
	JMP SHORT MOVE

GO_RIGHT:
	CMP BYTE[LAST_KEY], 'a' ; So you can't go backwards and hit yourself.
	JE GET_KEY

	INC DL
	JMP SHORT MOVE

GO_UP:
	CMP BYTE[LAST_KEY], 's'
	JE GET_KEY

	DEC DH
	JMP SHORT MOVE

GO_DOWN:
	CMP BYTE[LAST_KEY], 'w'
	JE GET_KEY

	INC DH ; Moving the snake, pretty self explanatory.

MOVE:
	MOV BYTE[LAST_KEY], AL ; Save the valid key.
	MOV WORD[HEAD_COORDS], DX ; Save the new head location.

	MOV AL, ' ' ; Make it so the characters don't interfere.
	MOV CX, 1 ; We want to print 1 block.

	MOV BX, SNAKE_BODY ; The location of the snake body.
	PUSH BX

	MOV DI, WORD[SNAKE_LENGTH]
	DEC DI
	SHL DI, 1
	ADD BX, DI ; Calculate the last snake segment location.

	PUSH DX

	MOV DX, WORD[BX]
	MOV BX, 0x0007
	CALL WRITE_AT_LOCATION ; Clear the last snake segment location.

	POP DX
	POP BX ; Restore our registers.

	MOV DI, WORD[SNAKE_LENGTH]

MOVE_LOOP:
	MOV SI, WORD[BX] ; Load the current value pointed by BX.

	MOV WORD[BX], DX ; Store the new value.
	ADD BX, 2 ; Move BX by a word.

	MOV DX, SI

	DEC DI ; Check if we have snake segments to update.
	JNZ CHECK_COLLISION
	JMP CHECK_FRUIT_OVERLAP ; This is done to fix an issue where collision is incorrectly detected if trailing the last snake piece.

CHECK_COLLISION:
	MOV SI, WORD[HEAD_COORDS]
	CMP SI, DX
	JE DEAD ; If the head and segments overlap the player lost. 

	JMP MOVE_LOOP ; Do this for n more segments.

CHECK_FRUIT_OVERLAP:
	MOV BX, 0x0027
	MOV DX, WORD[HEAD_COORDS]
	CALL WRITE_AT_LOCATION ; Write the snake head.
	
	CMP DL, 0
	JL DEAD 

	CMP DL, 40
	JGE DEAD 

	CMP DH, 0
	JL DEAD 

	CMP DH, 25
	JGE DEAD ; Checks if we went out of the screen.

	CMP DX, WORD[FRUIT_COORDS]
	JNE DISPLAY_FRUIT ; If the head and fruit coords are equal we don't jump.

	MOV AH, 0x00
	INT 0x1A ; Get the number of clock ticks since midnight.

	MOV AX, DX
	ADD CX, DX ; Add DX to CX to make it more "random".

	XOR DX, DX

	MOV BX, 25
	DIV BX ; Get the remainder of the y coordinate.

	MOV AX, CX

	SHL DX, 8
	MOV CX, DX ; Save the remainder for later.

	XOR DX, DX
	
	MOV BX, 40
	DIV BX ; Get the remainder of the x coordinate.

	OR DX, CX

	MOV BX, SNAKE_BODY
	MOV DI, WORD[SNAKE_LENGTH]

CHECK_FRUIT_COLLISION:
	CMP DX, WORD[BX]
	JNE NO_FRUIT_COLLISION ; If the fruit overlaps with the snake we have to displace it by 1.

	INC DL
	CMP DL, 40 
	JNE DL_DH_NO_OVERFLOW ; Check if the x coordinate overflows.

	XOR DL, DL ; If it does clear it.

	INC DH
	CMP DH, 25
	JNE DL_DH_NO_OVERFLOW ; Check if the y coordinate overflows.

	XOR DH, DH

DL_DH_NO_OVERFLOW:
	MOV BX, SNAKE_BODY ; Load the original values to repeat the loop.
	MOV DI, WORD[SNAKE_LENGTH]
	JMP CHECK_FRUIT_COLLISION

NO_FRUIT_COLLISION:
	ADD BX, 2
	DEC DI
	JNZ CHECK_FRUIT_COLLISION ; If DI is zero it means that the fruit doesn't overlap with the snake.

	MOV WORD[FRUIT_COORDS], DX ; Save the new coordinate.
	INC WORD[SNAKE_LENGTH] ; Increment the snake lenght.

	MOV AL, ' '
	MOV CX, 1

DISPLAY_FRUIT:
	MOV BX, 0x0047
	MOV DX, WORD[FRUIT_COORDS]
	CALL WRITE_AT_LOCATION ; Display the fruit.

	MOV AH, 0x86
	MOV CX, 0x0002
	MOV DX, 0x49F0
	INT 0x15 ; BIOS wait interrupt (waits for 150ms).

	JMP GET_KEY

DEAD:
	MOV AH, 0x02
	XOR BX, BX
	MOV DX, 0x0B05
	INT 0x10 ; Change cursor location to around the middle of the screen.

	MOV SI, DEAD_MSG
	CALL PUTS

	MOV WORD[SNAKE_LENGTH], 1 ; Reset the snake length.
	MOV WORD[HEAD_COORDS], (12 << 8) | 20 ; Set the head coords to somewhere at the middle of the screen.

WAIT_FOR_R:
	MOV AH, 0x00
	INT 0x16 ; Wait for any key to be pressed.

	OR AL, 0B00100000 ; Make the character lowercase.

	CMP AL, 'r'
	JE START_GAME ; If it's r then reset the game, else wait again.
	JMP WAIT_FOR_R 
	
HALT:
	HLT
	JMP HALT

; Writes n amount of coloured characters on a given location.
;
; AL -> Character.
; BH -> Page.
; BL -> Colour.
; CX -> Number of characters.
; DH -> Row.
; DL -> Column.
WRITE_AT_LOCATION:
	PUSH AX

	MOV AH, 0x02
	INT 0x10

	MOV AH, 0x09
	INT 0x10

	POP AX
	RET

; Prints a null terminated string on the screen.
;
; SI -> The location of the string in RAM.
PUTS:
	PUSH AX
	PUSH SI
	MOV AH, 0x0E

.LOOP:
	LODSB
	OR AL, AL
	JZ .OUT
	INT 0x10
	JMP .LOOP

.OUT:
	POP SI
	POP AX
	RET

; Initialises an array to a nice value.
;
; BX -> Array location.
; CX -> Number of bytes to intialise. 
MEMINIT:
	PUSH BX
	PUSH CX

.LOOP:
	MOV BYTE[BX], 69 
	INC BX
	DEC CX
	JNZ .LOOP

	POP CX
	POP BX
	RET

LAST_KEY: DB 'a'

SNAKE_LENGTH: DW 1 
HEAD_COORDS:
HEAD_X: DB 20
HEAD_Y: DB 12

FRUIT_COORDS:
FRUIT_X: DB 9
FRUIT_Y: DB 12 

ANY_KEY_MSG: DB "Snake controls => W, A, S, D.", 0x00
DEAD_MSG: DB "Game over, press r to restart.", 0x00

TIMES 510 - ($ - $$) DB 0
DW 0xAA55

SNAKE_BODY:
