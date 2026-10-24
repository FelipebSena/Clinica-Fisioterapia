-- ============================================================
-- 03_consultas.sql
-- A8 — Consultas de verificação
-- 15 consultas comentadas com a pergunta de negócio.
-- ============================================================

USE clinica_fisioterapia;

-- ============================================================
-- 1. BÁSICA — Projeção
-- Pergunta: Quais são os nomes e situações cadastrais dos pacientes?
-- ============================================================
SELECT nome, situacao
FROM paciente;

-- ============================================================
-- 2. BÁSICA — WHERE
-- Pergunta: Quais pacientes estão atualmente ativos?
-- ============================================================
SELECT id_paciente, nome, cpf
FROM paciente
WHERE situacao = 'ATIVO';

-- ============================================================
-- 3. BÁSICA — ORDER BY
-- Pergunta: Quais pacientes estão em ordem alfabética?
-- ============================================================
SELECT id_paciente, nome
FROM paciente
ORDER BY nome ASC;

-- ============================================================
-- 4. BÁSICA — LIKE
-- Pergunta: Quais pacientes possuem "Ana" no nome?
-- ============================================================
SELECT id_paciente, nome
FROM paciente
WHERE nome LIKE '%Ana%';

-- ============================================================
-- 5. BÁSICA — BETWEEN / IN / NULL
-- Pergunta: Quais pacientes nasceram entre 1985 e 1995 e não possuem telefone informado?
-- ============================================================
SELECT id_paciente, nome, data_nascimento, telefone
FROM paciente
WHERE data_nascimento BETWEEN '1985-01-01' AND '1995-12-31'
  AND id_convenio IN (1, 2, 3, 4)
  AND telefone IS NULL;

-- ============================================================
-- 6. JUNÇÃO — três tabelas
-- Pergunta: Quais tratamentos estão vinculados a quais pacientes,
-- fisioterapeutas e especialidades?
-- ============================================================
SELECT
    t.id_tratamento,
    p.nome AS paciente,
    f.nome AS fisioterapeuta,
    e.nome AS especialidade,
    t.data_inicio
FROM tratamento t
JOIN paciente p ON p.id_paciente = t.id_paciente
JOIN fisioterapeuta ft ON ft.id_profissional = t.id_fisioterapeuta
JOIN profissional f ON f.id_profissional = ft.id_profissional
JOIN especialidade e ON e.id_especialidade = t.id_especialidade
ORDER BY t.id_tratamento;

-- ============================================================
-- 7. JUNÇÃO — LEFT JOIN
-- Pergunta: Quais pacientes possuem ou não avaliações físicas?
-- ============================================================
SELECT
    p.id_paciente,
    p.nome,
    a.data_avaliacao,
    a.nivel_dor
FROM paciente p
LEFT JOIN avaliacao_fisica a ON a.id_paciente = p.id_paciente
ORDER BY p.id_paciente, a.data_avaliacao;

-- ============================================================
-- 8. AGREGAÇÃO — GROUP BY
-- Pergunta: Quantos tratamentos cada especialidade possui?
-- ============================================================
SELECT
    e.nome AS especialidade,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM especialidade e
LEFT JOIN tratamento t ON t.id_especialidade = e.id_especialidade
GROUP BY e.id_especialidade, e.nome
ORDER BY quantidade_tratamentos DESC;

-- ============================================================
-- 9. AGREGAÇÃO — HAVING
-- Pergunta: Quais especialidades possuem pelo menos 5 tratamentos?
-- ============================================================
SELECT
    e.nome AS especialidade,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM especialidade e
JOIN tratamento t ON t.id_especialidade = e.id_especialidade
GROUP BY e.id_especialidade, e.nome
HAVING COUNT(t.id_tratamento) >= 5
ORDER BY quantidade_tratamentos DESC;

