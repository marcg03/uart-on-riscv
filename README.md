# Assembly code for QEMU-RISCV32 virt

## Overview

This project contains a program that is intended to run on `virt` of
QEMU-RISCV32.

It writes a single message to the emulated UART device.

## Usage example

Steps to compile:
- `riscv32-none-elf-as start.s -o start.o`
- `riscv32-none-elf-ld -Ttext=0x80000000 --entry=_start start.o -o start.elf`

Example run:
```console
$ qemu-system-riscv32 -M virt -bios none -kernel start.elf -nographic
Hello from UART! This is a long message to test whether FIFO is working correctly! Yapping Yapping Yapping
```

## Implementation TLDR

This implementation sets UART params, PLIC params, the hart's CSRs, and on each
interrupt pushes bytes through the TX FIFO.

> **Limitations**: The implementation is tightly coupled to the specific DTS of
> the `virt` machine (for example UART_BASE, PLIC_BASE etc. are all hardcoded)

## Implementation details

This implementation sets the stack register `sp` and then sets the message and
current index in `s1` and `s0` respectively.

### UART initialization

> **Note:** The emulated UART device is NS16550A compatible.

- configure UART for 8N1 operation at a baud rate of 38400 bps.
- set FIFO enable and clear XMIT FIFO in FCR
- clear LSR register
- enable interrupt for ETBEI in IER

### PLIC initialization

 > **Note:** UART has source ID = 10

- set source 10 priority to 1
- enable source 10 on context 0
- set threshold for context 0 to 0

> **Note**: DTS contains more info about PLIC contexts and wiring of sources

### CSR initialization

This implementation sets `mtvec` to point to `trap_handler`, enables
machine external interrupts via `mie.MEIE` and lastly enables interrupts via
`mstatus.MIE`.

### Interrupt handling and writing the actual message

The `trap_handler` is used to push the message into the TX FIFO, 16 bytes at
a time.

> **Note:** It defensively checks `mcause` (to confirm a machine external
> interrupt) and the source of this interrupt (source 10 corresponding to UART),
> jumping to `bad_hang` if either is unexpected.

## Development environment

For a reproducible environment I used `nix`.

`nix develop` or [nix-direnv](https://github.com/nix-community/nix-direnv) can
be used to get the tools needed for compilation and for running the code.

## AI disclaimer

No AI written code or docs :)
