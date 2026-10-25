# Relatório da etapa 1

Clínica de Fisioterapia | Laboratório de Banco de Dados | 2026/2

Responsável pela documentação e validação: David Fernandes dos Santos. Equipe: David, Felipe Romero, Caio e Felipe Sena. Revisão: 25/10/2026.

## 1. Objetivo e fontes

Construir um banco relacional para organizar pacientes, profissionais, tratamentos, sessões, evolução e exercícios de uma clínica de fisioterapia. Este relatório consolida o escopo original, o modelo e o comportamento efetivamente observado nos scripts. A base da revisão é o commit `02e1469` do repositório, acrescido das correções registradas em `docs/decisoes.md`.

Fontes internas: `SQL/etapa01.sql`, escopo original com RN01 a RN26, MER em `docs/mer-conceitual.drawio`, modelo lógico original e catálogo extraído do MySQL em `docs/evidencias/catalogo.json`. O enunciado integral do professor não foi disponibilizado; a matriz abaixo se refere às regras presentes no projeto.

## 2. Escopo e organização do domínio

O atendimento é organizado por tratamento, que pertence a um paciente e tem fisioterapeuta responsável e especialidade. Cada sessão depende de um tratamento, possui número próprio dentro dele, horário, sala e situação. Uma sessão realizada pode possuir uma evolução e várias aplicações de exercícios. Avaliações físicas formam histórico datado por paciente.

O modelo possui 12 entidades de domínio, mais duas tabelas associativas: `habilitacao_profissional` e `aplicacao_exercicio`. A etapa 2 acrescenta uma tabela técnica de auditoria. Não abrange faturamento, folha de pagamento, estoque, comunicação automática ou prontuário médico completo.

## 3. Modelagem e transformação relacional

- Especialização: `profissional` concentra dados comuns; `fisioterapeuta` e `estagiario` compartilham sua chave. Exclusividade é verificada por gatilhos. Totalidade é uma regra do domínio, mas não é garantida para toda operação SQL arbitrária.
- Supervisão: `estagiario.id_supervisor` referencia `fisioterapeuta.id_profissional`, e não diretamente a tabela `profissional`. Assim, o supervisor precisa pertencer ao subtipo fisioterapeuta.
- Relações N:N: habilitação registra a data por profissional/especialidade; aplicação registra séries, repetições e carga por sessão/exercício.
- Entidades dependentes: sessão usa chave `(id_tratamento, numero_sessao)`; evolução herda essa chave. A chave composta impede duplicidade, mas não exige numeração sem lacunas.
- Tratamento aberto: coluna gerada armazenada `id_especialidade_em_andamento` vale a especialidade quando não há alta e NULL após alta. A restrição única por paciente e essa coluna impede dois tratamentos abertos na mesma especialidade.

O [modelo lógico original](modelo-logico.pdf) é preservado como documento da equipe; este relatório esclarece suas divergências com o código. O [dicionário](dicionario-dados.md) contém todas as colunas físicas, inclusive FKs, campo gerado e auditoria, ausentes do dicionário conceitual anterior.

## 4. Normalização

As relações representam valores escalares e separam fatos de pacientes, convênios, profissionais e tratamentos. Nos relacionamentos associativos, os atributos descritivos dependem de toda a chave composta. Por exemplo, séries e repetições dependem de tratamento, número de sessão e exercício, em conjunto.

No modelo lógico, nomes de pacientes e especialidades não são repetidos em tratamento; telefones e e-mails não são listas. As dependências declaradas sustentam a análise de 3FN no modelo lógico sem o campo técnico derivado. A implementação física adiciona uma redundância controlada: a coluna gerada do tratamento é recalculada pelo SGBD e usada exclusivamente para RN13. Não se repete a afirmação anterior de ausência de campos calculados, nem se declara BCNF de todo o esquema físico sem ressalva.

## 5. Matriz de regras e mecanismos

| Regra | Implementação observada | Garantia e limite |
| --- | --- | --- |
| RN01 | `uq_paciente_cpf` | CPF único; dígitos verificadores não são validados no banco |
| RN02 | NOT NULL e gatilhos de nascimento INSERT/UPDATE | Data não futura; testada nos dois caminhos |
| RN03 | FK opcional `paciente.id_convenio` | No máximo um convênio; NULL representa particular |
| RN04 | ENUM e DEFAULT ATIVO | Domínio e padrão; usar modo SQL estrito |
| RN05 | PK/FKs dos subtipos e quatro gatilhos de exclusividade | Exclusividade testada em sequência; totalidade não imposta; concorrência não ensaiada |
| RN06 | NOT NULL e UNIQUE em CREFITO | Obrigatório e único; formato profissional não validado |
| RN07 | FK obrigatória para fisioterapeuta e gatilhos anti-autossupervisão | Supervisor existente no subtipo correto |
| RN08 | `habilitacao_profissional` e data obrigatória | Vínculo N:N com atributo próprio |
| RN09 | PK composta da habilitação | Impede vínculo duplicado |
| RN10 | Três FKs obrigatórias de tratamento | Paciente, fisioterapeuta e especialidade existentes |
| RN11 | Início NOT NULL; alta NULL permitida | Ausência de alta representa tratamento aberto |
| RN12 | `ck_tratamento_datas` | Alta não anterior ao início |
| RN13 | Coluna gerada e UNIQUE composto | Impede dois tratamentos abertos na mesma especialidade |
| RN14 | FKs de tratamento sem CASCADE DELETE | Bloqueia exclusão de paciente/fisioterapeuta com tratamento |
| RN15 | PK composta e CHECK de número positivo | Unicidade e dependência garantidas; sequência sem lacunas não |
| RN16 | Horário e FK de sala NOT NULL | Sessão com horário e sala existentes |
| RN17 | UNIQUE `(id_sala,data_hora)` | Bloqueia mesmo instante; não modela duração/sobreposição |
| RN18 | ENUM e DEFAULT AGENDADA | Quatro situações permitidas |
| RN19 | PK/FK da evolução e gatilhos INSERT/UPDATE/status | Evolução somente para realizada; uma por sessão |
| RN20 | PK composta de aplicação e FKs | Exercícios associados a sessões; séries/repetições positivas |
| RN21 | CHECK de carga | NULL ou carga não negativa |
| RN22 | UNIQUE `(id_paciente,data_avaliacao)` | Uma avaliação por paciente/data |
| RN23 | TINYINT UNSIGNED e CHECK 0 a 10 | Faixa de dor restringida |
| RN24 | NOT NULL e UNIQUE de convênio | Nome obrigatório no sentido de não NULL; texto vazio não bloqueado no SQL |
| RN25 | UNIQUE do código e CHECK de capacidade positiva | Capacidade armazenada; não controla ocupação simultânea |
| RN26 | UNIQUE do nome e região NOT NULL | Catálogo sem nome repetido |

