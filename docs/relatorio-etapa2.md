# Relatório da etapa 2

Clínica de Fisioterapia | Laboratório de Banco de Dados | 2026/2

Responsável pela documentação e validação: David Fernandes dos Santos. Equipe: David, Felipe Romero, Caio e Felipe Sena. Revisão: 25/10/2026.

## 1. Objetivo e rastreabilidade

Esta etapa reúne interface Java/JDBC, consultas parametrizadas, relatório gerencial, segurança, auditoria, análise de índices e planejamento físico. As designações B4, B5, B6 e B7 são preservadas dos arquivos existentes; não se presume uma rubrica completa para os demais itens.

Fontes: `SQL/etapa01.sql`, `SQL/etapa02.sql`, `interface/ClinicaApp.java` e resultados em `docs/evidencias/`. O relatório anterior de Felipe Romero, commit `6525092`, foi preservado em `docs/historico/relatorio-etapa2.pdf`. Esta revisão substitui conclusões não demonstradas por medições e ressalvas verificáveis.

## 2. Interface e integração: análise documental

O arquivo `interface/ClinicaApp.java` foi inspecionado e compilado com JDK 21.0.5. A compilação passou, mas não verifica os nomes de tabelas nem executa as ações JDBC. A interface e os scripts SQL não foram alterados: esta entrega é exclusivamente a documentação e validação de David.

| Achado no código original | Efeito esperado pela leitura do código | Situação |
| --- | --- | --- |
| CRUD usa coluna `id` em todas as entidades | O esquema possui chaves específicas, como id_paciente | Pendência de implementação |
| Referência à tabela equipamento | Tabela não existe no esquema | Pendência de implementação |
| Campos de sala e fisioterapeuta incompatíveis | Não correspondem às colunas físicas | Pendência de implementação |
| Botões Criar e Atualizar sem listeners | Ações não implementadas | Pendência de implementação |
| Consulta por ID enviada a executeUpdate | SELECT deve usar executeQuery | Pendência de implementação |
| Consultas usam id_sessao, p.id e s.id_paciente | Sessão tem chave composta e se liga ao paciente por tratamento | Pendência de implementação |
| View vw_relatorio_consolidado referenciada | Não é criada por etapa01.sql nem etapa02.sql | Pendência de implementação |
| Credencial padrão embutida | Variáveis de ambiente não eliminam o fallback no arquivo | Pendência de implementação; valor não reproduzido aqui |
| Resposta clínica positiva fixa na transação | Texto não é informado pelo usuário | Pendência de implementação |

A operação transacional existente tenta inserir sessão e evolução com autocommit desativado, usa COMMIT e trata falhas com ROLLBACK. Há PreparedStatement nos caminhos consultados. Esses mecanismos foram identificados por inspeção; não se declara que o fluxo da interface, a resistência a injeção, o rollback Java ou os perfis na tela tenham sido testados funcionalmente.

Os erros acima estão registrados para os responsáveis pela implementação. Nenhuma correção de Java ou de SQL faz parte desta revisão. O teste de banco descrito adiante verifica diretamente os objetos existentes, sem depender da interface.

## 3. B4 - análise de três consultas

Foram usadas exatamente as consultas 5, 10 e 14 da etapa 1. A consulta 5 atual usa convênios GEAP/Saúde Caixa e não filtra situação cadastral; o relatório anterior descrevia pacientes ativos e outros convênios, divergindo do SQL. Não se adicionou um filtro de ativos que a pergunta atual não solicita.

Método: mesma carga e mesma instância MySQL 8.0.46; ANALYZE TABLE antes de cada cenário; EXPLAIN FORMAT=JSON e EXPLAIN ANALYZE; uma execução de aquecimento e 15 medições por consulta usando relógio monotônico no cliente Python. O cenário anterior inclui os índices da etapa 1; o posterior acrescenta os índices da etapa 2. Hashes comprovam resultados idênticos antes/depois.

<!-- PERF_INICIO -->
| Consulta | Linhas retornadas | Custo antes/depois | Mediana antes (ms) | Mediana depois (ms) |
| --- | --- | --- | --- | --- |
| 5 | 2 | 3.07 / 3.07 | 0.3053 | 0.2896 |
| 10 | 40 | 52.00 / 40.76 | 0.6585 | 0.6387 |
| 14 | 14 | 68.72 / 61.91 | 0.7702 | 0.6506 |
<!-- PERF_FIM -->

