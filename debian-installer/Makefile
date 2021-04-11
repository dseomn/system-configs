# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

all: install.iso unmount

.PHONY: install-dependencies
install-dependencies:
	sudo apt install isolinux xorriso

base: base.iso
	mkdir -p base
	sudo mount -o loop,ro base.iso base

overlay: base
	mkdir -p overlay/upper overlay/work overlay/merged
	sudo mount -t overlay overlay overlay/merged -o \
		lowerdir=cdrom:base,upperdir=overlay/upper,workdir=overlay/work

inst-data.img:
	/sbin/mkfs.fat -C -n INST-DATA "$@.new" $$((32 * 1024))
	mkdir -p inst-data.mnt
	sudo mount -o loop "$@.new" inst-data.mnt
	sudo cp -r inst-data/* inst-data.mnt
	sudo umount inst-data.mnt
	mv -f "$@.new" "$@"

install.iso: overlay inst-data.img
	sudo chown -R $$USER: overlay/merged/boot/grub overlay/merged/isolinux
	chmod -R u+w overlay/merged/boot/grub overlay/merged/isolinux
	cd overlay/merged && ../../patch-bootloader
	rm -f overlay/merged/md5sum.txt
	cd overlay/merged && \
		find -L . -type f -exec md5sum '{}' + > md5sum.txt || true
	xorriso \
		-as mkisofs \
		-o "$@" \
		-r \
		-V DEBIAN-INST \
		-J \
		-joliet-long \
		-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
		-c isolinux/boot.cat \
		-b isolinux/isolinux.bin \
		-boot-load-size 4 \
		-boot-info-table \
		-no-emul-boot \
		-eltorito-alt-boot \
		-e boot/grub/efi.img \
		-no-emul-boot \
		-isohybrid-gpt-basdat \
		-isohybrid-apm-hfsplus \
		-append_partition 3 FAT16 inst-data.img \
		overlay/merged

.PHONY: unmount
unmount: install.iso
	sudo umount -q overlay/merged || true
	sudo umount -q base || true
