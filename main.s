global _start

%define BF_INC_DATA_PTR 0 ; '>'
%define BF_DEC_DATA_PTR 1 ; '<'
%define BF_INC_DATA 2 ; '+'
%define BF_DEC_DATA 3 ; '-'
%define BF_OUTPUT 4 ; '.'
%define BF_INPUT 5 ; ','
%define BF_JMP_FWD_IF_ZERO 6 ; '[', inst will be followed by jmp addr
%define BF_JMP_BACK_IF_NOT_ZERO 7 ; ']', inst will be followed by jmp addr

section .rodata

; TODO: read this
PROGRAM: db "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
PROGRAM_END equ $

section .bss

INSTRUCTIONS: resq 1024
INSTRUCTIONS_END equ $

JMP_STACK: resq 1024
JMP_STACK_END equ $

section .data

DATA: times 30000 db 0
DATA_END equ $

section .text

_start:
	; parse bf source
	mov rdi, INSTRUCTIONS
	mov rsi, PROGRAM
	mov rdx, JMP_STACK
.read_input_char:
	mov al, [rsi]
	call char_to_inst
	cmp rdi, INSTRUCTIONS_END-8
	jge exit_error
	cmp rdx, JMP_STACK_END
	jge exit_error
	inc rsi
	cmp rsi, PROGRAM_END
	jl .read_input_char
	cmp rdx, JMP_STACK
	; open bracket with no close bracket
	jne exit_error

	; interpret instructions
	; ptr to last inst
	mov r8, rdi
	mov rdi, INSTRUCTIONS
	mov rax, DATA
.interpret_inst:
	call interpret_inst
	cmp rax, DATA_END
	jge exit_error
	cmp rax, DATA
	jl exit_error
	cmp rdi, r8
	jle .interpret_inst

	mov rax, 60
	xor rdi, rdi
	syscall

exit_error:
	mov rax, 60
	mov rdi, 1
	syscall

; param rax: data ptr
; param rdi: instruction ptr
; modifies: rax, rsi, rdi, rdx, rcx, r11, flags
interpret_inst:
	mov rdx, [rdi]
	lea rdx, [.jump_table+rdx*8]
	jmp [rdx]

section .data
.jump_table: dq .inc_data_ptr, .dec_data_ptr, .inc_data, .dec_data, .output, .input, .jmp_fwd_if_zero, .jmp_back_if_not_zero
section .text

.jmp_fwd_if_zero:
	mov dl, [rax]
	cmp dl, 0
	je .change_jmp_addr
	jmp .exit_double_len_inst
.jmp_back_if_not_zero:
	mov dl, [rax]
	cmp dl, 0
	jne .change_jmp_addr
	jmp .exit_double_len_inst
.change_jmp_addr:
	mov rdi, [rdi+8]
	ret
.inc_data_ptr:
	inc rax
	jmp .exit
.dec_data_ptr:
	dec rax
	jmp .exit
.inc_data:
	mov dl, [rax]
	inc dl
	mov [rax], dl
	jmp .exit
.dec_data:
	mov dl, [rax]
	dec dl
	mov [rax], dl
	jmp .exit
.output:
	push rax
	push rdi
	; write(STDOUT, rax, 1)
	mov rsi, rax
	mov rax, 1
	mov rdi, 1
	mov rdx, 1
	syscall
	pop rdi
	pop rax
	jmp .exit
.input:
	push rax
	push rdi
	; read(STDIN, rax, 1)
	mov rsi, rax
	mov rax, 0
	mov rdi, 0
	mov rdx, 10
	syscall
	pop rdi
	pop rax
	jmp .exit
.exit_double_len_inst:
	add rdi, 16
	ret
.exit:
	add rdi, 8
	ret

; param al: char
; param rdi: ptr to next instruction, caller must ensure 2 qwords are free
; param rdx: ptr to jmp stack, caller must ensure 1 free qword
; modifies: flags, rdi, rdx
char_to_inst:
	cmp al, '>'
	je .gt
	cmp al, '<'
	je .lt
	cmp al, '+'
	je .plus
	cmp al, '-'
	je .minus
	cmp al, '.'
	je .dot
	cmp al, ','
	je .comma
	cmp al, '['
	je .open_bracket
	cmp al, ']'
	je .close_bracket
	jmp .exit
.gt:
	mov qword [rdi], BF_INC_DATA_PTR
	jmp .exit
.lt:
	mov qword [rdi], BF_DEC_DATA_PTR
	jmp .exit
.plus:
	mov qword [rdi], BF_INC_DATA
	jmp .exit
.minus:
	mov qword [rdi], BF_DEC_DATA
	jmp .exit
.dot:
	mov qword [rdi], BF_OUTPUT
	jmp .exit
.comma:
	mov qword [rdi], BF_INPUT
	jmp .exit
.open_bracket:
	mov qword [rdi], BF_JMP_FWD_IF_ZERO
	; leave uninitialised ptr
	add rdi, 16
	; push ptr to next inst
	mov qword [rdx], rdi
	add rdx, 8
	ret
.close_bracket:
	mov qword [rdi], BF_JMP_BACK_IF_NOT_ZERO
	; pop ptr to inst after [
	sub rdx, 8
	cmp rdx, JMP_STACK
	; close bracket with no open bracket
	jl exit_error
	mov rbx, [rdx]
	mov qword [rdi+8], rbx
	; initialise ptr for [ to next inst
	add rdi, 16
	mov qword [rbx-8], rdi
	ret
.exit:
	add rdi, 8
	ret

; # vim:ft=nasm
