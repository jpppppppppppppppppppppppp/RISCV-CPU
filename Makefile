all:
	mkdir ./riscv/testspace
	cd ./riscv && make build_sim
	cp ./riscv/testspace/test code