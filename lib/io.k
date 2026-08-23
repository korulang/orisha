// Orisha's io — the contract.
//
// What io is: the seam between a running server and the machine's filesystem —
// the read half of "all-purpose". The baked path (`orisha:static`) embeds every
// byte at compile time and remains the right default for content known before
// the binary is built; nothing here competes with it. This module exists for
// the answers that CANNOT be known then: a file uploaded since the last
// deploy, a payload too large to embed, data the operator drops beside the
// binary while it runs.
//
// Every declaration is here; the platform bodies are in the companion `io.kz`.
// This file has no host language in it, so it has no `~` in it either.
//
// The three answers of `load` are three different facts, and collapsing any
// two of them is how serving bugs hide:
//
//   ready    the bytes are yours until you `release` them
//   gone     no such path — the caller may legitimately want this (404)
//   refused  the path exists and reading it would be wrong or impossible
//            (a directory, permissions, anything else the OS declined)
//
// A missing file and an unreadable file produce different responses in every
// honest server. The old std/net surface could not say them apart because it
// reported success for everything; these branches are the correction.
//
// Ownership: `ready` hands back memory the caller now owns, however large the
// file was. There is no size ceiling here — that is the point — so there is no
// borrowing either. Hand the slice to `release` when the response has been
// handed to the pump; the companion frees exactly what `load` allocated.

pub tor load { path: string }
| ready string
| gone
| refused

// Return what `load` handed over. Passing a slice that did not come from
// `load` is a programming error, same as freeing twice.
pub tor release { data: string }