Texto vazio não equivale a NULL. O banco não rejeita texto vazio em todas as colunas obrigatórias; a interface existente não foi validada como garantia complementar. O CPF fictício da carga serve a testes de identidade e unicidade, não a validação de cadastro real. Há também um convênio denominado Particular na carga; padronizar a escolha entre esse registro e NULL é uma decisão pendente de domínio.

## 6. Implementação e carga de demonstração

`SQL/etapa01.sql` cria o banco com InnoDB, utf8mb4 e collation utf8mb4_0900_ai_ci. Reúne criação, gatilhos de integridade, índices, carga fictícia e consultas. Foi executado integralmente no MySQL 8.0.46: 69 instruções sem erro.

Contagens verificadas: 40 pacientes, 40 profissionais (20 fisioterapeutas e 20 estagiários), 8 convênios, 8 especialidades, 40 habilitações, 40 tratamentos, 8 salas, 237 sessões, 169 evoluções, 13 exercícios, 440 aplicações e 103 avaliações físicas. Total: 14 tabelas de domínio e 1.286 linhas. A auditoria criada na etapa 2 inicia vazia.

A carga usa 24/10/2026 como referência explícita; datas de demonstração não devem ser confundidas com a data de uso futuro da aplicação. Foram verificadas, na carga, a presença de um subtipo por profissional, a habilitação dos fisioterapeutas para seus tratamentos e sessões dentro do período do tratamento. Essas verificações de estado não provam que toda futura inserção obedecerá às mesmas condições.

## 7. Consultas implementadas

| Número | Pergunta/resumo | Recurso |
| --- | --- | --- |
| 1 | Nomes e situações dos pacientes | Projeção |
| 2 | Pacientes ativos | WHERE |
| 3 | Pacientes em ordem alfabética | ORDER BY |
| 4 | Ana como palavra inteira no nome | LIKE |
| 5 | Nascimento 1985-1995, sem telefone, GEAP/Saúde Caixa | BETWEEN, IN, NULL e JOIN |
| 6 | Tratamentos, pacientes, fisioterapeutas e especialidades | Junção de cinco tabelas |
| 7 | Pacientes com ou sem avaliações | LEFT JOIN |
| 8 | Quantidade de tratamentos por especialidade | GROUP BY |
| 9 | Especialidades com pelo menos cinco tratamentos | HAVING |
| 10 | Sessões realizadas por paciente | Junção e agregação |
| 11 | Dor acima da média do próprio paciente | Subconsulta correlacionada |
| 12 | Fisioterapeutas habilitados em Respiratória | EXISTS |
| 13 | Exercícios nunca aplicados | NOT EXISTS |
| 14 | Pacientes com sessão realizada e dor média >= 6 | EXISTS, AVG e HAVING |
| 15 | Fisioterapeutas acima da média entre os que atendem | Agregação e subconsulta |

As consultas 10 e 14 usam junções internas e condições de existência: não pretendem listar pacientes sem atendimento com quantidade zero. A view gerencial referenciada pela interface não está definida nos scripts atuais; essa pendência pertence à implementação.

## 8. Validação, limites e conclusão da etapa

A execução das duas etapas, restrições, perfis, auditoria e restauração está registrada em `docs/evidencias/validacao.json`. A interface original foi apenas compilada, sem ensaio funcional JDBC. Os arquivos SQL e Java originais não foram alterados nesta revisão documental. A metodologia e os passos para reproduzir constam em `docs/validacao.md`.

O modelo sustenta o fluxo acadêmico demonstrado. Permanecem limites explícitos: totalidade da especialização, sequência de sessões sem lacunas, verificação de habilitação em novas gravações, sobreposição por duração e concorrência. Não há ensaio de carga de produção nem comprovação de conformidade com uma rubrica externa não recebida.

## 9. Declaração de apoio

Foi utilizado assistente de IA para apoiar a revisão, a redação, a geração dos artefatos e os testes automatizados. Resultados apresentados como executados possuem evidências versionadas; propostas e limitações são identificadas separadamente. A validação acadêmica final cabe à equipe.
