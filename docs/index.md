---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "morm"
  text: "MoonBit ORM Toolkit"
  tagline: "Schema generation, query builders, and multi-engine database access for MoonBit."
  actions:
    - theme: brand
      text: Get Started
      link: /get-started
    - theme: alt
      text: Architecture
      link: /architecture

features:
  - title: Entity-First Modeling
    details: Define MoonBit structs with `#morm.entity` annotations and generate table metadata directly from your types.
  - title: Typed Query Builders
    details: Build `select`, `insert`, `update`, `delete`, and `upsert` statements with typed params instead of hand-written SQL strings.
  - title: Multi-Engine Support
    details: Target MySQL, PostgreSQL, SQLite, SQL Server, and Oracle through a common query and parameter model.
  - title: Mapper Generation
    details: Use `mormgen` to generate mapper implementations from annotated traits and keep boilerplate out of your codebase.
  - title: JSON-Friendly Models
    details: Integrates with `ToJson` and `FromJson` flows so entities can move cleanly between DB rows and application data.
  - title: Time Type Support
    details: Built-in support for `PlainDate`, `PlainTime`, `PlainDateTime`, and `ZonedDateTime` in params and JSON serialization.
  - title: Auto Timestamps
    details: `created_at` and `updated_at` can be filled automatically in generated save methods, with opt-in annotations for custom field names.
  - title: Explicit Architecture
    details: ORM concerns, engine-specific execution, and code generation stay separated so behavior is easier to reason about and extend.
---
