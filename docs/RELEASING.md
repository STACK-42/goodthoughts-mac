# Releasing goodthoughts for Mac

Releases are Developer ID builds outside the Mac App Store: signed, notarised by Apple, stapled, packed in a `.dmg` and attached to a GitHub Release. [`.github/workflows/release.yml`](../.github/workflows/release.yml) does all of it on a macOS runner, so no one needs Xcode locally. It does nothing until the secrets below exist.

## One-time setup

You need these from your Apple Developer account. None of them can be made for you.

1. **Apple Developer Program membership** (paid, yearly), for the account or organisation that will publish the app. Note the **Team ID**: developer.apple.com → Account → Membership details, ten characters like `AB12CD34EF`.

2. **A Developer ID Application certificate.** It signs apps distributed outside the App Store. Only the Account Holder can create one.
   - On a Mac, open Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority. Enter your email, choose "Saved to disk", and save the `.certSigningRequest`.
   - developer.apple.com → Certificates → **+** → *Developer ID Application* (choose the G2 Sub-CA if asked) → upload the request → download the `.cer` and double-click it to add it to your login keychain.
   - In Keychain Access, under My Certificates, select "Developer ID Application: …" with its private key → File → Export Items… → save as `.p12` with a strong password.

3. **An App Store Connect API key for notarisation.** appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API → Team Keys → **+**, role *Developer*. Note the **Key ID** and the **Issuer ID** at the top, and download the `.p8`. You can only download it once.

4. **GitHub secrets.** In STACK-42/goodthoughts-mac → Settings → Secrets and variables → Actions, add:

   | Secret | Value |
   | --- | --- |
   | `APPLE_TEAM_ID` | The Team ID from step 1 |
   | `DEVELOPER_ID_CERT_P12_BASE64` | `base64 -i DeveloperID.p12 \| pbcopy`, then paste |
   | `DEVELOPER_ID_CERT_PASSWORD` | The `.p12` password from step 2 |
   | `NOTARY_KEY_ID` | The API key's Key ID |
   | `NOTARY_ISSUER_ID` | The Issuer ID |
   | `NOTARY_KEY_P8_BASE64` | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy`, then paste |

   Delete the local `.p12` and `.p8` copies once they're stored somewhere safe, such as a password manager.

5. **Confirm the bundle id**, `page.goodthoughts.mac` in `project.yml`, before the first public release. Changing it later loses users' settings and their login item. Developer ID distribution doesn't need the id registered on the developer site.

> [!IMPORTANT]
> The certificate and the API key give whoever holds them the power to ship software under your name. Keep them only in GitHub secrets and your password manager.

## Making a release

1. Make sure `main` is green.
2. Tag and push: `git tag v0.1.0 && git push origin v0.1.0`. The tag sets the version (`MARKETING_VERSION`), and the build number is the workflow run number.
3. Watch the Release workflow. It imports the certificate into a throwaway keychain, archives the Release configuration, exports with `scripts/release/ExportOptions.plist`, notarises and staples the app, builds the `.dmg` with `scripts/make-dmg.sh`, then signs, notarises and staples that too, and publishes a release with the `.dmg` and its SHA-256.

To try the pipeline without publishing, run the workflow by hand (Actions → Release → Run workflow) with a version. That makes a draft release you can delete.

> [!NOTE]
> Notarisation usually takes a few minutes but can take longer. The workflow waits up to 30 minutes for each submission.

## What's not set up yet

- **Automatic updates.** Users have to download new versions themselves. [Sparkle](https://sparkle-project.org) is the usual answer, but it's a dependency and needs its own signing key and an appcast feed, so it's a separate decision.
- **The live feed.** Until `https://goodthoughts.page/wallpapers.json` exists, a Release build (which has no sample feed) shows "The quote feed returned an error (404)". Publish the feed before the first public release.
