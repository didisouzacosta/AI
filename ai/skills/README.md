# Skills compartilhadas de desenvolvimento Apple

Esta pasta centraliza cópias versionáveis das skills usadas pelo fluxo de
desenvolvimento iOS e macOS. As cópias foram importadas das fontes instaladas
no ambiente Codex para que os projetos consumidores tenham os arquivos
completos localmente.

Skills atualmente copiadas:

- swiftui-expert-skill
- swift-concurrency
- swiftui-patterns
- swiftui-ui-patterns
- swiftui-liquid-glass
- swiftui-view-refactor
- ios-debugger-agent

Em cada projeto consumidor, `ai/skills` deve preferencialmente ser um link para
`ai/shared/ai/skills`, com `ai/shared` fornecido por este repositório como
submodule. Assim, as skills acompanham o commit versionado da base sem serem
copiadas para cada projeto.
