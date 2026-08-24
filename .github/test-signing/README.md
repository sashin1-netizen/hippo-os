# Hippo OS personal-test signing

The keystore in this directory is intentionally a **public, non-production test key** used only for Hippo OS personal/sideload APKs.

Purpose:
- keep the signing identity stable across GitHub Actions runs;
- allow future personal-test APKs to update an installed personal build instead of changing certificate every run;
- make CI assert the expected certificate fingerprint.

It must **never** be used for a Google Play, public production, paid distribution, or security-sensitive release. A production release requires a private keystore stored in repository secrets or another secure signing service.

Stable personal-test certificate SHA-256:
`3F:19:98:3A:E8:A8:6F:7F:7B:20:FA:6B:E1:7B:69:88:28:79:C7:6A:74:7F:5D:77:44:A6:B0:63:71:7F:1D:C2`

Because earlier Hippo OS test APKs were signed with ephemeral GitHub-runner keys, the first install of the stable-signed `0.2.1-personal` build may require uninstalling an older Hippo OS test build once. Builds signed with this stable personal key can then update each other normally while the package ID remains `com.sashin.hippoos`.
