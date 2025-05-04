; hello_linux.asm - Hello World in x86-64 assembly for Linux
section .data
    hello db "Hello, World!", 0xA

section .text
    global _start

_start:
    ; write(1, hello, 14)
    mov rax, 1          ; syscall number (sys_write)
    mov rdi, 1          ; file descriptor (stdout)
    mov rsi, hello      ; pointer to message
    mov rdx, 14         ; length of message manually specified
    syscall

    ; exit(0)
    mov rax, 60         ; syscall number (sys_exit)
    xor rdi, rdi        ; exit code 0
    syscall
