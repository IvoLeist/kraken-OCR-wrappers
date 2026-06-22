include .env
export

.PHONY: \
	check-colab-bridge \
	link-colab-bridge \
	switch-to-colab-bridge \
	dry-sync-local-to-colab-bridge \
	sync-local-to-colab-bridge \
	restore-local-from-colab-bridge

check-colab-bridge:
	@echo "Local Drive bridge:  $(LOCAL_COLAB_BRIDGE_TARGET)"
	@echo "Remote Colab bridge: $(REMOTE_COLAB_BRIDGE)"
	@echo "Bridge dirs:         $(COLAB_BRIDGE_DIRS)"
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "$$dir:"; \
		if [ -L "$$dir" ]; then \
			echo "  symlink -> $$(readlink "$$dir")"; \
		elif [ -d "$$dir" ]; then \
			echo "  real local directory"; \
		elif [ -e "$$dir" ]; then \
			echo "  exists but is not a directory"; \
		else \
			echo "  missing"; \
		fi; \
		if [ -d "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir" ]; then \
			echo "  Drive target exists: $(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
		else \
			echo "  Drive target missing: $(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
		fi; \
	done

# Drive folder already exists or may be empty.
# Just create repo symlinks.
link-colab-bridge:
	mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)"
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "Linking $$dir"; \
		mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
		if [ -e "$$dir" ] && [ ! -L "$$dir" ]; then \
			echo "  Error: $$dir exists and is a real local path."; \
			echo "  To preserve and upload its contents first, run:"; \
			echo "    make switch-to-colab-bridge"; \
			echo "  Or move/remove $$dir manually before linking."; \
			exit 1; \
		fi; \
		ln -sfn "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir" "$$dir"; \
		echo "  $$dir -> $(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
	done

# Copy real local folders to Drive, then replace them with symlinks.
switch-to-colab-bridge: sync-local-to-colab-bridge
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "Switching $$dir to Colab bridge"; \
		if [ -L "$$dir" ]; then \
			echo "  $$dir is already a symlink."; \
		elif [ -d "$$dir" ]; then \
			mv "$$dir" "$$dir.local-backup"; \
			ln -sfn "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir" "$$dir"; \
			echo "  Moved $$dir to $$dir.local-backup and created symlink."; \
		else \
			ln -sfn "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir" "$$dir"; \
			echo "  Created symlink: $$dir"; \
		fi; \
	done

dry-sync-local-to-colab-bridge:
	mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)"
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "Dry-run syncing local $$dir -> Google Drive"; \
		if [ ! -d "$$dir" ] || [ -L "$$dir" ]; then \
			echo "  Skipping $$dir: not a real local directory."; \
			continue; \
		fi; \
		mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
		rsync -avhn --delete "$$dir/" "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir/"; \
	done

sync-local-to-colab-bridge:
	mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)"
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "Syncing local $$dir -> Google Drive"; \
		if [ -L "$$dir" ]; then \
			echo "  Error: $$dir is a symlink. Refusing to sync symlink source."; \
			echo "  Use a real local folder as the source."; \
			exit 1; \
		fi; \
		if [ ! -d "$$dir" ]; then \
			echo "  Error: $$dir is not a local directory."; \
			exit 1; \
		fi; \
		mkdir -p "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
		rsync -avh --delete "$$dir/" "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir/"; \
	done

# Copy Drive contents back, remove symlinks, and restore real local folders.
restore-local-from-colab-bridge:
	@for dir in $(COLAB_BRIDGE_DIRS); do \
		echo ""; \
		echo "Restoring $$dir from Google Drive to a real local folder"; \
		if [ ! -d "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir" ]; then \
			echo "  Error: Drive folder does not exist: $(LOCAL_COLAB_BRIDGE_TARGET)/$$dir"; \
			exit 1; \
		fi; \
		tmp_dir="$$dir.local-restore-tmp"; \
		rm -rf "$$tmp_dir"; \
		mkdir -p "$$tmp_dir"; \
		rsync -avh "$(LOCAL_COLAB_BRIDGE_TARGET)/$$dir/" "$$tmp_dir/"; \
		if [ -L "$$dir" ]; then \
			rm "$$dir"; \
		elif [ -e "$$dir" ]; then \
			echo "  Error: $$dir exists and is not a symlink. Refusing to overwrite."; \
			rm -rf "$$tmp_dir"; \
			exit 1; \
		fi; \
		mv "$$tmp_dir" "$$dir"; \
		echo "  Restored real local folder: $$dir"; \
	done