O custo do otimizador é uma estimativa sem unidade de tempo. A mediana do cliente inclui comunicação, execução e leitura dos resultados; não mede apenas CPU do servidor. A base é pequena, os cenários foram executados sequencialmente e não houve ensaio estatístico ou carga concorrente. Diferenças inferiores a um milissegundo não justificam prometer ganho em produção.

### Consulta 5 - faixa de nascimento, convênio e telefone ausente

Índice avaliado: `idx_paciente_busca (data_nascimento, id_convenio, telefone)`. O plano observado manteve `uq_convenio_nome` e `idx_paciente_convenio`, antes e depois. O índice proposto não foi escolhido nesta carga. Não se comprovou a passagem de varredura completa para range alegada no relatório anterior. Uma faixa na primeira coluna também limita o uso das colunas seguintes para delimitar intervalos; o índice não cobre nome, retornado pela consulta.

Decisão: preservar o índice existente para rastrear a proposta da equipe, mas classificá-lo como candidato sem benefício demonstrado para esta consulta. Reavaliar com volume representativo antes de mantê-lo em uma implantação real.

### Consulta 10 - sessões realizadas por paciente

Índice: `idx_sessao_situacao (situacao, id_tratamento)`. Antes, o acesso às sessões usa a chave primária pelo tratamento e filtra situação. Depois, o plano utiliza o novo índice como acesso coberto por situação e tratamento. A estimativa de custo cai; a mediana medida não necessariamente acompanha a estimativa. A agregação e ordenação permanecem no plano, e não se afirma eliminação geral de varreduras ou tabelas temporárias.

### Consulta 14 - sessões realizadas e média de dor >= 6

Índices: `idx_sessao_situacao` e `idx_avaliacao_dor (id_paciente, nivel_dor)`. O plano posterior utiliza acessos cobertos aos dois conjuntos. O índice de avaliação cobre os campos necessários dessa tabela, mas não todos os dados de paciente. A redução do custo estimado é observada no cenário; a contribuição individual de cada índice não foi isolada. HAVING, agrupamento e ordenação continuam necessários.

Os planos completos, tempos individuais, SQL e hashes estão em `docs/evidencias/explain.json`. A remoção de `idx_avaliacao_paciente` mantém um índice iniciado por id_paciente, preservando o suporte à FK.

## 4. B5 - segurança e perfis

| Perfil | Permissões implementadas | Verificação e limite |
| --- | --- | --- |
| Administrador | ALL PRIVILEGES no banco do projeto | Não implica administração global do servidor |
| Fisioterapeuta | SELECT em cadastros; SELECT/INSERT/UPDATE nos dados operacionais | DELETE de paciente foi recusado; sem permissão geral de cadastro |
| Estagiario | SELECT na view restrita e em tratamento; SELECT/INSERT/UPDATE em evolução | SELECT direto de CPF foi recusado |

As contas de demonstração recebem senhas aleatórias pelo MySQL e roles padrão. A view restrita expõe id, nome, nascimento e situação, omitindo CPF, telefone e convênio. Ela não anonimiza o paciente e não filtra pacientes por supervisor. A política implementada atua por objeto/coluna, não por linha ou por vínculo clínico individual.

A view restrita usa SQL SECURITY DEFINER, padrão do MySQL. O criador precisa continuar existindo e possuir privilégios apropriados, inclusive após restauração. A aplicação pode exibir ações indisponíveis para determinado perfil; o banco as recusa. Melhorias de interface por perfil ficam fora da validação visual desta revisão.

## 5. B6 - gatilhos e auditoria

`auditoria_evolucao` registra UPDATE e DELETE, conteúdo anterior/novo, chaves da sessão, usuário conectado e horário. Não existe FK para a sessão: o histórico precisa sobreviver à exclusão do dado de origem. `usuario_db` comporta até 288 caracteres para usuário e host.

Os gatilhos usam USER(), pois CURRENT_USER() dentro de um gatilho representa o definidor. Como exclusões em cascata não disparam gatilhos nas tabelas dependentes no MySQL, há gatilhos adicionais antes da exclusão direta de sessão ou tratamento. Os testes verificaram exclusão direta de evolução e ambos os caminhos de cascata, com quantidade correta de registros de auditoria.

A auditoria participa da mesma transação: um ROLLBACK desfaz dados e logs dessa operação. Ela não registra INSERT de evolução, consultas nem tentativas recusadas. A conta Administrador pode alterar/excluir a auditoria; portanto ela não é um registro imutável ou resistente a administrador malicioso. IDs alterados via cascata também não recebem rastreamento completo.

