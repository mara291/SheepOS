ASM = nasm
DD = dd
VBOXMANAGE = VBoxManage
VM_NAME = MyOS100
IMG_NAME = myos100.img
VDI_NAME = myos100.vdi
IMG_SIZE = 1M

all: build_img

# Create a VM
initialize: build_img create_vdi create_vm setup_vm
# Build image and attach to VDI
build: build_img detach_vdi modify_vdi setup_vm
# Run VM
run: run_vm

# Assemble bootloader
bootloader.bin: bootloader.asm
	$(ASM) -f bin bootloader.asm -o bootloader.bin

# Assemble second sector
sector2.bin: sector2.asm
	$(ASM) -f bin sector2.asm -o sector2.bin

# Create a raw disk image
build_img: bootloader.bin sector2.bin
	rm -f $(IMG_NAME)
	$(DD) if=/dev/zero of=$(IMG_NAME) bs=512 count=2048
	$(DD) if=bootloader.bin of=$(IMG_NAME) bs=512 count=1 seek=0 conv=notrunc
	$(DD) if=sector2.bin of=$(IMG_NAME) bs=512 count=5 seek=1 conv=notrunc 

# Create VDI (first-time setup)
create_vdi: build_img
	$(VBOXMANAGE) convertfromraw $(IMG_NAME) $(VDI_NAME) --format VDI

# Modify VDI - Instead of resizing, detach the old one and replace it
modify_vdi: build_img
	$(VBOXMANAGE) closemedium disk $(VDI_NAME) --delete || true  # Close old disk if exists
	$(VBOXMANAGE) convertfromraw $(IMG_NAME) $(VDI_NAME) --format VDI

# Create a new VM (only if it does not exist)
create_vm:
	$(VBOXMANAGE) createvm --name $(VM_NAME) --register
	$(VBOXMANAGE) modifyvm $(VM_NAME) --memory 32 --boot1 disk
	$(VBOXMANAGE) storagectl $(VM_NAME) --name "SATA Controller" --add sata --controller IntelAhci

# Attach the VDI file to an existing VM
setup_vm:
	$(VBOXMANAGE) storageattach $(VM_NAME) --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $(VDI_NAME)

# Detach the VDI (so it can be replaced)
detach_vdi:
	$(VBOXMANAGE) storageattach $(VM_NAME) --storagectl "SATA Controller" --port 0 --device 0 --medium none || true

# Start the VM
run_vm:
	$(VBOXMANAGE) startvm $(VM_NAME) --type gui

# Clean vm and vdi
clean_all: clean
	rm -f $(IMG_NAME) $(VDI_NAME)
	$(VBOXMANAGE) unregistervm $(VM_NAME) --delete 2>/dev/null || true

# Clean up
clean:
	rm -f bootloader.bin sector2.bin 
