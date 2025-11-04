# Orisha - Web Framework for Koru

> *Spiritual power meets type safety*

A web framework for the [Koru programming language](https://github.com/koru-lang/koru), inspired by Yoruba spiritual traditions.

Orisha provides a family of components for building high-performance, type-safe web applications.

---

## 🌍 The Orisha Family

### **Eshu** - HTTP Server & Routing 🛤️

> *Guardian of the crossroads, chooser of paths*

**Status**: 🚧 In Development

**Purpose**: HTTP server, routing, request handling

In Yoruba tradition, Èṣù is the divine messenger who stands at crossroads and guides travelers. Similarly, Eshu guides HTTP requests to their correct destinations.

**Key Features** (Planned):
- Compile-time route collection
- Type-safe request/response handling
- Context obligations (never forget to respond!)
- PGO-optimized route matching
- Hot-path ordering from profiling data

---

### **Oya** - Template Engine 🌬️

> *Wind of transformation*

**Status**: 🚧 In Development

**Purpose**: HTML templating and rendering

Ọya is the Orisha of wind, storms, and transformation. Oya transforms your data into beautiful markup with the speed of wind.

**Key Features** (Planned):
- Compile-time template parsing
- Variable interpolation
- Type-safe context binding
- Source parameter integration
- Template composition

---

### **Oshun** - Database & ORM 🌊

> *River of data*

**Status**: 📋 Planned

**Purpose**: Database queries, connection pooling, ORM

Ọṣun is the Orisha of rivers, flowing waters, and sweetness. Oshun provides elegant, flowing data access.

**Key Features** (Aspirational):
- Type-safe query building
- Connection pooling
- Migration support
- Transaction handling
- Multiple database backends

---

### **Shango** - Authentication & Authorization ⚡

> *Thunder guards the gates*

**Status**: 📋 Planned

**Purpose**: Authentication, authorization, security

Ṣàngó is the Orisha of thunder, lightning, and justice. Shango brings the power of authority and security to your applications.

**Key Features** (Aspirational):
- JWT authentication
- Role-based access control
- Permission checking
- Session management
- OAuth integration

---

### **Ogun** - Build Tools 🔨

> *Master of tools and pathways*

**Status**: 📋 Planned

**Purpose**: Build system, bundling, optimization

Ògún is the Orisha of iron, technology, and tools. Ogun forges your application with precision and power.

**Key Features** (Aspirational):
- Asset bundling
- Code splitting
- Minification
- Source maps
- Hot module replacement

---

### **Yemoja** - State Management 🌊

> *Mother of waters, container of state*

**Status**: 📋 Planned

**Purpose**: Application state, session management

Yemọja is the mother of all Orishas, the ocean that contains all. Yemoja nurtures and contains your application state.

**Key Features** (Aspirational):
- Reactive state stores
- Session management
- State persistence
- Time-travel debugging
- Event sourcing

---

## 🎯 Project Structure

```
orisha/
├── eshu/           # HTTP server & routing
├── oya/            # Template engine
├── oshun/          # Database & ORM (planned)
├── shango/         # Auth & security (planned)
├── ogun/           # Build tools (planned)
├── yemoja/         # State management (planned)
├── examples/       # Example applications
│   └── hello/      # Simple hello world
├── koru.zon        # Project configuration
└── README.md       # This file
```

## 📦 Import Structure

```koru
~import "$orisha/eshu"     // HTTP routing
~import "$orisha/oya"      // Templates
~import "$orisha/oshun"    // Database (future)
~import "$orisha/shango"   // Auth (future)
```

---

## 🚀 Getting Started

### Prerequisites

- [Koru compiler](https://github.com/koru-lang/koru) installed
- Node.js 20+ (for npm dependencies)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/koru-lang/orisha
cd orisha

# Run the hello world example
cd examples/hello
koruc main.kz
./main
```

Visit `http://localhost:3000` to see your first Orisha application!

---

## 📖 Philosophy

### Bounded Contexts

Each Orisha component represents a **bounded context** - a clear boundary with explicit interfaces. This makes code easier to understand, test, and reason about.

### Type Safety

Leveraging Koru's phantom types and obligation system, Orisha components enforce safety at compile-time:

- Never forget to respond to an HTTP request
- Always clean up database connections
- Validate template context types
- Track authorization requirements

### Performance

Koru's metacircular compiler enables unique optimizations:

- **PGO Route Ordering**: Profile-guided optimization of route matching
- **Compile-Time Templates**: Zero-overhead template rendering
- **Dead Code Elimination**: Remove unused routes and handlers
- **Inline Hot Paths**: Aggressive inlining of frequently-called code

### AI-First

Clear boundaries and explicit types make Orisha components perfect for AI-assisted development:

- Events define clear units of work
- Continuations make control flow explicit
- Obligations prevent common mistakes
- Bounded contexts limit reasoning scope

---

## 🌍 Cultural Respect

Orisha is named after deities from the Yoruba religion, a spiritual tradition originating from the Yoruba people of West Africa (primarily Nigeria, Benin, and Togo). The Yoruba religion has profoundly influenced Afro-Caribbean traditions including Santería (Cuba), Candomblé (Brazil), and Vodou (Haiti).

**We honor these traditions by:**

1. **Accurate Representation**: Each component's name reflects its actual role in Yoruba tradition
2. **Educational Content**: Sharing the meanings and stories behind each Orisha
3. **Respectful Usage**: Treating these names with reverence, not as mere branding
4. **Community Support**: A portion of any future commercial support fees will be donated to Yoruba cultural preservation organizations

**Learn More:**
- [Yoruba Religion](https://en.wikipedia.org/wiki/Yoruba_religion)
- [Orishas](https://en.wikipedia.org/wiki/Orisha)
- [Yoruba Cultural Heritage](https://ich.unesco.org/en/RL/ifa-divination-system-00146)

---

## 📊 Status Legend

- 🚧 **In Development**: Actively being built
- 📋 **Planned**: Designed but not yet implemented
- ✅ **Stable**: Production-ready
- 🧪 **Experimental**: Available but API may change

---

## 🤝 Contributing

We welcome contributions! Whether it's:

- Implementing planned components
- Adding examples and documentation
- Reporting bugs or suggesting features
- Improving performance or adding tests

Please read our [CONTRIBUTING.md](./CONTRIBUTING.md) (coming soon) for guidelines.

---

## 📜 License

MIT License - See [LICENSE](./LICENSE) for details

---

## 🙏 Acknowledgments

- The **Yoruba people** for their rich spiritual traditions
- The **Koru community** for building an incredible language
- All contributors who help build Orisha

---

**Built with ❤️ and respect**

*Àṣẹ - May it manifest*
