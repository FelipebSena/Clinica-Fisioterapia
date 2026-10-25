# Dicionário de dados

Clínica de Fisioterapia | David Fernandes dos Santos | 25/10/2026

As 15 tabelas abaixo correspondem às duas etapas do banco, executadas no MySQL 8.0.46. O catálogo completo está em docs/apoio/evidencias.json. Todas as tabelas usam InnoDB, utf8mb4 e collation utf8mb4_0900_ai_ci.

**Legenda:** PK = chave primária; FK = chave estrangeira; único = valor ou combinação sem repetição. NULL representa ausência. AUTO_INCREMENT e campos gerados são preenchidos pelo banco. FK sem ação explícita usa RESTRICT/NO ACTION.

NOT NULL não impede texto vazio. O banco não valida todos os formatos de CPF, e-mail e telefone. As situações ENUM foram testadas em modo SQL estrito. TEXT armazena até 65.535 bytes, e VARCHAR limita a quantidade de caracteres. O relatório reúne as demais regras e os testes.

## 1. convenio

Catálogo de convênios; paciente pode não possuir vínculo.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_convenio` | int unsigned | Não | AUTO_INCREMENT | Identificador do convênio. |
| `nome` | varchar(150) | Não | Sem padrão | Nome usado no cadastro. |

**Chaves e restrições**

- PK: (id_convenio)
- Único: (nome)

## 2. paciente

Cadastro de pacientes e situação administrativa.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_paciente` | int unsigned | Não | AUTO_INCREMENT | Identificador do paciente. |
| `cpf` | char(11) | Não | Sem padrão | CPF em texto, sem pontuação. Os dígitos verificadores não são validados. |
| `nome` | varchar(150) | Não | Sem padrão | Nome usado no cadastro. |
| `data_nascimento` | date | Não | Sem padrão | Data de nascimento. Gatilhos impedem data futura. |
| `telefone` | varchar(20) | Sim | NULL | Um contato principal; NULL indica ausência. |
| `situacao` | enum('ATIVO','INATIVO') | Não | ATIVO | Situação cadastral do paciente. |
| `id_convenio` | int unsigned | Sim | NULL | Identificador do convênio. |

**Chaves e restrições**

- PK: (id_paciente)
- Único: (cpf)
- FK: (id_convenio) -> convenio (id_convenio); exclusão SET NULL; atualização CASCADE

Índices adicionais: (id_convenio), (data_nascimento,id_convenio,telefone).

## 3. profissional

Dados comuns aos dois subtipos de profissionais.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | AUTO_INCREMENT | Identificador do profissional. |
| `nome` | varchar(150) | Não | Sem padrão | Nome usado no cadastro. |
| `cpf` | char(11) | Não | Sem padrão | CPF em texto, sem pontuação. Os dígitos verificadores não são validados. |
| `telefone` | varchar(20) | Sim | NULL | Um contato principal; NULL indica ausência. |
| `email` | varchar(254) | Sim | NULL | Um endereço de e-mail; formato não validado por CHECK. |

**Chaves e restrições**

- PK: (id_profissional)
- Único: (cpf)

## 4. fisioterapeuta

Subtipo profissional habilitado a responder por tratamento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | Identificador do profissional. |
| `crefito` | varchar(30) | Não | Sem padrão | Registro profissional único; formato não validado pelo banco. |

**Chaves e restrições**

- PK: (id_profissional)
- Único: (crefito)
- FK: (id_profissional) -> profissional (id_profissional); exclusão CASCADE; atualização CASCADE

## 5. estagiario

Subtipo com instituição de ensino e supervisor fisioterapeuta.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | Identificador do profissional. |
| `instituicao_ensino` | varchar(150) | Não | Sem padrão | Instituição do estagiário. |
| `id_supervisor` | int unsigned | Não | Sem padrão | Fisioterapeuta supervisor; obrigatório; não pode ser o próprio estagiário. |

**Chaves e restrições**

- PK: (id_profissional)
- FK: (id_profissional) -> profissional (id_profissional); exclusão CASCADE; atualização CASCADE
- FK: (id_supervisor) -> fisioterapeuta (id_profissional); exclusão RESTRICT; atualização CASCADE

Índices adicionais: (id_supervisor).

## 6. especialidade

