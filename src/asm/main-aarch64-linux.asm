// hello_linux.asm - Hello World in aarch64 assembly for Linux
.section .data
hello:
    .asciz "Hello, World!\n"

.section .text
.global _start

_start:
    // write(1, hello, 14)
    mov x8, 64          // syscall number (sys_write)
    mov x0, 1           // file descriptor (stdout)
    ldr x1, =hello      // pointer to message
    mov x2, 14          // length of message
    svc #0

    // exit(0)
    mov x8, 93          // syscall number (sys_exit)
    mov x0, 0           // exit code
    svc #0
