# Oya - Template Engine

> *Wind of transformation*

## Overview

Oya is the template engine component of the Orisha Stack. Named after the Yoruba Orisha of wind and transformation, Oya transforms data into rendered HTML with blazing speed.

## Status

🚧 **In Development**

## Planned Features

### Source Parameter Templates
- Templates captured in `{ }` blocks as Source parameters
- Compile-time parsing and validation
- Zero-overhead rendering

### Variable Interpolation
- Context binding at compile-time
- Type-safe variable access
- Scope capture (test 059)

### Template Composition
- Reusable template components
- Layout system
- Partial templates

### Compile-Time Validation
- Check all variables exist in context
- Type checking for expressions
- Error reporting at compile-time

## Architecture

```
oya/
├── parser.kz       # Template parsing (compile-time)
├── render.kz       # Runtime rendering
├── context.kz      # Template context types
└── compiler.kz     # Compile-time template processor
```

## Usage

*Coming soon - syntax to be validated*

## Implementation Notes

- Templates are Source parameters (anonymous block content)
- Need scope capture support (test 059)
- Interpolation syntax TBD
- Will integrate with Eshu's response context
