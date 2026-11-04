# Releasing goodthoughts for Mac

A release is a `.dmg` on GitHub Releases plus a Sparkle appcast, so copies people have already installed update themselves. [`.github/workflows/release.yml`](../.github/workflows/release.yml) does everything on a macOS runner, so nobody needs Xcode.

There's no Apple Developer account involved. The app is ad-hoc signed and not notarised, so macOS asks each person to approve it once on first launch (the README explains how). Updates are checked with Sparkle's own EdDSA signature instead.

## Making a release

1. Make sure `main` is green.
2. Tag and push:

   ```sh
   git tag v0.2.0
   git push origin v0.2.0
   ```

   The tag sets both `CFBundleShortVersionString` and `CFBundleVersion`. Sparkle compares versions, so each tag must be higher than the last.
3. The Release workflow archives the Release configuration, packs `goodthoughts-<version>.dmg` with `scripts/make-dmg.sh`, signs it with the Sparkle key, writes `appcast.xml` with `scripts/release/make-appcast.sh`, and publishes a GitHub Release with the `.dmg`, its SHA-256 and the appcast.

Installed copies check `https://github.com/STACK-42/goodthoughts-mac/releases/latest/download/appcast.xml` once a day and offer the new version. People can also click **Updates** in the popover.

To try the pipeline without publishing, run the workflow by hand (Actions → Release → Run workflow) with a version. It makes a draft release, which `releases/latest` ignores, so nobody is offered it. Delete the draft afterwards.

> [!WARNING]
> Don't delete or replace a published release's `.dmg`. Installed copies may be partway through downloading it, and the appcast's signature only matches the original file.

## The update key

Sparkle refuses any update whose `.dmg` isn't signed by the private key matching `SUPublicEDKey` in `project.yml`.

- The private key is in the GitHub secret `SPARKLE_ED_PRIVATE_KEY`, and in the login keychain of the Mac it was made on, under the account `goodthoughts-mac`.
- To sign by hand on that Mac (with Sparkle's tools from its release download): `sign_update --account goodthoughts-mac file.dmg`.

> [!CAUTION]
> Back up the private key (`generate_keys --account goodthoughts-mac -x key.txt`, then into a password manager, then delete `key.txt`). If it's lost, installed copies can't be updated: everyone would have to download a new build with a new key by hand. If it leaks, someone could push a fake update to everyone who can be tricked into fetching their appcast, so replace it at once.

## Updating Sparkle

Change the version in two places together: `packages.Sparkle.exactVersion` in `project.yml`, and `SPARKLE_VERSION` plus `SPARKLE_SHA256` (the checksum of `Sparkle-<version>.tar.xz`) in the release workflow.

## If you ever do get a Developer ID

Signing with a Developer ID and notarising removes the first-launch approval. It would mean importing the certificate in the workflow, archiving with `CODE_SIGN_IDENTITY="Developer ID Application"`, turning the hardened runtime back on, and running `notarytool` and `stapler` on the app and the `.dmg`. Sparkle keeps working, because the EdDSA key doesn't change.
