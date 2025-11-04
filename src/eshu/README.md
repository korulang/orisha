# Eshu - HTTP Server & Routing

> *Èṣù ni baba ọ̀nà* - Eshu is the father of the crossroads

## Overview

Eshu is the HTTP routing and server component of the Orisha Stack. Named after the Yoruba Orisha of crossroads and paths, Eshu guides HTTP requests to their correct handlers.

## Status

🚧 **In Development**

## Planned Features

### Compile-Time Route Collection
- Routes declared as `comptime|norun` events
- AST walker collects all route definitions
- Generates optimized dispatch table

### Type-Safe Context
- Request/response context with phantom types
- Obligation system ensures responses are always sent
- Compile-time validation of handler chains

### PGO Route Ordering
- Profile-guided optimization of route matching
- Hot paths checked first
- Custom compiler pass reads profiling data

### Request/Response Handling
- Parse HTTP requests
- Route matching and dispatch
- Response building with type safety

## Architecture

```
eshu/
├── server.kz       # HTTP server runtime
├── router.kz       # Route collection and dispatch
├── context.kz      # Request/response context types
└── compiler.kz     # Compile-time route collector pass
```

## Usage

*Coming soon - syntax to be validated*

## Implementation Notes

- Will need to integrate with Zig's HTTP server or Node.js
- Route collection follows same pattern as `package:requires`
- Context obligations prevent forgotten responses