-- ============================================================
-- 10. JUNÇÃO + AGREGAÇÃO
-- Pergunta: Quantas sessões realizadas cada paciente possui?
-- ============================================================
SELECT
    p.nome AS paciente,
    COUNT(s.numero_sessao) AS sessoes_realizadas
FROM paciente p
JOIN tratamento t ON t.id_paciente = p.id_paciente
JOIN sessao s ON s.id_tratamento = t.id_tratamento
WHERE s.situacao = 'REALIZADA'
GROUP BY p.id_paciente, p.nome
ORDER BY sessoes_realizadas DESC, paciente;

-- ============================================================
-- 11. AVANÇADA — subconsulta correlacionada
-- Pergunta: Quais pacientes possuem uma avaliação cuja dor é maior
-- que a média das avaliações daquele mesmo paciente?
-- ============================================================
SELECT
    a.id_paciente,
    p.nome,
    a.data_avaliacao,
    a.nivel_dor
FROM avaliacao_fisica a
JOIN paciente p ON p.id_paciente = a.id_paciente
WHERE a.nivel_dor > (
    SELECT AVG(a2.nivel_dor)
    FROM avaliacao_fisica a2
    WHERE a2.id_paciente = a.id_paciente
)
ORDER BY p.nome, a.data_avaliacao;

-- ============================================================
-- 12. AVANÇADA — EXISTS
-- Pergunta: Quais fisioterapeutas possuem pelo menos uma habilitação
-- registrada em especialidade?
-- ============================================================
SELECT
    f.id_profissional,
    p.nome,
    f.crefito
FROM fisioterapeuta f
JOIN profissional p ON p.id_profissional = f.id_profissional
WHERE EXISTS (
    SELECT 1
    FROM habilitacao_profissional h
    WHERE h.id_profissional = f.id_profissional
)
ORDER BY p.nome;

-- ============================================================
-- 13. AVANÇADA — NOT EXISTS
-- Pergunta: Quais exercícios ainda não foram aplicados em nenhuma sessão?
-- ============================================================
SELECT
    e.id_exercicio,
    e.nome
FROM exercicio e
WHERE NOT EXISTS (
    SELECT 1
    FROM aplicacao_exercicio ae
    WHERE ae.id_exercicio = e.id_exercicio
)
ORDER BY e.nome;

-- ============================================================
-- 14. AVANÇADA — pergunta não trivial
-- Pergunta: Quais pacientes tiveram pelo menos uma sessão realizada
-- e possuem média de dor nas avaliações igual ou superior a 6?
-- ============================================================
SELECT
    p.id_paciente,
    p.nome,
    AVG(a.nivel_dor) AS media_dor
FROM paciente p
JOIN avaliacao_fisica a ON a.id_paciente = p.id_paciente
WHERE EXISTS (
    SELECT 1
    FROM tratamento t
    JOIN sessao s ON s.id_tratamento = t.id_tratamento
    WHERE t.id_paciente = p.id_paciente
      AND s.situacao = 'REALIZADA'
)
GROUP BY p.id_paciente, p.nome
HAVING AVG(a.nivel_dor) >= 6
ORDER BY media_dor DESC;

-- ============================================================
-- 15. AVANÇADA — pergunta não trivial
-- Pergunta: Quais fisioterapeutas possuem mais tratamentos do que
-- a média de tratamentos por fisioterapeuta?
-- ============================================================
SELECT
    p.nome AS fisioterapeuta,
    COUNT(t.id_tratamento) AS quantidade_tratamentos
FROM fisioterapeuta f
JOIN profissional p ON p.id_profissional = f.id_profissional
JOIN tratamento t ON t.id_fisioterapeuta = f.id_profissional
GROUP BY f.id_profissional, p.nome
HAVING COUNT(t.id_tratamento) > (
    SELECT AVG(qtd)
    FROM (
        SELECT COUNT(*) AS qtd
        FROM tratamento
        GROUP BY id_fisioterapeuta
    ) AS medias
)
ORDER BY quantidade_tratamentos DESC;
