; hello.asm - Hello World in x86-64 assembly for Linux
; System call numbers:
; 1 = write
; 60 = exit

section .data
    ; Define the message to print
    message db "Hello, World!", 10  ; 10 is the ASCII code for newline
    message_length equ $ - message  ; Calculate length of the message

section .text
    global _start                   ; Entry point for the linker

_start:
    ; Write the message to stdout (file descriptor 1)
    mov rax, 1                      ; syscall number for write
    mov rdi, 1                      ; file descriptor 1 is stdout
    mov rsi, message                ; pointer to the message
    mov rdx, message_length         ; message length
    syscall                         ; call kernel

    ; Exit the program with status code 0
    mov rax, 60                     ; syscall number for exit
    mov rdi, 0                      ; exit status 0 (success)
    syscall                         ; call kernel
