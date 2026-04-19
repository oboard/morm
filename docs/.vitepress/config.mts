import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "morm",
  description: "MoonBit ORM toolkit with schema generation, query builders, and multi-engine database support",
  cleanUrls: true,
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
          { text: 'Pagination', link: '/pagination' },
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
    outline: {
      level: [2, 3]
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/oboard/morm' }
    ]
  },
  locales: {
    root: {
      label: 'English',
      lang: 'en',
      link: '/'
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      themeConfig: {
        nav: [
          { text: '首页', link: '/zh/' },
          { text: '指南', link: '/zh/get-started' },
          { text: '引擎', link: '/zh/engines' },
          { text: '参考', link: '/zh/api-examples' }
        ],
        sidebar: [
          {
            text: '指南',
            items: [
              { text: '快速开始', link: '/zh/get-started' },
              { text: '架构设计', link: '/zh/architecture' },
              { text: '连接池', link: '/zh/connection-pooling' },
            ]
          },
          {
            text: '建模',
            items: [
              { text: '实体', link: '/zh/entities' },
              { text: '映射器', link: '/zh/mappers' },
              { text: '迁移', link: '/zh/migrations' },
            ]
          },
          {
            text: '查询',
            items: [
              { text: '查询构建器', link: '/zh/query-builders' },
              { text: '分页', link: '/zh/pagination' },
              { text: 'JSON 列', link: '/zh/json' },
              { text: '时间类型', link: '/zh/time' },
              { text: 'API 示例', link: '/zh/api-examples' }
            ]
          },
          {
            text: '引擎',
            items: [
              { text: '总览', link: '/zh/engines' },
              {
                text: 'SQL 引擎',
                items: [
                  { text: 'SQLite', link: '/zh/engine-sqlite' },
                  { text: 'MySQL', link: '/zh/engine-mysql' },
                  { text: 'PostgreSQL', link: '/zh/engine-postgresql' },
                  { text: 'SQL Server', link: '/zh/engine-sqlserver' },
                  { text: 'Oracle', link: '/zh/engine-oracle' }
                ]
              },
              {
                text: '文档引擎',
                items: [
                  { text: 'MongoDB', link: '/zh/engine-mongodb' }
                ]
              }
            ]
          }
        ]
      }
    }
  },
})
