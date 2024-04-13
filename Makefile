EXECUTABLE = main

.PHONY: all clean

all: $(EXECUTABLE)

$(EXECUTABLE): main.o
	$(LD) main.o -o $(EXECUTABLE)

clean:
	$(RM) *.o

%.o: %.s
	nasm -g -f elf64 $^ -o $@

