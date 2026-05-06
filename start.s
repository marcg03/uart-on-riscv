.section .text
.global _start
_start:
    lui sp, 0x88000
    addi sp, sp, -16 # initialize stack register

    addi s0, x0, 0x0 # s0 will be the index for iterating through s1 which holds the message
1:
    auipc s1, %pcrel_hi(msg)
    addi  s1, s1, %pcrel_lo(1b)

    lui t0, 0x10000 # set t0 to UART_BASE
    addi t0, t0, 0x3 # offset t0 to LCR address
    addi t1, x0, 0x80 # set only bit 7 representing DLAB
    sb t1, 0(t0) # set DLAB=1

    addi t0, t0, -3 # set t0 to DLL address
    addi t1, x0, 0x6 # set t1 to 0x6
    sb t1, 0(t0) # set DLL=6

    addi t0, t0, 0x1 # set t0 to DLM address
    sb x0, 0(t0) # set DLM=0

    addi t0, t0, 0x2 # set t0 to LCR address
    addi t1, x0, 0x3 # set t1 to represent 8N1
    sb t1, 0(t0) # set LCR to 8N1

    addi t0, t0, -1 # set t0 to FCR address
    addi t1, x0, 0x5 # set t1 to represent FIFO enable and clear XMIT FIFO
    sb t1, 0(t0) # set FCR

    addi t0, t0, 0x3 # set t0 to LSR address
    lbu x0, 0(t0) # read LSR => clean LSR

    addi t0, t0, -4 # set t0 to IER address
    addi t1, x0, 0x2 # set t1 to represent ETBEI only
    sb t1, 0(t0) # set IER with only ETBEI

    lui t0, 0xc000 # set t0 to PLIC_BASE
    addi t0, t0, 0x028 # offset t0 to source 10 priority register's address
    addi t1, x0, 0x1 # set t1 to equal 1
    sw t1, 0(t0) # set source 10 priority register to equal 1

    lui t0, 0xc002 # set t0 to address of enable bits for sources 0-31 on context 0
    addi t1, x0, 0x400 # store enable bit for source 10
    sw t1, 0(t0) # set enable bit for source 10

    lui t0, 0xc200 # address of threshold register for context 0
    sw x0, 0(t0) # set threshold for context 0

1:
    auipc t0, %pcrel_hi(trap_handler)
    addi t0, t0, %pcrel_lo(1b) # set t0 to trap handler's address
    csrrw x0, mtvec, t0 # set mtvec to trap handler's address

    addi t0, x0, 1
    slli t0, t0, 11
    csrrw x0, mie, t0 # set mie with only MEIE=1

    addi t0, x0, 0x8
    csrrs x0, mstatus, t0 # set mstatus' MIE=1

hang:
    wfi # wait for interrupt
    jal x0, hang

bad_hang:
    li t0, 0xcafebabe
    jal x0, bad_hang

trap_handler:
    addi sp, sp, -32
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)
    sw t3, 12(sp)
    sw t4, 16(sp)

    csrrs t0, mcause, x0 # set t0 to mcause
    lui t1, 0x80000 # set mcause interrupt bit
    addi t1, t1, 0xb # set t1 to represent M-mode
    bne t0, t1, bad_hang # if not M-mode then hang

    lui t0, 0xc200
    addi t0, t0, 0x4 # set t0 to address of claim/complete for context 0
    lw t1, 0(t0) # read source ID into t1

    beq t1, x0, cleanup # if source 0 then no interrupt then cleanup

    addi t2, x0, 0xa # set t2 to represent source 10
    bne t1, t2, bad_hang # if not source 10 then hang

    lui t1, 0x10000 # set t1 to UART_BASE
    addi t1, t1, 0x2 # offset t1 to IIR address
    lbu t1, 0(t1) # read IIR into t1
    addi t2, x0, 0xce # set t2 to mask for IIR
    and t1, t1, t2 # keep only relevant bits of IIR into t1
    addi t2, x0, 0xc2
    bne t1, t2, bad_hang

    addi t3, x0, 16
write_chunk:
    beq t3, x0, cleanup

    add t1, s1, s0 # t1 = msg + index
    lbu t2, 0(t1) # t2 = msg[index]
    beq t2, x0, cleanup_inter # null terminator => jump to cleanup and disable interrupt

    lui t4, 0x10000 # set t4 to UART_BASE
    sb t2, 0(t4)

    addi s0, s0, 1
    addi t3, t3, -1
    jal x0, write_chunk

cleanup_inter:
    lui t1, 0xc002 # set t1 to address of enable bits for sources 0-31 on context 0
    sw x0, 0(t1) # disable source 10

    lui t1, 0x10000 # set t1 to UART_BASE
    addi t1, t1, 0x1 # offset t1 to IER address
    sb x0, 0(t1) # disable all interrupts

cleanup:
    addi t1, x0, 0xa # set t1 to represent source 10
    sw t1, 0(t0) # write completion for source 10

    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    lw t3, 12(sp)
    lw t4, 16(sp)
    addi sp, sp, 32
    mret

.section .data
msg:
    .asciz "Hello from UART! This is a long message to test whether FIFO is working correctly! Yapping Yapping Yapping\n"
