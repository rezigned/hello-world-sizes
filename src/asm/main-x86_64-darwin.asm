; hello_macos.asm - Hello World in x86-64 assembly for macOS
section .data
    hello db "Hello, World!", 0xA

section .text
    global _main

_main:
    ; write(1, hello, 14)
    mov rax, 0x2000004    ; SYS_write is 0x4 + 0x2000000
    mov rdi, 1            ; stdout
    lea rsi, [rel hello]  ; pointer to hello
    mov rdx, 14           ; length
    syscall

    ; exit(0)
    mov rax, 0x2000001    ; SYS_exit is 0x1 + 0x2000000
    xor rdi, rdi
    syscall
