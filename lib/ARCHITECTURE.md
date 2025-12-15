# App Architecture (MVVM + Clean + SOLID)

High-level layers:

- `presentation/` – Widgets, Pages, ViewModels (MVVM)
- `domain/` – Entities, Repositories (interfaces), Use Cases (business rules)
- `data/` – Models, DataSources (remote/local), Repository implementations
- `core/` – Networking, Errors, DI, shared utilities

Feature-first organization is recommended (e.g., `features/scan`, `features/product`)
