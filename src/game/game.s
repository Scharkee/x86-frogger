.file "src/game/game.s"

.global gameInit
.global gameLoop

.section .game.data

f:          .asciz "%u"
tick:       .quad 0
gameStage:  .quad 0
stateDirty: .quad 0                     # rendering flag
switchStage:.quad 0                     # set to 1 if switching stages
number:     .asciz "%u"

.align 16
menutbl:
    .quad _menu					        # 0 (for gameInit spillover)
    .quad _menu					        # 1
    .quad _play_loop          			# 2 - 1 on top key row
    .quad _highscores_loop          	# 3 - 2 on top key row
    .quad quit          				# 4 - 3 on top key row
    .skip 251*8

.section .game.text

gameInit:
    # setting program stage to 0, menu.
    # NOTE: spill over, gameInit is not always first
    movq    $1,	(gameStage)
    movq    $1,	(stateDirty)

    movq    $0, (shiftCounter)      # setting initial shift counter+ceiling
    movq    $0, (highscoreCurrent)     
    movq    $50, (shiftCeiling)

    #movq	$2993182, %rdi
    #call	setTimer

    # Disable the blinking cursor
    movq    $0x3D4, %rdx            # address port
    movq    $0xA, %rax              # 0xA is the cursor config
    outb    %al, %dx                # indicate that we want to write to VGA BIOS config address 0xA
    incq    %rdx                    # increase port address to the VGA BIOS data
    movq    $0x20, %rax             # 0x20 is bit 5 set, which means: disable cursor
    outb    %al, %dx                # write the value to the VGA BIOS config

    retq

gameLoop:

    pushq   %rbp
    movq    %rsp, %rbp

    # Set stateDirty if we just switched the stage
    cmpq    $0, (switchStage)
    je      _gameLoop_no_stage_switch
    movq    $1, (stateDirty)
    movq    $0, (switchStage)
    _gameLoop_no_stage_switch:

    # Decide on the game stage
    movq	(gameStage), %rax
    movq    menutbl(,%rax,8), %rax  # do the lookup in the jump table
    testq   %rax, %rax              # check if the current char is a valid action
    jz      _stage_handler_done     # if not, act like we did nothing
    jmpq    *%rax

    _stage_handler_done:

    movq    $0, (stateDirty)        # at the end of the tick, must reset stateDirty, because everything should have been rendered by now

    # Debug tick counter (draw over everything)
    movq    $0, %rsi            # x = 0
    movq    $24, %rdx           # y = 24
    movq    $0x0F, %rcx         # black background, white foreground
    movq    (tick), %r8
    movq    $number, %rdi
    call    printf_coords
    incq    (tick)

    movq    %rbp, %rsp
    popq    %rbp

    retq

#########################
# Game stage offloaders #
#########################

    #
    # MENU STAGE
    #
    _menu: 

    call    listenMenu              # listen before showing, because a key may have been pressed which makes the state dirty
    call 	showMenu                # show the actual menu

    jmp     _stage_handler_done
    
    #
    # PLAY STAGE
    #
    _play_loop:
    call    logic
    call    render                  # render the current game state
    jmp     _stage_handler_done

    #
    # HIGHSCORE STAGE
    #
    _highscores_loop:

    call    listenHighscores         # listen before showing, because a key may have been pressed which makes the state dirty
    call 	showHighscores           # show the highscores

    jmp     _stage_handler_done

quit:
    # QEMU-specific shutdown implementation
    movq    $0x604, %rdx            # address
    movq    $0x2000, %rax           # 0x2000 as data
    outw    %ax, %dx

    # Change to menu just to be sure if this didn't work
    movq    $1, (gameStage)
    movq    $1, (switchStage)

    jmp     _stage_handler_done