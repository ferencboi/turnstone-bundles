# Custom Wine Build Practices for Gaming Focused Minimal Distributions

> **Document status**: Draft
> **Last updated**: 2025-12-25
> **Author:** GitHub Copilot - GPT-5.2

## Scope and goals

This note focuses on high value practices for producing a custom Wine build intended for gaming, with an emphasis on minimizing installed footprint while preserving compatibility for DirectX 9 to 11 titles when paired with DXVK.

Key design tension:
- Wine is not a modular product in the sense of cleanly separable subsystems. Many DLLs have hidden coupling via COM, registry, RPC, and loader behaviors.
- Size reduction is easiest by removing build time dependencies and post build artifacts, and hardest when deleting builtin DLLs.

This means the safest path is:
1. Reduce compile time dependencies and built modules via configure and distro deps.
2. Strip symbols and remove development outputs.
3. Disable or override components at runtime rather than deleting them, except for large and clearly unused payloads.

Sources are cited inline.

## Build strategy overview

### Prefer a staged size reduction approach

Use this order:
1. Configure time feature reduction: avoids producing large drivers and integrations you do not want in the first place.
2. Install time pruning: omit headers, import libs, man pages, locale data, build tools.
3. Post install stripping: strip PE and ELF artifacts to reduce size.
4. Runtime disablement: registry or override based disabling of helper executables and integrations.
5. Only then consider deleting builtin DLLs, and treat it as a compatibility risk requiring testing.

This aligns with common practices in curated Wine build projects, which emphasize practical flag selection and dependency control for minimal and portable builds, and also mention container style delivery patterns for isolating dependencies. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md) [[2]](https://github.com/Kron4ek/Wine-Builds)

## Configure and dependency practices

### Use configure flags to drop external integrations you do not need

Practical flags frequently used for reducing footprint and dependency surface include disabling OSS, LDAP, and winemenubuilder, and also disabling tests and legacy win16 support. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)

Guideline:
- Disable features that pull large or complex host dependencies (printing, scanning, cameras, packet capture, directory services).
- Keep the minimum display, audio, font, and Vulkan stack you need for games.