Catálogo de especialidades de atendimento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_especialidade` | int unsigned | Não | AUTO_INCREMENT | Identificador da especialidade. |
| `nome` | varchar(100) | Não | Sem padrão | Nome usado no cadastro. |
| `descricao` | text | Sim | NULL | Descrição livre opcional do catálogo. |

**Chaves e restrições**

- PK: (id_especialidade)
- Único: (nome)

## 7. habilitacao_profissional

Associação N:N entre profissional e especialidade, com data.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_profissional` | int unsigned | Não | Sem padrão | Identificador do profissional. |
| `id_especialidade` | int unsigned | Não | Sem padrão | Identificador da especialidade. |
| `data_habilitacao` | date | Não | Sem padrão | Data em que o profissional obteve habilitação na especialidade. |

**Chaves e restrições**

- PK: (id_profissional,id_especialidade)
- FK: (id_especialidade) -> especialidade (id_especialidade); exclusão RESTRICT; atualização CASCADE
- FK: (id_profissional) -> profissional (id_profissional); exclusão CASCADE; atualização CASCADE

Índices adicionais: (id_especialidade).

## 8. tratamento

Plano de atendimento vinculado a paciente, responsável e especialidade.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | AUTO_INCREMENT | Identificador do tratamento. |
| `descricao_condicao` | varchar(255) | Não | Sem padrão | Condição ou objetivo terapêutico do tratamento. |
| `data_inicio` | date | Não | Sem padrão | Início do tratamento; obrigatório. |
| `data_alta` | date | Sim | NULL | Alta do tratamento; NULL indica aberto; não anterior ao início. |
| `id_paciente` | int unsigned | Não | Sem padrão | Identificador do paciente. |
| `id_fisioterapeuta` | int unsigned | Não | Sem padrão | Identificador do fisioterapeuta responsável. |
| `id_especialidade` | int unsigned | Não | Sem padrão | Identificador da especialidade. |
| `id_especialidade_em_andamento` | int unsigned | Sim | Gerada STORED; ver expressão abaixo | Campo gerado: especialidade se alta é NULL; caso contrário NULL. Não preencher manualmente. |

**Chaves e restrições**

- PK: (id_tratamento)
- Único: (id_paciente,id_especialidade_em_andamento)
- FK: (id_especialidade) -> especialidade (id_especialidade)
- FK: (id_fisioterapeuta) -> fisioterapeuta (id_profissional)
- FK: (id_paciente) -> paciente (id_paciente)
- CHECK: (((data_alta is null) or (data_alta >= data_inicio)))

Índices adicionais: (id_paciente), (id_fisioterapeuta), (id_especialidade).

Expressão gerada: `(case when (`data_alta` is null) then `id_especialidade` else NULL end)`.

## 9. sala

Local físico; a capacidade é descritiva e não controla concorrência de agenda.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_sala` | int unsigned | Não | AUTO_INCREMENT | Identificador da sala. |
| `codigo` | varchar(30) | Não | Sem padrão | Código único de identificação da sala. |
| `capacidade` | int unsigned | Não | Sem padrão | Capacidade declarada positiva; não calcula ocupação. |

**Chaves e restrições**

- PK: (id_sala)
- Único: (codigo)
- CHECK: ((capacidade > 0))

## 10. sessao

Atendimento identificado dentro de um tratamento.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | Identificador do tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `data_hora` | datetime | Não | Sem padrão | Data e horário da sessão; sem fuso armazenado. |
| `situacao` | enum('AGENDADA','REALIZADA','CANCELADA','FALTA') | Não | AGENDADA | Situação da sessão. |
| `id_sala` | int unsigned | Não | Sem padrão | Identificador da sala. |

**Chaves e restrições**

- PK: (id_tratamento,numero_sessao)
- Único: (id_sala,data_hora)
- FK: (id_sala) -> sala (id_sala); exclusão RESTRICT; atualização CASCADE
- FK: (id_tratamento) -> tratamento (id_tratamento); exclusão CASCADE; atualização CASCADE
- CHECK: ((numero_sessao > 0))

Índices adicionais: (id_sala), (data_hora), (situacao,id_tratamento).

## 11. evolucao

Registro de conduta e resposta de uma sessão realizada.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | Identificador do tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `conduta_aplicada` | text | Não | Sem padrão | Texto da conduta da sessão realizada. |
| `resposta_observada` | text | Não | Sem padrão | Texto da resposta observada na sessão. |

**Chaves e restrições**

- PK: (id_tratamento,numero_sessao)
- FK: (id_tratamento, numero_sessao) -> sessao (id_tratamento, numero_sessao); exclusão CASCADE; atualização CASCADE

## 12. exercicio

Catálogo de exercícios terapêuticos.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_exercicio` | int unsigned | Não | AUTO_INCREMENT | Identificador do exercício. |
| `nome` | varchar(100) | Não | Sem padrão | Nome usado no cadastro. |
| `regiao_corpo` | varchar(100) | Não | Sem padrão | Região corporal trabalhada pelo exercício. |
| `descricao` | text | Sim | NULL | Descrição livre opcional do catálogo. |

