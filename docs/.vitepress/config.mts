import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "morm",
  description: "MoonBit ORM toolkit with schema generation, query builders, and multi-engine database support",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/get-started' },
      { text: 'Reference', link: '/api-examples' }
    ],

    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Get Started', link: '/get-started' },
          { text: 'Entities', link: '/entities' },
          { text: 'Mappers', link: '/mappers' },
          { text: 'Query Builders', link: '/query-builders' },
          { text: 'JSON Columns', link: '/json' },
          { text: 'Time Types', link: '/time' },
          { text: 'Engines', link: '/engines' },
          { text: 'Migrations', link: '/migrations' },
          { text: 'Architecture', link: '/architecture' }
        ]
      },
      {
        text: 'Reference',
        items: [
          { text: 'API Examples', link: '/api-examples' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/oboard/morm' }
    ]
  }
})