If your target environment is Linux with DXVK, Vulkan support is generally a must, and you should ensure you have Vulkan drivers and loader available in the runtime environment. DXVK is typically installed into the prefix with DLL overrides rather than compiled into Wine itself. [[6]](https://linuxconfig.org/improve-your-wine-gaming-on-linux-with-dxvk)

### Be deliberate about WoW64 and 32 bit support

Many games and launchers still require 32 bit components, even on 64 bit systems. Wine supports mixed 32 and 64 bit execution via WoW64. Community discussion and curated builds highlight that a WoW64 capable build is important for compatibility and that there are different approaches, including shared WoW64 and builds that avoid system multilib in certain environments. [[3]](https://forum.winehq.org/viewtopic.php?t=37761) [[4]](https://glfs-book.github.io/glfs/wine/winedeps.html) [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)

Recommendation:
- If you ship a single distribution artifact intended to run a wide range of games, enable WoW64 and include both i386 and x86_64 Windows DLL trees.
- If you only need 32 bit games, consider a pure 32 bit Wine build, but test carefully with DXVK and your runtime constraints.

### Understand and embrace the PE versus Unix split direction

Wine has been moving toward more PE based builtin modules for Windows DLLs, which can improve compatibility with software expecting Windows like loader and module characteristics. [[5]](http://livebg.net/docs/wine/wine-devel/)

Implication for minimal builds:
- Avoid deleting builtin PE DLLs unless you have high confidence they are not transitively required.
- Prefer disabling or overriding instead of deleting, because the loader and COM may load DLLs you did not expect.

## Size reduction practices that preserve compatibility

### Strip symbols, but keep a reproducible unstripped build

After building and installing, stripping binaries can reduce size substantially. This is widely used in gaming focused custom builds. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)

Practice:
- Create two artifacts:
  - release: stripped
  - debug: unstripped or partially stripped, not shipped to users but retained for diagnosing crashes
- Ensure you do not strip in a way that breaks stack unwinding on your platform if you rely on crash reporting.

### Remove development outputs and tools from the runtime bundle

If you ship Wine as a runtime only component, remove:
- headers and import libs
- build tools such as widl, wrc, wmc, winebuild, winegcc wrappers
- test suites
- man pages and docs if space constrained

Curated build projects explicitly note practical ways to minimize by controlling which pieces are built and shipped. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md) [[2]](https://github.com/Kron4ek/Wine-Builds)

### Prefer runtime overrides for DXVK rather than deleting D3D DLLs

DXVK is usually installed into the prefix and enabled via DLL overrides, mapping d3d9 and d3d10 and d3d11 to Vulkan. A typical workflow is to add DXVK to the prefix and set overrides accordingly, rather than removing Wine builtin graphics DLLs. [[6]](https://linuxconfig.org/improve-your-wine-gaming-on-linux-with-dxvk)

Reason:
- Some titles and launchers probe for presence of certain DLLs, and missing modules can cause early failures.
- Keeping builtin stubs while overriding at runtime gives you a fallback.

## Recommended testing and validation practices

### Test the loader and prefix initialization as first class targets

Minimal builds often fail on:
- wineboot and prefix creation
- first run registry population
- missing fonts or broken fontconfig integration
- missing winhttp or schannel causing TLS failures

Run:
- wineboot -u
- a basic GUI app creation
- a TLS fetch via winhttp from within the prefix
- your target game launcher and login sequence

Community guidance around dependencies and WoW64 makes clear that missing base components can cause build or runtime failures, so validate these early. [[4]](https://glfs-book.github.io/glfs/wine/winedeps.html) [[3]](https://forum.winehq.org/viewtopic.php?t=37761)

### Maintain a compatibility matrix per profile

If you will ship multiple variants:
- wine minimal: launchers and simple apps
- wine gaming: DXVK focused with network and audio
- wine gaming full: adds gecko and mono for embedded web and dotnet apps

Record:
- required host libraries
- supported GPU driver families and Vulkan versions
- known incompatible games or launchers

## Security and operational guidance for shipping Wine in an app

- Treat the Wine prefix as untrusted input. Games can execute arbitrary Windows code which maps to host syscalls through Wine.
- Apply least privilege at the process level: sandbox, seccomp, namespaces, filesystem whitelisting, and minimal device access.
- Avoid bundling credentials, and do not log secrets. Use structured logs and redact tokens.
- Keep a fast patch pipeline for Wine and DXVK updates when security fixes land.

These points are not directly from the sources below, but they follow standard Zero Trust and least privilege practice for executing third party code.

## Practical do and do not list

Do:
- Use configure to drop external subsystems you do not need. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)
- Enable WoW64 unless you are certain all targets are single arch. [[3]](https://forum.winehq.org/viewtopic.php?t=37761) [[4]](https://glfs-book.github.io/glfs/wine/winedeps.html)
- Use DXVK via prefix install and overrides. [[6]](https://linuxconfig.org/improve-your-wine-gaming-on-linux-with-dxvk)
- Strip and prune installation outputs, keep an unstripped build for diagnosis. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)
- Prefer disabling helpers like winemenubuilder rather than shipping them. [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)

Do not:
- Aggressively delete builtin DLLs before you have strong evidence they are unused.
- Rely on one game test as proof of correctness. Use at least a small portfolio.

## Sources

1. Kron4ek Wine Builds README: build flags, dependency and portability guidance  
   https://github.com/Kron4ek/Wine-Builds/blob/master/README.md [[1]](https://github.com/Kron4ek/Wine-Builds/blob/master/README.md)

2. Kron4ek Wine Builds repository: curated Wine build distributions and practices  
   https://github.com/Kron4ek/Wine-Builds [[2]](https://github.com/Kron4ek/Wine-Builds)

3. WineHQ Forums thread on shared WoW64: discussion of WoW64 approaches and implications  
   https://forum.winehq.org/viewtopic.php?t=37761 [[3]](https://forum.winehq.org/viewtopic.php?t=37761)

4. Wine dependencies overview: useful for understanding what optional features pull in  
   https://glfs-book.github.io/glfs/wine/winedeps.html [[4]](https://glfs-book.github.io/glfs/wine/winedeps.html)

5. Wine developers guide mirror: background on Wine internals and architecture evolution  
   http://livebg.net/docs/wine/wine-devel/ [[5]](http://livebg.net/docs/wine/wine-devel/)

6. DXVK integration guidance: installing DXVK into a Wine prefix and enabling it  
   https://linuxconfig.org/improve-your-wine-gaming-on-linux-with-dxvk [[6]](https://linuxconfig.org/improve-your-wine-gaming-on-linux-with-dxvk)