**Chaves e restrições**

- PK: (id_exercicio)
- Único: (nome)

## 13. aplicacao_exercicio

Exercício aplicado em sessão, com parâmetros de execução.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_tratamento` | int unsigned | Não | Sem padrão | Identificador do tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas. |
| `id_exercicio` | int unsigned | Não | Sem padrão | Identificador do exercício. |
| `series` | int unsigned | Não | Sem padrão | Quantidade positiva de séries. |
| `repeticoes` | int unsigned | Não | Sem padrão | Quantidade positiva de repetições por série. |
| `carga` | decimal(8,2) | Sim | NULL | Carga não negativa ou NULL. A unidade não está definida no esquema. |

**Chaves e restrições**

- PK: (id_tratamento,numero_sessao,id_exercicio)
- FK: (id_exercicio) -> exercicio (id_exercicio); exclusão RESTRICT; atualização CASCADE
- FK: (id_tratamento, numero_sessao) -> sessao (id_tratamento, numero_sessao); exclusão CASCADE; atualização CASCADE
- CHECK: (((carga is null) or (carga >= 0)))
- CHECK: ((repeticoes > 0))
- CHECK: ((series > 0))

Índices adicionais: (id_exercicio).

## 14. avaliacao_fisica

Histórico de avaliações por paciente e data.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_avaliacao` | int unsigned | Não | AUTO_INCREMENT | Identificador da avaliação. |
| `data_avaliacao` | date | Não | Sem padrão | Data da avaliação; única por paciente. |
| `nivel_dor` | tinyint unsigned | Não | Sem padrão | Inteiro de 0 a 10, conforme CHECK. |
| `amplitude_movimento` | varchar(100) | Sim | NULL | Descrição textual até 100 caracteres; unidade/padrão clínico não definido. |
| `observacoes` | text | Sim | NULL | Observações livres opcionais. |
| `id_paciente` | int unsigned | Não | Sem padrão | Identificador do paciente. |

**Chaves e restrições**

- PK: (id_avaliacao)
- Único: (id_paciente,data_avaliacao)
- FK: (id_paciente) -> paciente (id_paciente); exclusão CASCADE; atualização CASCADE
- CHECK: ((nivel_dor between 0 and 10))

Índices adicionais: (id_paciente,nivel_dor).

## 15. auditoria_evolucao

Registro técnico de alterações/exclusões de evolução; etapa 2.

| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |
| --- | --- | --- | --- | --- |
| `id_auditoria` | int unsigned | Não | AUTO_INCREMENT | Identificador do registro de auditoria. |
| `id_tratamento` | int unsigned | Não | Sem padrão | Identificador do tratamento. |
| `numero_sessao` | int unsigned | Não | Sem padrão | Número da sessão de origem, copiado pelo gatilho; sem FK ou CHECK nesta tabela. |
| `acao` | varchar(10) | Não | Sem padrão | Gatilhos registram UPDATE, DELETE ou DEL_CASC. VARCHAR sem CHECK de domínio. |
| `conduta_anterior` | text | Sim | NULL | Conduta antes da alteração/exclusão. |
| `conduta_nova` | text | Sim | NULL | Conduta após UPDATE; NULL na exclusão. |
| `resposta_anterior` | text | Sim | NULL | Resposta antes da alteração/exclusão. |
| `resposta_nova` | text | Sim | NULL | Resposta após UPDATE; NULL na exclusão. |
| `usuario_db` | varchar(288) | Não | Sem padrão | Usuário e host da conexão, obtidos por USER(). |
| `data_hora` | datetime | Não | Sem padrão | Data e horário da alteração ou exclusão; sem fuso armazenado. |

**Chaves e restrições**

- PK: (id_auditoria)

## View e gatilhos

A view vw_paciente_restrito expõe id, nome, nascimento e situação do paciente, com SQL SECURITY DEFINER. Não limita linhas por supervisor. A etapa 1 cria 11 gatilhos de integridade; a etapa 2 acrescenta quatro de auditoria. O relatório descreve suas funções e limites.

A auditoria não possui FK para a sessão, para manter os registros após a exclusão dos dados de origem. Na etapa 2, idx_avaliacao_dor substitui idx_avaliacao_paciente no suporte à FK; os procedimentos auxiliares de índices são removidos ao fim da execução.

Houve apoio de IA na organização e conferência deste documento.
