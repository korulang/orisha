# Orisha - Architecture Notes

## Import Resolution

Based on Koru's module resolver, `~import "$orisha/eshu"` will:

1. Resolve `$orisha` alias to `.` (project root, from `koru.zon`)
2. Then resolve `eshu` component within that path
3. Look for **both**:
   - `eshu.kz` file (main module)
   - `eshu/` directory (submodules)
4. If `.kz` extension is omitted, it's automatically added

### Import Patterns

```koru
// Import components from Orisha framework
~import "$orisha/eshu"           // HTTP routing
~import "$orisha/oya"            // Templates
~import "$orisha/oshun"          // Database (future)

// Import specific files from components
~import "$orisha/eshu/router"    // → looks for eshu/router.kz
~import "$orisha/oya/parser"     // → looks for oya/parser.kz
```

### Component Structure Options

**Option 1**: Main file + directory
```
eshu.kz          # Main exports (re-exports from eshu/*)
eshu/
  router.kz      # Route collection
  server.kz      # HTTP server
  context.kz     # Request/response types
```

**Option 2**: Directory only
```
eshu/
  eshu.kz        # Main module (or any name)
  router.kz
  server.kz
  context.kz
```

We'll likely use **Option 1** for clean top-level imports.

## Compile-Time Architecture

### Route Collection (Eshu)

Following the `package:requires` pattern:

1. **Route Definition**: Events marked `~[comptime|norun]`
2. **AST Walking**: Custom compiler pass collects routes
3. **Code Generation**: Generates dispatch table
4. **PGO Integration**: Orders routes by hotpath frequency

### Template Processing (Oya)

Following the Source parameter pattern:

1. **Template Capture**: HTML in `{ }` blocks as Source parameters
2. **Compile-Time Parsing**: Validate syntax, extract interpolations
3. **Code Generation**: Generate rendering functions
4. **Type Checking**: Validate context types

## Runtime Architecture

### Request Flow

```
HTTP Request
  → Eshu Router (dispatches to handler)
    → Handler Event (user code)
      → Oya Template (if rendering HTML)
        → HTTP Response
```

### Obligation Tracking

Using Koru's phantom type system:

```
http_context<needs_response>  // Created on request
  ↓
handler logic
  ↓
http.respond()               // Fulfills obligation
  ↓
http_context<responded>      // Obligation cleared
```

Compiler error if any path doesn't fulfill the response obligation!

## Performance Strategy

### Compile-Time Optimization

- Route dispatch table pre-computed
- Templates pre-parsed
- Hot paths inlined
- Dead code elimination

### Profile-Guided Optimization (PGO)

1. Run with `--pgo-instrument`
2. Generate profiling data (`profile.json`)
3. Custom pass reads profile data
4. Reorder route checks (hot paths first)
5. Recompile with `--pgo-use`

### Zero-Cost Abstractions

- Events compile to direct calls
- Phantom types erased at compile-time
- Continuations become jumps/returns
- No runtime overhead for type safety

## Development Phases

### Phase 1: Foundation (Current)
- ✅ Project structure
- ✅ Documentation
- ✅ koru.zon configuration
- 🚧 Basic route definition syntax
- 🚧 Simple HTTP server

### Phase 2: Core Features
- Route collector pass
- Request/response handling
- Basic template rendering
- Context obligations

### Phase 3: Optimization
- PGO route ordering
- Template compilation
- Performance benchmarks

### Phase 4: Production Ready
- Error handling
- Logging and monitoring
- Production examples
- Performance tuning

## Design Principles

1. **Bounded Contexts**: Each Orisha component is isolated
2. **Compile-Time Safety**: Catch errors before runtime
3. **Zero-Cost Abstractions**: Type safety without overhead
4. **Explicit Flow**: Continuations make control flow visible
5. **AI-Friendly**: Clear boundaries for AI assistance

## Integration with Koru

### Standard Library

Uses Koru's standard library:
- `std.package:requires` for npm dependencies
- `std.build:requires` for native libs
- Future: `std.http`, `std.template`, etc.

### Compiler Integration

Custom compiler passes:
- Route collector (AST walking)
- Template processor (Source parsing)
- PGO optimizer (profile analysis)

### Event System

Built on Koru's event-continuation model:
- Routes are events
- Handlers are procs
- Responses are continuations
- Obligations tracked via phantom types

---

*This is a living document - will be updated as we implement features*
