# check if build directory exists. Else, create it
if [ ! -d "build" ]
then
    mkdir build
fi

# assemble and build the interpreter
nasm -f elf interpreteur.asm -o build/brainfuck.o
ld -m elf_i386 -s build/brainfuck.o -o build/brainfuck
