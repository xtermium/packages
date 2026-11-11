# Publishing xtermium to package managers

Two repositories hold all of this:

- `homebrew-tap/` becomes **xtermium/homebrew-tap** (Homebrew finds `brew tap xtermium/tap` only under that name).
- Everything else here (`aur/`, `choco/`, `winget/`, `.github/workflows/`, this file) becomes **xtermium/packages**. Its three workflows poll GitHub every hour, as the Scoop bucket's Excavator does, so the app repository needs no change and holds none of these tokens.

Every workflow takes the new version from the GitHub API (`releases/latest`, or the `nightly` release's name: `xtermium nightly 2026-11-10 03:53:28 UTC` becomes `20261110.035328`, as in Scoop) and the sha256 from the digest GitHub records for each uploaded file, so nothing is downloaded to bump.

| Manager | Stable | Nightly | How it stays current | Verified how |
|---|---|---|---|---|
| Homebrew (macOS) | `xtermium` cask, universal .dmg | `xtermium@nightly` cask, rolling .dmg, stamped version + real sha256 | homebrew-tap `bump.yml`, hourly, commits with `GITHUB_TOKEN` | `ruby -c`, `brew style` (no offenses), `brew livecheck` (both current); `brew audit` on Linux checks no cask rules, so not really audited; never installed on a Mac |
| AUR (Arch) | `xtermium-bin`, repackaged .deb | `xtermium-nightly-bin`, same, stamped version + real sha256 | packages `aur.yml`, hourly: bumps, commits, pushes to the AUR over SSH | built with `makepkg -s`, installed with `pacman -U`, `namcap`, `xtermium help` in `archlinux:latest`; conflict both ways checked |
| winget (Windows) | `Xtermium.Xtermium`, MSI, machine scope | none (see below) | packages `winget.yml`, hourly: wingetcreate opens a pull request to microsoft/winget-pkgs per release | `winget validate` succeeded; not installed |
| Chocolatey (Windows) | `xtermium`, downloads the MSI with its checksum | none (see below) | packages `choco.yml`, hourly: packs and pushes each release | `choco pack` in `chocolatey/choco`; not installed |
| Scoop (exists) | `xtermium` | `xtermium-nightly` | Excavator, hourly | in use |

## Homebrew: once

1. Create the public repository **xtermium/homebrew-tap**; push `homebrew-tap/` as its root.
2. Settings › Actions › General › Workflow permissions: **Read and write**. No secrets: `bump.yml` uses `GITHUB_TOKEN`.
3. Try it on a Mac: `brew tap xtermium/tap && brew install --cask xtermium`, then `brew audit --cask --strict --online xtermium/tap/xtermium xtermium/tap/xtermium@nightly` (the audit only works on macOS).

Then: a release or nightly build reaches the casks within the hour. Until the .dmg is signed with a Developer ID and notarized, users clear the quarantine flag after each install (the tap README says how); Homebrew 5 removed `--no-quarantine`. Submitting to homebrew/cask itself instead of a tap needs a signed app (it disables casks that fail Gatekeeper since September 2026) and some popularity; not needed for the tap.

## AUR: once

1. Create an AUR account (aur.archlinux.org › Register) for the project, e.g. `xtermium`, with a project address.
2. Make a key pair just for this: `ssh-keygen -t ed25519 -N '' -C xtermium-aur -f aur_key`. Paste `aur_key.pub` into the AUR account (My Account › SSH Public Key).
3. Create the public repository **xtermium/packages**; push this folder (without `homebrew-tap/`). Settings › Actions › General › Workflow permissions: **Read and write**.
4. Secret **`AUR_SSH_PRIVATE_KEY`** in xtermium/packages: the contents of `aur_key`. Then delete the local copy.
5. Actions › aur › Run workflow. The first run creates both AUR packages (pushing to a new name creates it) and logs `pushed xtermium-bin`, `pushed xtermium-nightly-bin`.

Then: hourly, `aur/bump.sh` sets `pkgver` and `sha256sums`, regenerates `.SRCINFO`, commits here, and pushes to the AUR whatever differs from it. `yay -S xtermium-bin` or `yay -S xtermium-nightly-bin`; the two replace each other (`provides`/`conflicts` = `xtermium`). The `Maintainer:` line says `xtermium <support@xtermium.com>`.

Plain `git` over SSH is used instead of an action such as KSXGitHub/github-actions-deploy-aur: it is a dozen lines, needs no third-party code with the key, and the AUR host key is pinned in the workflow (checked against the fingerprint on aur.archlinux.org).

## winget: once

1. The first version goes in by hand, from a fork of microsoft/winget-pkgs: copy `winget/manifests/x/Xtermium/Xtermium/0.9.0/` to the same path in the fork, then open a pull request titled `New package: Xtermium.Xtermium version 0.9.0` (and sign Microsoft's CLA when the bot asks). Or `wingetcreate submit winget/manifests/x/Xtermium/Xtermium/0.9.0 --token <token>`.
2. Expect a moderator question: the installers are not Authenticode-signed, and new packages from an unsigned publisher get a manual look (SmartScreen/Defender scans run on every PR).
3. A classic personal access token with the **public_repo** scope (fine-grained tokens don't work with wingetcreate) from the GitHub account that should own the fork and the pull requests. Secret **`WINGET_TOKEN`** in xtermium/packages.

Then: within the hour of each release, `winget.yml` checks that winget-pkgs has neither the version nor an open pull request for it, and runs `wingetcreate update` (pinned v1.12.13.0), which reads the new MSI (hash, ProductCode) and opens the pull request. Microsoft's moderators merge it, usually within a day or two.

Why MSI and not the setup .exe: the MSI installs for all users, has a fixed UpgradeCode (`{80E46DA4-1156-5387-8E28-C10888864271}`) that ties every version together in winget's upgrade matching, and is what Scoop and Chocolatey use, so all three install the same files. The ProductCode changes with every build, so the manifest lists it only per installer, where wingetcreate refreshes it.

### Nightly on winget: not offered

winget-pkgs policy asks for "unique URLs per version of a package to avoid the hash-mismatch errors" (doc/Policies.md, "Manifest URLs"); the nightly's URL is the same every night and its file changes, so any nightly manifest is wrong from the next build until a new pull request merges. Neovim does ship `Neovim.Neovim.Nightly` that way, and the winget bot rewrites its hash every few days; between rewrites it fails to install. With a version per build there would be a pull request a night, each needing moderation, and every earlier one left pointing at a file that no longer matches. The nightly MSI also says 0.9.0 and shares the release's UpgradeCode, so winget would see the release and the nightly as the same installed app. A private winget REST source would work but is far more than a nightly needs. Windows users who want nightly builds use Scoop's `xtermium-nightly`.

## Chocolatey: once

1. Create an account on community.chocolatey.org (for the project), copy its API key (Account › API Keys). Secret **`CHOCO_API_KEY`** in xtermium/packages.
2. Actions › choco › Run workflow pushes nothing while the package is at the latest release. For the first submission push 0.9.0 by hand from Windows: `cd choco\xtermium; choco pack; choco push xtermium.0.9.0.nupkg --source https://push.chocolatey.org/ --api-key <key>`, or set the nuspec version back to 0.8.0 and let the workflow push 0.9.0.
3. Answer the moderators on the package page. Every version of a new package is reviewed by a person (automated validation and a test install run first); expect questions about the unsigned MSI.

Then: within the hour of each release, `choco.yml` points the package at the new MSI with GitHub's digest, packs, pushes, and commits the change. A failed push commits nothing and is retried next hour. The package has no uninstall script: Chocolatey's automatic uninstaller removes the MSI by its Programs and Features entry.

### Nightly on Chocolatey: not offered

Chocolatey wants a pre-release as a version of the same package, not a package of its own: `xtermium-nightly` breaks rule CPMR0024 ("Prerelease information shouldn't be included as part of Package Id"), and the package guide says the beta and the release "have the SAME package id, just different versions". So a nightly would be `xtermium 0.9.1-nightly202611100353`, installed with `--pre`. But every version of a community package is moderated by a person unless the package is trusted, the test install happens after the push, and the nightly's file changes at the same URL each night, so its checksum is often wrong before a moderator gets to it; embedding the MSI instead means a 21 MB binary through moderation each night. Revisit once the package has trusted status (vendor packages with a clean history can get it, and then skip human review): then a weekly pre-release with the MSI embedded would be reasonable. Until then, Scoop's `xtermium-nightly`.

## Sources

- winget-pkgs policy on vanity URLs: https://github.com/microsoft/winget-pkgs/blob/master/doc/Policies.md
- winget hash mismatch guide: https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md
- Neovim's rolling nightly in winget-pkgs: https://github.com/microsoft/winget-pkgs/tree/master/manifests/n/Neovim/Neovim/Nightly
- wingetcreate token: https://github.com/microsoft/winget-create/blob/main/doc/token.md
- Chocolatey CPMR0024: https://docs.chocolatey.org/en-us/community-repository/moderation/package-validator/rules/cpmr0024/
- Chocolatey pre-releases share the id: https://docs.chocolatey.org/en-us/create/create-packages/
- Chocolatey moderation: https://docs.chocolatey.org/en-us/community-repository/moderation/
- Homebrew 5.0.0 (Gatekeeper, `--no-quarantine`): https://brew.sh/2025/11/12/homebrew-5.0.0/
- AUR host key fingerprints: https://aur.archlinux.org
