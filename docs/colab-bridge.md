# Colab bridge workflow

**Colab bridge mode**
`example_input/` and `output/` are symlinks to matching folders in Google Drive.
This allows files generated in Google Colab to appear locally in VS Code after Google Drive syncs.

The bridge is useful because Google Colab runs on a remote runtime. 
It cannot directly access folders from the local computer, 
but both Colab and the local machine can access the same Google Drive folder.

## Folder layout

Locally, the repository uses folders such as:

```text
example_input/
output/
```

In Colab bridge mode, these folders point to Google Drive folders, for example:

```text
example_input -> /Users/ivo/Google Drive/My Drive/colab_bridge/kraken-ocr/example_input
output        -> /Users/ivo/Google Drive/My Drive/colab_bridge/kraken-ocr/output
```

Inside Google Colab, the same Drive location is available at:

```text
/content/drive/MyDrive/colab_bridge/kraken-ocr
```

## Configuration

Create a local `.env` file in the repository root:

```dotenv
# Local macOS path to the Google Drive-synced bridge folder
LOCAL_COLAB_BRIDGE_TARGET=/Users/ivo/Google Drive/My Drive/colab_bridge/kraken-ocr

# Colab path to the Google Drive-synced bridge folder
REMOTE_COLAB_BRIDGE=/content/drive/MyDrive/colab_bridge/kraken-ocr

# Repository folders that can be bridged through Google Drive
COLAB_BRIDGE_DIRS=example_input output
```

The `.env` file is intended for local use and should usually not be committed.


## Check current bridge status

Run:

```bash
make check-colab-bridge
```

This prints whether each configured folder is currently:

* a real local directory
* a symlink to Google Drive
* missing
* present on Google Drive

Use this before switching modes.

## Switch from local mode to Colab bridge mode

Use this when `example_input/` and `output/` are currently real local folders and 
you want to move their contents into Google Drive-backed folders.

First run a dry run:

```bash
make dry-sync-local-to-colab-bridge
```

This shows what would be copied to Google Drive without changing anything.

Then switch to bridge mode:

```bash
make switch-to-colab-bridge
```

This does three things:

1. copies the local folder contents to Google Drive
2. renames the original local folders to `.local-backup`
3. creates symlinks from the repo folders to the Google Drive folders

For example:

```text
example_input.local-backup/
output.local-backup/

example_input -> /Users/ivo/Google Drive/My Drive/colab_bridge/kraken-ocr/example_input
output        -> /Users/ivo/Google Drive/My Drive/colab_bridge/kraken-ocr/output
```

After verifying that everything works, the backup folders can be removed manually:

```bash
rm -rf example_input.local-backup output.local-backup
```

## Link existing Google Drive folders

Use this when the Google Drive bridge folders already exist and the local folders are missing or already symlinks:

```bash
make link-colab-bridge
```

This does not copy local data. It only creates symlinks from the repository folders to the Google Drive folders.

If a real local folder already exists, this target refuses to overwrite it. 
Use `make switch-to-colab-bridge` instead if you want to preserve and upload the local contents first.

## Sync local folders to Google Drive

Use this when `example_input/` and `output/` are real local folders and you want to overwrite/update the Google Drive copies:

```bash
make sync-local-to-colab-bridge
```

The sync uses `rsync --delete`, so the Google Drive folder is made to match the local folder. 
Files that exist only on Google Drive will be deleted.
Do not run this while the local folders are symlinks. 
The Makefile refuses to do that to avoid accidentally syncing Google Drive to itself.

This does three things:

1. copies the Google Drive folder contents into a temporary local folder
2. removes the symlink
3. moves the copied folder into place as a real local directory

Before running the actual sync, you can do a dry run to see what would be copied and deleted:

```bash
make dry-sync-local-to-colab-bridge
```

## Restore local folders from Google Drive

Use this when the repo folders are symlinks and you want to return to normal local folders:

```bash
make restore-local-from-colab-bridge
```

After this, `example_input/` and `output/` are normal folders again.