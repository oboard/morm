---
layout: home

hero:
  name: "morm"
  text: "MoonBit ORM Toolkit"
  tagline: "Type-driven modeling, inspectable code generation, and unified multi-engine query workflow."
  actions:
    - theme: brand
      text: Get Started
      link: /get-started
    - theme: alt
      text: Architecture
      link: /architecture
    - theme: alt
      text: Engine Guides
      link: /engines

features:
  - title: Entity-First Modeling
    details: "Define entities with MoonBit structs and keep schema metadata synchronized with your types."
  - title: Typed Query Builders
    details: "Build select/insert/update/delete/upsert statements with typed params instead of raw string assembly."
  - title: Unified Multi-Engine API
    details: "Use one query model across SQLite, MySQL, PostgreSQL, SQL Server, Oracle, and MongoDB."
  - title: Mapper Code Generation
    details: "Generate mapper implementations from traits with mormgen to reduce repetitive boilerplate."
  - title: JSON and Time Support
    details: "Consistent handling for Json, PlainDate, PlainTime, PlainDateTime, and ZonedDateTime."
  - title: Clear Engine Boundary
    details: "Builder logic, SQL rendering, execution, and migration responsibilities are intentionally separated."
---

## Documentation Map

- Start at [Get Started](/get-started) to go from entities to execution
- Deep dive with [Entities](/entities), [Mappers](/mappers), [Query Builders](/query-builders), and [Pagination](/pagination)
- Review [Engines](/engines) for dialect, migration, and transaction differences
- Copy practical snippets from [API Examples](/api-examples)
