// Orisha's router — the contract.
//
// Standalone module for testing and benchmarking routing logic without network
// overhead. No host language here, so no `~` anywhere in the file.
//
// Usage:
//   ~test(Route matching) {
//       ~router.match = ok { path: "/users/42", pattern: "/users/:id" }
//       ~router.match(path: "/users/42", pattern: "/users/:id")
//       | ok m |> assert.ok()
//   }

import std/testing

// ============================================================================
// PATTERN MATCHING
// ============================================================================
// Match a path against a pattern like "/users/:id/posts/:post_id"; `ok` carries
// the extracted parameters. `RouteMatch` is a host type the companion declares.

pub tor match { path: string, pattern: string }
| ok RouteMatch
| no-match
