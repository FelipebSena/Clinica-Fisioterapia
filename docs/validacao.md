# Registro de testes e resultados

Revisão exclusiva de documentação e validação. Os scripts SQL e a aplicação foram preservados conforme o commit `02e1469`. As evidências foram produzidas sobre esses arquivos originais, e não sobre alterações propostas para a implementação.

## Ambiente e método

Windows, MySQL 8.0.46/InnoDB, cliente PyMySQL, Python e JDK 21.0.5. Foi criada uma instância MySQL descartável em diretório próprio e porta 33317, limitada a 127.0.0.1, sem utilizar o serviço MySQL80 da equipe. O banco foi recriado pelos dois scripts do projeto; somente dados fictícios da carga foram usados. Data e modo SQL completos estão em `evidencias/validacao.json`.

## Evidências

| Arquivo | Conteúdo |
| --- | --- |
| `evidencias/validacao.json` | Casos, resultados, códigos de erro, versão, data e hashes dos dois scripts |
| `evidencias/carga.json` | Contagens e hashes de dados por tabela |
| `evidencias/catalogo.json` | Colunas e SHOW CREATE TABLE das 15 tabelas |
| `evidencias/explain.json` | SQL exato, planos antes/depois, tempos individuais e hashes de resultados |
| `evidencias/verificacao-documental.json` | Cobertura de dicionário, links e integridade do escopo documental |

O teste usa falhas esperadas para verificar restrições. Um erro SQL esperado e com código conferido é aprovação do teste negativo; ausência de erro é falha. Casos DML são revertidos, e as tabelas são comparadas antes/depois. Os testes de backup restauram a mesma base apenas dentro da instância descartável.

## Resultado da execução

<!-- TESTES_INICIO -->
Execução: 2026-10-25T12:18:14.117362-03:00. MySQL 8.0.46. **54 testes passaram; 0 falharam.**

| Caso executado | Resultado | Evidência resumida |
| --- | --- | --- |
| Servidor MySQL 8 (não MariaDB) | PASSOU | 8.0.46 |
| Etapa 1: criação, carga e 15 consultas | PASSOU | 69 instruções sem erro |
| Etapa 2: perfis, views, auditoria e índices | PASSOU | 48 instruções sem erro |
| Consulta 5: mesmo resultado antes/depois dos índices | PASSOU | Condição verificada pelo teste |
| Consulta 10: mesmo resultado antes/depois dos índices | PASSOU | Condição verificada pelo teste |
| Consulta 14: mesmo resultado antes/depois dos índices | PASSOU | Condição verificada pelo teste |
| Reexecução da etapa 2 preserva dados | PASSOU | Condição verificada pelo teste |
| 14 tabelas de domínio e 1 de auditoria | PASSOU | 15 |
| RN01: CPF de paciente duplicado | PASSOU | código MySQL 1062 |
| RN02: nascimento futuro INSERT | PASSOU | código MySQL 1644 |
| RN02: nascimento futuro UPDATE | PASSOU | código MySQL 1644 |
| RN04: situação inválida | PASSOU | código MySQL 1265 |
| RN05: subtipos exclusivos | PASSOU | código MySQL 1644 |
| RN06: CREFITO único | PASSOU | código MySQL 1062 |
| RN07: supervisor inexistente | PASSOU | código MySQL 1452 |
| RN09: habilitação duplicada | PASSOU | código MySQL 1062 |
| RN10: tratamento sem paciente válido | PASSOU | código MySQL 1452 |
| RN12: alta anterior ao início | PASSOU | código MySQL 3819 |
| RN13: dois tratamentos abertos na mesma especialidade | PASSOU | código MySQL 1062 |
| RN14: excluir paciente com tratamento | PASSOU | código MySQL 1451 |
| RN15: sessão duplicada | PASSOU | código MySQL 1062 |
| RN15: número de sessão zero | PASSOU | código MySQL 3819 |
| RN17: sala e horário duplicados | PASSOU | código MySQL 1062 |
| RN18: situação de sessão inválida | PASSOU | código MySQL 1265 |
| RN19: evolução em sessão não realizada | PASSOU | código MySQL 1644 |
| RN19: sessão com evolução deixa de ser realizada | PASSOU | código MySQL 1644 |
| RN21: carga negativa | PASSOU | código MySQL 3819 |
| Séries positivas | PASSOU | código MySQL 3819 |
| Repetições positivas | PASSOU | código MySQL 3819 |
| RN22: avaliação duplicada por paciente e data | PASSOU | código MySQL 1062 |
| RN23: dor acima de 10 | PASSOU | código MySQL 3819 |
| RN24: nome de convênio duplicado | PASSOU | código MySQL 1062 |
| RN25: capacidade zero | PASSOU | código MySQL 3819 |
| RN26: nome de exercício duplicado | PASSOU | código MySQL 1062 |
| Carga: todo profissional tem exatamente um subtipo | PASSOU | Condição verificada pelo teste |
| Carga: fisioterapeutas habilitados no tratamento | PASSOU | Condição verificada pelo teste |
| Carga: sessões dentro do período do tratamento | PASSOU | Condição verificada pelo teste |
| View restrita não expõe CPF/telefone/convênio | PASSOU | Condição verificada pelo teste |
| Auditoria UPDATE: antes/depois e usuário conectado | PASSOU | Condição verificada pelo teste |
| Auditoria exclusão via evolucao | PASSOU | Condição verificada pelo teste |
| Auditoria exclusão via sessao | PASSOU | Condição verificada pelo teste |
| Auditoria exclusão via tratamento | PASSOU | Condição verificada pelo teste |
| Perfil ativo: Administrador | PASSOU | Condição verificada pelo teste |
| Perfil ativo: Fisioterapeuta | PASSOU | Condição verificada pelo teste |
| Fisioterapeuta consulta pacientes | PASSOU | Condição verificada pelo teste |
| Fisioterapeuta não exclui paciente | PASSOU | Condição verificada pelo teste |
| Perfil ativo: Estagiario | PASSOU | Condição verificada pelo teste |
| Estagiário consulta view restrita | PASSOU | Condição verificada pelo teste |
| Estagiário não lê tabela paciente | PASSOU | Condição verificada pelo teste |
| Testes transacionais preservam dados | PASSOU | Condição verificada pelo teste |
| Backup/restauração: contagem e SHA-256 de todas as tabelas | PASSOU | Condição verificada pelo teste |
| Backup/restauração: view restrita | PASSOU | Condição verificada pelo teste |
| Backup/restauração: 15 gatilhos | PASSOU | Condição verificada pelo teste |
| Backup/restauração: gatilho de auditoria funciona | PASSOU | Condição verificada pelo teste |