## 6. B7 - projeto físico e crescimento

Todas as tabelas usam InnoDB e utf8mb4. Chaves inteiras usam INT UNSIGNED; nível de dor usa TINYINT UNSIGNED com CHECK; carga usa DECIMAL(8,2); as situações usam ENUM. Esses tipos correspondem ao DDL. O custo total em disco inclui registros, índices, páginas e espaço livre: não se estima o banco somando apenas larguras nominais.

O cenário herdado do relatório de Felipe considera 20 profissionais, 10 sessões por dia, 22 dias por mês e 12 meses. A fórmula é 20 × 10 × 22 × 12 = 52.800 sessões/ano. É uma hipótese de planejamento, não volume real medido. A proporção de 85% de crescimento atribuída anteriormente a três tabelas não possui evidência e foi retirada.

Com hipótese adicional de 80% de sessões realizadas, uma evolução por sessão realizada e três exercícios por sessão realizada: 42.240 evoluções e 126.720 aplicações por ano, além das 52.800 sessões. São 221.760 novas linhas anuais nessas três tabelas. Auditoria, pacientes, avaliações e tratamentos exigem estimativas próprias. Detalhamento, cenários e consulta de dimensionamento estão em `docs/backup-crescimento.md`.

Não se recomenda aplicar PARTITION BY RANGE à tabela sessão atual. O particionamento InnoDB é incompatível com suas relações de chave estrangeira; também há exigências de inclusão da chave de particionamento em todas as chaves únicas. Preservar integridade e medir índices é a decisão atual. Qualquer reestruturação futura exigirá outro desenho e testes, não um ALTER isolado. Referência: manual oficial do MySQL, restrições de particionamento.

## 7. Backup e recuperação

O relatório anterior tratava mysqldump como opção de backup diferencial. A proposta corrigida adota backup lógico completo com mysqldump. O procedimento documentado usa snapshot consistente para InnoDB, inclui rotinas, eventos e gatilhos e grava diretamente em arquivo. A ferramenta de validação executa o procedimento em ambiente descartável e calcula SHA-256; nenhuma rotina operacional é instalada.

O ensaio desta revisão fez dump e restauração em servidor descartável. Contagens e hashes de todas as tabelas coincidiram, a view restrita e os 15 gatilhos foram restaurados, e um gatilho de auditoria foi executado com sucesso após restauração. Valores medidos e hash do arquivo estão em `docs/evidencias/validacao.json`; esse ensaio pequeno não comprova RTO de produção.

Agendamento diário às 02h, retenção de 30 dias, cópia externa e guarda mensal são propostas a confirmar com Felipe. Não há tarefa agendada nem armazenamento em nuvem configurados no repositório. RPO proposto: até 24 horas, condicionado ao sucesso do último backup e da cópia externa. RTO deve ser definido e validado em restauração representativa; nenhum prazo aprovado pela clínica foi encontrado. Recuperação ponto a ponto exigiria binlogs preservados e um procedimento adicional, não implementado.

## 8. Resultados e pendências

A documentação acompanha os scripts SQL originais executados e indica explicitamente o que é proposta. A interface foi apenas inspecionada e compilada, e suas pendências permanecem sob responsabilidade da implementação. Os relatórios não prometem desempenho nem disponibilidade sem teste correspondente. `docs/validacao.md` reúne resultados, método, reprodução e limites.

Antes de entregar: confirmar a rubrica oficial; revisar os limites de totalidade e agenda com a equipe; confirmar com Felipe as premissas operacionais; ensaiar a interface visualmente no computador de apresentação. Os slides serão preparados após essa revisão, em etapa separada.

## 9. Referências e declaração

- Código e evidências: arquivos citados neste relatório e registro `docs/decisoes.md`.
- MySQL, índices compostos: https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html
- MySQL, particionamento e engines: https://dev.mysql.com/doc/refman/8.0/en/partitioning-limitations-storage-engines.html
- MySQL, mysqldump: https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html
- MySQL, Connector/J: https://dev.mysql.com/doc/connector-j/en/connector-j-installing.html

Consulta às referências: 25/10/2026. Foi utilizado assistente de IA na revisão e na execução de testes; a equipe deve revisar os artefatos e compreender as decisões. Não se atribui esta revisão ao professor nem se apresenta conteúdo gerado anteriormente como medição experimental.
