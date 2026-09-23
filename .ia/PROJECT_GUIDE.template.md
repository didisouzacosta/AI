# Guia de arquitetura e desenvolvimento de {{PROJECT_NAME}}

## Escopo e fontes de verdade

{{PROJECT_NAME}} é um produto {{PLATFORM_AND_CATEGORY}}.

As fontes deste checkout são, nesta ordem:

- AGENTS.md — regras de engenharia, coordenação e validação.
- PROJECT_BRIEF.md — produto, fluxos, estados e pendências.
- README.md — requisitos públicos e comandos.
- Código e configuração existentes — comportamento efetivamente conectado.

Não trate um tipo, string, pacote ou serviço sem callsite de produção como uma
feature disponível. Não faça migrações de nomes, pastas ou arquitetura sem
escopo explícito.

## Baseline efetiva

- Plataforma e versão mínima:
- Projeto/workspace:
- Schemes ou targets:
- Linguagem e versão:
- Dependências permitidas:
- Requisitos de hardware:

## Coordenação dos subagentes

Use os papéis definidos no `AGENTS.md` e detalhados no
`.ia/CODEX_ORCHESTRATOR.md`:

- Planejamento: `sol` (papel conceitual Manager), somente leitura.
- Implementação e correções: `luna` (papel conceitual Developer).
- Revisão: `sol` (papel conceitual Manager), somente leitura.

O ciclo é Manager planeja → Developer implementa e valida → Manager revisa →
Developer corrige → Manager revisa novamente até resolver todos os apontamentos.
Os IDs técnicos vêm do campo `name` dos TOML compartilhados. Confira os valores
de modelo e esforço que o runtime expõe contra esses TOML; bloqueie se forem
divergentes e declare a limitação quando a ferramenta não expuser esses dados.

## Arquitetura

Descreva os módulos, fronteiras de responsabilidade, composição de
dependências, navegação, persistência e integrações externas.

- Entrada e composição:
- Domínio:
- Features:
- Infraestrutura:
- Componentes compartilhados:
- Testes:

## Estado, concorrência e efeitos

- Fonte de verdade de cada estado:
- Isolamento de atores e tarefas:
- Cancelamento e invalidação de resultados obsoletos:
- Limites de memória e trabalho pendente:
- Permissões, rede, arquivos e outros efeitos:

## Regras de implementação

- Injete serviços e protocolos nas fronteiras de comportamento.
- Use dublês nos testes e nas previews.
- Preserve cancelamento, isolamento e tratamento de erros.
- Não adicione dependências sem aprovação explícita.
- Mantenha segredos fora do repositório.
- Preserve alterações locais não relacionadas.

## Estilo e formatação Swift

- Convenção geral: [Google Swift Style Guide](https://google.github.io/swift/),
  aplicada a todo código Swift, incluindo arquivos sem SwiftUI e testes.
- Cadeias de modificadores SwiftUI: cada modificador em sua própria linha,
  conforme os exemplos da Apple em
  [Configuring Views](https://developer.apple.com/documentation/swiftui/configuring-views).
- Ferramentas e versões fixadas:
- Comandos de lint e formatação usados localmente e no CI:
- Exceções locais justificadas:

## Previews SwiftUI

- Toda `View` criada deve ter `#Preview` para cada estado de apresentação
  suportado, incluindo os estados de carregamento, vazio, erro e sucesso quando
  fizerem parte do contrato da tela.
- Use `@Previewable` em cada propriedade dinâmica local necessária para
  configurar esses estados dentro do corpo de `#Preview`. Esse macro só é
  válido nesse corpo e não substitui a declaração dos previews para cada estado.
- Injete dados e dependências determinísticos; não conecte previews a serviços
  reais, rede, autenticação ou arquivos mutáveis do usuário.
- Convenção confirmada com a documentação da Apple:
  [Previewable](<https://developer.apple.com/documentation/swiftui/previewable()>).

## Testes e validação

Registre comandos e resultados reais. Separe compilação e Simulator de
validação em dispositivo físico e de serviços externos.

- Testes unitários:
- Testes de integração:
- Build:
- Simulator:
- Dispositivo físico:
- Serviços live:
- Validações ainda não executadas:

## Entrega

- Checklist de aceitação:
- Arquivos de documentação a atualizar:
- Artefatos temporários a limpar:
- Estado de commit esperado:
- Riscos conhecidos:
