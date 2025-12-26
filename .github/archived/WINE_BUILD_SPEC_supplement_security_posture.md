Your security expectations should match what you are actually shipping: an Android app that downloads and executes a modular native runtime capable of running untrusted third party Windows binaries. That is closer to a local sandboxed runtime and updater than a typical game launcher, so you need a stronger than average consumer security baseline, but not SOC 2.

> **Last updated**: 2025-12-25
> **Author:** GitHub Copilot - GPT-5.2

Below is a practical, Play Store aligned security bar you can adopt as engineering requirements. I will also connect it to your repo architecture (bundle index, per component releases, sha256 verification noted in README).

## 1. Security posture statement (one paragraph you can publish)

Turnstone runs third party Windows software inside an isolated app sandbox. The app follows least privilege on Android, uses verified signed updates for runtime bundles, stores all prefixes and game files in app scoped storage by default, and provides user visible controls for network and filesystem access for each container. The app does not collect sensitive identifiers and does not access contacts, SMS, microphone, camera, location, or accessibility services.

## 2. Threat model (what you are defending against)

Primary threats for your app:
- Untrusted EXE content (malware, trojans in cracked games, infected mods).
- Malicious or compromised bundle distribution (supply chain attack on Wine, DXVK, Turnip, box64 artifacts).
- Abuse as a stealth downloader or bot client (the runtime can access network).
- Data exposure from broad storage mappings (exfiltrate photos, documents, other app files if exposed).
- Privilege escalation attempts via native code vulnerabilities in the runtime stack.

Non goals (state explicitly):
- You cannot guarantee malware containment equivalent to a VM or hardened emulator.
- You do not guarantee the safety of running arbitrary Windows software. Users must trust what they run.

## 3. Minimum viable security requirements (common sense baseline)

### 3.1 Android permissions and platform features
Hard requirements:
- Request no dangerous permissions unless absolutely required for a user facing feature.
- Do not use accessibility service, device admin, VPNService, or overlay permissions.
- Storage access must use scoped storage and Storage Access Framework. No broad external storage access by default.

Rationale: This aligns with least privilege and reduces policy and privacy risk.

### 3.2 Filesystem exposure rules
Default policy:
- Prefixes and runtime data live in app private storage.
- No drive mapping to shared storage by default.

User initiated expansion:
- Only expose user selected directories via SAF. Treat each grant as a capability.
- Provide per container or per game mapping list the user can revoke.

Security expectation:
- The runtime cannot enumerate arbitrary shared storage without explicit user grants.

### 3.3 Network access controls
Because you support multiplayer and Steam like launchers, you need network. But you also need abuse controls.

Baseline:
- Per container toggle: allow network yes or no.
- Optionally per game toggle if you later add a launcher UI.
- Default on is acceptable, but it must be visible and controllable.

Hardening options:
- If you implement a network block, do it at OS level for the runtime process group (not only in Wine config). If you cannot, clearly label it as best effort.

### 3.4 Logging and telemetry
Requirements:
- No secrets in logs (tokens, cookies, auth headers).
- No PII in logs by default (paths that include user identity, game account names).
- Crash and usage telemetry must be opt in, with a clear data inventory.

### 3.5 Updater and bundle integrity (highest priority given your design)
Your README already says:
- each bundle is a GitHub Release
- bundle index is updated
- sha256 verification required for bundles

Turn that into strict security requirements:

1. Trusted origin
- Only download bundles from your allowlisted release hostnames.
- Enforce HTTPS.

2. Cryptographic authenticity, not only sha256
- A sha256 in a manifest protects against corruption, not a malicious mirror or compromised index.
- Require a signature chain you control.
  - Option A: sign bundle manifests with a long term offline key, and ship the public key in the app.
  - Option B: use GitHub release artifact signatures if you can make them verifiable and stable in app.

3. Protect the index
- Treat bundle index as untrusted input.
- Validate schema, lengths, and enforce allowlists for component names and versions.
- Require signature over the index content as well.

4. Rollback and freeze protection
- Prevent downgrade to known vulnerable versions unless user explicitly opts in.
- Keep a local allowlist or minimum version policy for critical components.

### 3.6 Execution boundaries
Minimum expectation:
- Wine runtime should run in a separate process from UI and update logic.
- The runtime process should have minimal privileges and no direct access to update credentials or signing keys.

If you later add an embedded Linux container:
- Never run as root.
- Do not ship setuid binaries.
- Prefer no writable executable mappings in shared locations.

## 4. Abuse and malware considerations (given users can run anything)

You do not need to become an antivirus product, but you should make abuse harder:

- Import gating: require explicit user action to import and run an EXE, do not auto execute from downloads.
- Show warnings for unknown executables.
- Provide a safe mode that disables network and limits file mappings.
- Provide a simple file hash display and optionally reputation lookup if you add it later (opt in).

Also include a policy stance:
- You do not support piracy. You cannot prevent it completely, but your UI and docs should not promote it.

## 5. Secure defaults and settings checklist

Default configuration:
- Network enabled but visible, or disabled by default if you want a stricter stance. Given multiplayer goals, enabled by default is practical.
- No shared storage mapping.
- No background auto updates on metered networks unless user opts in.
- Bundle updates only from verified sources and only after signature verification.

User visible controls:
- Manage container storage mappings
- Manage network toggle
- Clear prefix data
- Show installed bundle versions and their hashes

## 6. What to document for Play Store readiness

Produce these documents internally (and optionally publish summaries):
- Permissions rationale list: why each permission is needed.
- Data safety inventory: what data is collected, stored, and transmitted.
- Third party code inventory: Wine, DXVK, Mesa, box64 versions and licenses.
- Update and integrity design: signature scheme, key rotation, rollback policy.

## 7. Specific to your repo layout and current mechanism

From your README, the distribution mechanism is:
- per component releases
- bundle index
- sha256 verification

Security gap to close:
- Add signature verification for bundle index and per bundle manifest. Sha256 alone is not enough against a compromised distribution path.

If you want, I can propose an ASCII only spec for:
- signed bundle index format
- signed manifest format
- key management and rotation plan
- offline root key, online signing key split
- how to integrate this into your existing scripts update index and create release workflow

Clarifying question that affects the design:
- Will the app ever download executables or code other than these bundles (for example hotfix scripts), or only the tar zst bundles you publish?