Backup completo: 113,803 bytes; 0.136 s para gerar e 1.357 s para restaurar. Tempos de base acadêmica local, sem garantia de recuperação de produção.
<!-- TESTES_FIM -->

## O que foi validado e o que não foi

Executado: criação e carga da etapa 1; reexecução da etapa 2; restrições enumeradas acima; coerência selecionada da carga; acesso por perfis; auditoria direta e em cascata; equivalência dos resultados antes/depois dos índices; dump/restauração com comparação das 15 tabelas; view, gatilhos e auditoria após restauração.

Inspecionado/compilado: `interface/ClinicaApp.java`, sem ensaio funcional da interface. Compilação bem-sucedida não comprova execução de SQL, funcionalidade de botões, segurança de entradas nem COMMIT/ROLLBACK do Java. As divergências constam no relatório 2 e não foram corrigidas, por pertencerem à parte de implementação de outros integrantes.

Não executado: teste visual completo da interface, concorrência, carga de produção, recuperação após perda de máquina, nuvem e agendamento. Os testes sequenciais não provam ausência de corrida entre transações. RN05 totalidade e RN15 sequência sem lacunas não são garantidas pelo modelo atual e não recebem aprovação artificial.

## Reprodução dos testes do banco

**O script apaga/recria clinica_fisioterapia e troca senhas das contas de demonstração no servidor escolhido. Use uma instância descartável, nunca a base de trabalho.** O argumento de confirmação evita execução acidental, mas não verifica se a instância é realmente descartável.

1. Criar servidor MySQL 8.0 compatível, isolado, com clientes mysql e mysqldump disponíveis.
2. Na raiz do repositório, instalar `python -m pip install -r scripts/requirements.txt`.
3. Definir MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD e MYSQL_BIN (diretório dos executáveis). Não guardar credenciais no repositório.
4. Executar `python scripts/validar_banco.py --confirmar-base-descartavel`.
5. Conferir saída de sucesso, JSON de evidências e código de saída zero. Uma execução interrompida ou com erro não substitui evidência aprovada, mesmo se o resumo parcial contiver testes aprovados.
6. Executar `python scripts/gerar_documentacao.py` para refletir os resultados na documentação e nos PDFs; revisar páginas renderizadas antes de entregar.

EXPLAIN é coletado sobre as consultas 5, 10 e 14, com estatísticas atualizadas. Cada cenário usa uma execução de aquecimento e 15 medições. As medianas incluem comunicação com o cliente e não são benchmark de produção. O relatório 2 discute planos e limitações.

## Reprodução da compilação

```powershell
New-Item -ItemType Directory -Force build | Out-Null
javac -encoding UTF-8 -d build interface/ClinicaApp.java
```

Resultado observado: código de saída zero, com JDK 21.0.5. O driver JDBC é necessário para executar conexões, não para compilar imports de java.sql. Não há teste funcional Java versionado nesta revisão.

## Critério de atualização

Se os scripts originais forem alterados pelos responsáveis, repetir a validação e registrar novos hashes, ambiente e resultados. Não reaproveitar como atuais evidências de uma versão antiga. As conclusões sobre desempenho e backup precisam ser reavaliadas quando volume, hardware, versão ou configuração mudarem.
