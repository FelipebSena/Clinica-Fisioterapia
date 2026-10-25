# Clínica de Fisioterapia

Projeto acadêmico de Laboratório de Banco de Dados, turma 2026/2. Equipe: David Fernandes dos Santos, Felipe Romero, Caio e Felipe Sena. Documentação e validação organizadas na revisão de 25/10/2026.

## Comece por aqui

- [Índice da documentação](docs/README.md).
- [Relatório da etapa 1](docs/relatorio-etapa1.md) e [PDF](docs/relatorio-etapa1.pdf).
- [Relatório da etapa 2](docs/relatorio-etapa2.md) e [PDF](docs/relatorio-etapa2.pdf).
- [Dicionário de dados](docs/dicionario-dados.md) e [PDF](docs/dicionario-dados.pdf).
- [Decisões e correções](docs/decisoes.md), [testes e resultados](docs/validacao.md) e [backup e crescimento](docs/backup-crescimento.md).

## Ambiente e execução

Requer MySQL 8.0.18 ou superior na linha 8.x, JDK 17+ e MySQL Connector/J. Banco validado com MySQL 8.0.46; interface original apenas compilada com JDK 21.0.5, sem ensaio funcional. Não usar MariaDB como substituto: collation, roles e sintaxe diferem.

**A etapa 1 apaga e recria `clinica_fisioterapia`. Execute apenas em ambiente de desenvolvimento/avaliação com dados descartáveis.** Não execute automaticamente ao iniciar a interface.

No cliente MySQL, conectado com conta administrativa, execute a partir da raiz do repositório:

```sql
SOURCE SQL/etapa01.sql;
SOURCE SQL/etapa02.sql;
```

A etapa 1 reúne DDL, carga fictícia e 15 consultas; os antigos arquivos `01_ddl.sql`, `02_carga.sql` e `03_consultas.sql` não existem separadamente. A etapa 2 cria roles, contas de demonstração, a view restrita, auditoria e índices. As senhas aleatórias exibidas na primeira criação das contas devem ser guardadas fora do Git. Reexecutar a etapa 2 não troca essas senhas.

## Interface Java (Windows / PowerShell)

Coloque o JAR de [MySQL Connector/J](https://dev.mysql.com/doc/connector-j/en/connector-j-installing.html) em `lib/`. O JAR e os arquivos compilados não são versionados. Para compilar e executar:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
javac -encoding UTF-8 -d build interface/ClinicaApp.java
$env:DB_URL = 'jdbc:mysql://localhost:3306/clinica_fisioterapia'
$env:DB_USER = 'admin_user'
$credencial = Read-Host 'Senha da conta de demonstração' -AsSecureString
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', $credencial).Password
try { java -cp 'build;lib/*' ClinicaApp }
finally { Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue }
```

Os comandos explicam como compilar e abrir o código existente; não certificam funcionamento dos cadastros. A interface referencia objetos ausentes no esquema, possui ações incompletas e uma credencial padrão embutida. Configure as variáveis de ambiente e consulte as pendências do relatório da etapa 2. O código Java foi preservado conforme o escopo exclusivo de documentação e validação de David.

## Validação e reprodução

Consulte [o procedimento completo e as limitações](docs/validacao.md) antes de executar os testes. Há testes de banco e restauração, com saídas em `docs/evidencias/`. Eles recriam o banco e alteram contas de demonstração no **servidor descartável** indicado.

## Organização

| Caminho | Conteúdo |
| --- | --- |
| `SQL/` | Implementação das duas etapas e consultas de conferência |
| `interface/` | Aplicação Swing/JDBC |
| `scripts/` | Validação e geração da documentação |
| `docs/` | Documentação atual, fontes Markdown e PDFs |
| `docs/evidencias/` | Resultados verificáveis, sem senhas |
| `docs/historico/` | Documentos anteriores preservados para rastreabilidade |

## Situação da entrega

A revisão altera exclusivamente documentação, organização dos documentos e recursos de validação de David. Os arquivos SQL e Java permanecem iguais ao commit base `02e1469`; incompatibilidades da aplicação são apenas registradas. O enunciado integral e a rubrica do professor não estão no repositório; por isso não se declara atendimento a itens não verificáveis. As limitações do modelo estão explícitas nos relatórios. A política operacional de backup e os parâmetros de crescimento precisam de confirmação da equipe; os slides ficam para uma etapa posterior.

Foi utilizado assistente de IA na análise do código, documentação e execução de testes. A equipe deve revisar a entrega, conhecer as decisões e observar as regras da disciplina sobre declaração de uso.
