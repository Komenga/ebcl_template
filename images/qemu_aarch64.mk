# Makefile for runnung QEMU amd64 images

#-------------------
# Run the QEMU image
#-------------------

# QEMU kernel commandline
ifeq ($(kernel_cmdline),)
kernel_cmdline = console=ttyAMA0
endif

ifeq ($(kernel_cmdline_append),)
kernel_cmdline_append = 
endif

ifeq ($(qemu_net_append),)
qemu_net_append = ,hostfwd=tcp::2222-:22
endif

.PHONY: qemu
qemu: $(kernel) $(initrd_img) $(disc_image)
	@echo "Running $(disc_image) in QEMU aarch64..."
	qemu-system-aarch64 \
		-machine virt -cpu cortex-a72 -machine type=virt -nographic -m 4G \
		-netdev user,id=mynet0$(qemu_net_append) \
		-device virtio-net-pci,netdev=mynet0 \
		-kernel $(kernel) \
		-append "$(kernel_cmdline) $(kernel_cmdline_append)" \
		-initrd $(initrd_img) \
		-drive format=raw,file=$(disc_image),if=virtio

.PHONY: qemu_efi
qemu_efi: $(disc_image)
	@echo "Running $(disc_image) in QEMU aarch64 using EFI loader..."	
	qemu-system-aarch64 \
        -machine virt \
        -cpu cortex-a72 \
        -m 4096 \
        -nographic \
        -netdev user,id=mynet0$(qemu_net_append) \
        -device virtio-net-pci,netdev=mynet0 \
        -drive format=raw,file=$(disc_image),if=virtio
		-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd