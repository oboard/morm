import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "morm",
  description: "MoonBit ORM toolkit with schema generation, query builders, and multi-engine database support",
  markdown: {
    languages: ['moonbit'],
    languageAlias: {
      mbt: 'moonbit',
      mbti: 'moonbit'
    }
  },
  themeConfig: {
    search: {
      provider: 'local'
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/get-started' },
      { text: 'Engines', link: '/engines' },
      { text: 'Reference', link: '/api-examples' }
    ],

    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Get Started', link: '/get-started' },
          { text: 'Architecture', link: '/architecture' },
          { text: 'Connection Pooling', link: '/connection-pooling' },
        ]
      },
      {
        text: 'Modeling',
        items: [
          { text: 'Entities', link: '/entities' },
          { text: 'Mappers', link: '/mappers' },
          { text: 'Migrations', link: '/migrations' },
        ]
      },
      {
        text: 'Querying',
        items: [
          { text: 'Query Builders', link: '/query-builders' },
          { text: 'JSON Columns', link: '/json' },
          { text: 'Time Types', link: '/time' },
          { text: 'API Examples', link: '/api-examples' }
        ]
      },
      {
        text: 'Engines',
        items: [
          { text: 'Overview', link: '/engines' },
          {
            text: 'SQL Engines',
            items: [
              { text: 'SQLite', link: '/engine-sqlite' },
              { text: 'MySQL', link: '/engine-mysql' },
              { text: 'PostgreSQL', link: '/engine-postgresql' },
              { text: 'SQL Server', link: '/engine-sqlserver' },
              { text: 'Oracle', link: '/engine-oracle' }
            ]
          },
          {
            text: 'Document Engine',
            items: [
              { text: 'MongoDB', link: '/engine-mongodb' }
            ]
          }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/oboard/morm' }
    ]
  }
})
