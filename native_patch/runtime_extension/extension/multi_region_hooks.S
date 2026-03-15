.intel_syntax noprefix
.text

.extern coop_evaluate_multi_region_radius

.extern g_coop_update_hook_0_inside
.extern g_coop_update_hook_0_outside
.extern g_coop_update_hook_1_inside
.extern g_coop_update_hook_1_outside
.extern g_coop_update_hook_2_inside
.extern g_coop_update_hook_2_outside
.extern g_coop_update_hook_3_inside
.extern g_coop_update_hook_3_outside
.extern g_coop_update_hook_4_inside
.extern g_coop_update_hook_4_outside
.extern g_coop_simulate_hook_1_inside
.extern g_coop_simulate_hook_1_outside
.extern g_coop_simulate_hook_2_inside
.extern g_coop_simulate_hook_2_outside

.global coop_update_radius_hook_1
.global coop_update_radius_hook_2
.global coop_update_radius_hook_3
.global coop_update_radius_hook_4
.global coop_update_radius_hook_5
.global coop_simulate_radius_hook_1
.global coop_simulate_radius_hook_2

coop_update_radius_hook_1:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, rdi
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 0
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lupdate1_inside
    mov rax, qword ptr [rip + g_coop_update_hook_0_outside]
    jmp rax
.Lupdate1_inside:
    mov rax, qword ptr [rip + g_coop_update_hook_0_inside]
    jmp rax

coop_update_radius_hook_2:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, rdi
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 1
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lupdate2_inside
    mov rax, qword ptr [rip + g_coop_update_hook_1_outside]
    jmp rax
.Lupdate2_inside:
    mov rax, qword ptr [rip + g_coop_update_hook_1_inside]
    jmp rax

coop_update_radius_hook_3:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, rdi
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 2
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lupdate3_inside
    mov rax, qword ptr [rip + g_coop_update_hook_2_outside]
    jmp rax
.Lupdate3_inside:
    mov rax, qword ptr [rip + g_coop_update_hook_2_inside]
    jmp rax

coop_update_radius_hook_4:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, rdi
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 3
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lupdate4_inside
    mov rax, qword ptr [rip + g_coop_update_hook_3_outside]
    jmp rax
.Lupdate4_inside:
    mov rax, qword ptr [rip + g_coop_update_hook_3_inside]
    jmp rax

coop_update_radius_hook_5:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, rdi
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 4
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lupdate5_inside
    mov rax, qword ptr [rip + g_coop_update_hook_4_outside]
    jmp rax
.Lupdate5_inside:
    mov rax, qword ptr [rip + g_coop_update_hook_4_inside]
    jmp rax

coop_simulate_radius_hook_1:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, r14
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 5
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lsimulate1_inside
    mov rax, qword ptr [rip + g_coop_simulate_hook_1_outside]
    jmp rax
.Lsimulate1_inside:
    mov rax, qword ptr [rip + g_coop_simulate_hook_1_inside]
    jmp rax

coop_simulate_radius_hook_2:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    mov rcx, r14
    lea rdx, [rsp + 80]
    mov r8, rbp
    mov r9d, 6
    call coop_evaluate_multi_region_radius
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    test al, al
    jne .Lsimulate2_inside
    mov rax, qword ptr [rip + g_coop_simulate_hook_2_outside]
    jmp rax
.Lsimulate2_inside:
    mov rax, qword ptr [rip + g_coop_simulate_hook_2_inside]
    jmp rax
