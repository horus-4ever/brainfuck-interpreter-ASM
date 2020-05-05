nasm -f elf interpreteur.asm -o build/brainfuck.o
ld -m elf_i386 -s build/brainfuck.o -o build/brainfuck
