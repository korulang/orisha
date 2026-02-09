- NEVER SUGGEST NOT FIXING THINGS PROPERLY, THE TOOLCHAIN IS THE ONLY THING OF VALUE.

## 🧬 Project Consciousness
Optimize Orisha webserver performance to exceed industry-standard frameworks (Actix, .NET, Go) using aggressive compile-time specialization and log-guided routing.

### Decisions
- **Replaced the synchronous server loop with a high-performance kqueue-based worker pool in lib/index.kz.**: To achieve performance parity with high-performance frameworks like Actix and .NET while maintaining the Koru DSL DX.
- **Modified the router transform to emit direct inline statement blocks (if/return chains) instead of a RouteResult union and switch.**: To eliminate the overhead of union tagging and switching, allowing the router to compile down to straight-line Zig control flow.
- **Modified the Koru compiler (visitor_emitter.zig) to support a '//@koru:inline_stmt' marker for raw statement emission.**: To allow transforms to inject multi-statement blocks (like if/return chains) into the generated Zig without the emitter forcing invalid trailing semicolons.
- **Adopted a 'compile-time/upstream' approach to JSON formatting using thread-local buffers and precomputed header prefixes.**: To ensure 'honest' performance comparisons with other frameworks by matching payload size and Content-Type while leveraging Zig's efficiency.
- **Implemented an experiment for log-guided route reordering based on nginx access logs.**: To test the impact of PGO-style optimizations where the most frequent routes are checked first in the generated if-chain.
- **Precompute and cache response headers as static byte slices.**: Microbenchmarks revealed that string formatting and header construction during the request lifecycle were significant bottlenecks. Precomputing them moves the cost to startup/compile-time.
- **Introduce granular microbenchmarks for request parsing, router dispatch, and response building.**: To isolate performance gains at the function level, ensuring that DSL changes don't introduce regressions that are masked by network jitter in macro-benchmarks.
- **Standardize benchmark responses to use Content-Type: application/json and real JSON payloads for dynamic routes.**: To ensure 'apples-to-apples' comparisons with TechEmpower-style frameworks which typically serve JSON, and to measure the impact of SIMD-json integration.
- **Established /usr/local/lib/koru as the global system path for Koru compiler sources and standard library.**: Allows the compiler to behave as a standard system tool and fixes fragility of 'koruc run' outside the repo root.
- **Remove `const` and `var` from `std.types` and focus it strictly on type declarations (struct, enum, union).**: Value declarations are handled by raw Zig or `~const` in `control.kz`. Keeping `types.kz` focused on structural definitions is semantically cleaner.
- **Standardize on Liquid-style `{{ var }}` and `{% if %}` syntax across the entire language, deprecating `${var}`.**: To avoid developer confusion and provide a unified, powerful metaprogramming interface.
- **Orthogonal Type System Architecture (Shape vs. Phantom)**: Separates structural validation (field names/types) from semantic lifecycle tracking (phantom states).

### Instructions & Usage
### 🧠 Semantic Memory & Search
This project uses `prose` to maintain a cross-session semantic memory of decisions, insights, and story beats.

- **Semantic Search**: If you're unsure about a past decision or need context on a feature, run:
  ```bash
  prose search "your question or keywords"
  ```
- **Project Status**: To see a summary of recent sessions and evolved memory, run:
  ```bash
  prose status
  ```
- **View Chronicles**: Run `prose serve` to browse the interactive development timeline in your browser.


### Active Gotchas
- **Misleading server lifecycle events (e.g., a 'listening' branch that is never reached due to the infinite accept loop).**: Refactor event branches to 'shutdown' and 'failed' to reflect honest execution semantics.
- **Runtime compression (Gzip) significantly degrades performance (up to 45% in some frameworks).**: Prioritize compile-time pre-compression or static file serving with pre-compressed assets (gzip_static) to maintain high throughput.
- **Duplicate module definitions in generated Zig code when multiple Koru files require the same dependency.**: Implement string-based deduplication in the CompilerRequiresCollector using a StringHashMap.
- **Zig keyword escaping collisions (e.g., @\"@\"error\"\\\") in the backend emitter.**: Refine escaping logic in the Zig emitter and update runtime.kz error names to avoid reserved keywords.
- **The router transformation previously generated separate events, causing scope issues for local variables.**: Use inline body codegen (Zig 'blk: {}' expressions) or the '//@koru:inline_stmt' marker so runtime values from the call-site scope are directly accessible.
- **Importing modules containing ~test blocks can break the build of the importing module due to missing event definitions.**: Ensure the compiler properly handles or strips test-related events when a module is imported as a dependency.


> [!NOTE]
> This file is automatically generated from `CLAUDE.md.template` by `prose`.
> Last updated: 2/9/2026, 2:57:16 PM
