// korulang.org, inside a unikernel. No operating system underneath.
//
// The same two declarations the hosted build uses — the whole website is
// embedded at compile time and the handler is the static router. What changes
// is one build flag, which selects a different `~proc run|…` inside orisha/pump
// and nothing else.
//
//   cd ~/src/korulang_org && STATIC_BUILD=1 pnpm build:local
//   koruc main.kz --build=unikraft
//   zig build-lib wrapper.zig -target x86_64-freestanding \
//       -O ReleaseSmall -fno-stack-protector -femit-bin=libkoruapp.a
//   UK_CFLAGS="-std=gnu17" kraft build --arch x86_64 --plat qemu --no-prompt

import orisha

orisha:static(name: "site", root: "../../../korulang_org/build", fallback: "200.html")

orisha:handler = orisha:static-router(name: "site")

orisha:serve(port: 8080)
| shutdown _ |> _
| failed _ |> _
