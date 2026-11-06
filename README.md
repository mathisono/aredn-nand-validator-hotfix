# AREDN MikroTik NAND validator hotfix APK

**Unofficial community package**, not an AREDN firmware image or an official
AREDN package. Review the source and checksum before using it on a remote node.

One-time package for the firmware-upload validation failure on MikroTik BaseBox 5
(RB912UAG-5HPnD), RB911G-5HPnD, and QRT 5 (RB911G-5HPnD-QRT). The correction
itself is already merged into AREDN in [PR #2979](https://github.com/aredn/aredn/pull/2979),
but affected *running* firmware needs its validator corrected before it can
accept a fixed firmware image.

## Install and upgrade

1. Save the node configuration backup before the upgrade.
2. Download `aredn-nand-validator-hotfix-1.0.0-r0.apk` from this repository's
   [release](https://github.com/mathisono/aredn-nand-validator-hotfix/releases/tag/v1.0.0).
3. On the affected node, open **Setup → Administration → Packages** and use
   **Upload Package** to install the downloaded APK. It changes the running
   validator immediately; no reboot is needed.
4. If the GUI says **Package installed**, retry the correct official
   **sysupgrade** firmware image through the normal firmware web UI. Do not use
   `sysupgrade -F` for this fix. If the normal upload still fails, investigate
   that separate failure rather than forcing the image.
5. After the firmware upgrade, remove the hotfix package from Packages if it
   remains installed. Removing it does **not** undo a running validator change;
   the firmware upgrade replaces that file. On an already-fixed script, the
   install hook is a no-op.

If installation fails with an unsupported-board or unrecognized-script message,
**nothing is patched**. The package only accepts the three exact board IDs and
two known affected `platform.sh` checksums. It never flashes firmware, reboots,
or disables firmware signature/device checks.

## Package source

- `patch-aredn-nand-validator.sh`: the [previously published hotfix](https://github.com/aredn/aredn/pull/2978#issuecomment-6513852218), unchanged.
- `post-install`: runs that script during GUI package installation.
- `build.sh`: builds the APK using `apk-tools` 3.x `mkpkg`, the same packaging
  format used by current AREDN firmware. The package is unsigned; the AREDN
  **Upload Package** flow explicitly allows locally uploaded packages.
- The package owns only its patch script and package manifest. It does **not**
  own `/lib/upgrade/platform.sh`, so removing the package cannot accidentally
  delete the node's firmware validator.

Build with:

```sh
APK_TOOL=/path/to/apk-tools-3.x/bin/apk ./build.sh
```

The build requires `fakeroot` and uses a fixed source-date epoch so repeated
builds with the same apk-tools version produce the same APK bytes. To test the
patcher against archived affected platform scripts without touching a node:

```sh
python3 tests/test_hotfix.py /path/to/affected/platform.sh /path/to/one-line-workaround.sh
```

The published release includes a SHA-256 checksum for the APK. The package is
intentionally narrow: future/unrecognized firmware validators are left
untouched. Ten isolated BusyBox cases pass against archived affected and
one-line-workaround scripts; package integrity, GUI extraction, and isolated
APK add/remove were also checked. Those install/remove tests deliberately
disabled the lifecycle hook: the hook and patcher were inspected and tested
separately. No live node was modified to test this APK; QRT 5 installation
has not been tested on physical hardware.
