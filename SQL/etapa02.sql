USE clinica_fisioterapia;

-- Ordem de execução: DDL -> carga -> este script.
-- Requer MySQL 8.0.18+ (CREATE ROLE, IDENTIFIED BY RANDOM PASSWORD).

-- ==========================================
-- 1. SEGURANÇA E PERFIS (B5)
-- ==========================================
CREATE ROLE IF NOT EXISTS 'Administrador', 'Fisioterapeuta', 'Estagiario';

GRANT ALL PRIVILEGES ON clinica_fisioterapia.* TO 'Administrador';

-- Menor privilégio: fisioterapeuta consulta os cadastros necessários e altera
-- apenas os dados operacionais do atendimento; não recebe DELETE geral.
GRANT SELECT ON clinica_fisioterapia.convenio TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.paciente TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.profissional TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.fisioterapeuta TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.especialidade TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.habilitacao_profissional TO 'Fisioterapeuta';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.tratamento TO 'Fisioterapeuta';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.sessao TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.sala TO 'Fisioterapeuta';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.evolucao TO 'Fisioterapeuta';
GRANT SELECT ON clinica_fisioterapia.exercicio TO 'Fisioterapeuta';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.aplicacao_exercicio TO 'Fisioterapeuta';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.avaliacao_fisica TO 'Fisioterapeuta';

-- A view roda com os privilégios de quem a criou (SQL SECURITY DEFINER, padrão),
-- então o estagiário enxerga apenas estas colunas, sem CPF, telefone ou convênio.
CREATE OR REPLACE VIEW vw_paciente_restrito AS
SELECT id_paciente, nome, data_nascimento, situacao
FROM paciente;

GRANT SELECT ON clinica_fisioterapia.vw_paciente_restrito TO 'Estagiario';
GRANT SELECT ON clinica_fisioterapia.tratamento TO 'Estagiario';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.evolucao TO 'Estagiario';

-- Cria contas de demonstração com senhas aleatórias geradas pelo MySQL;
-- o servidor mostra as senhas geradas na saída do comando. Não as coloque no Git.
CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
CREATE USER IF NOT EXISTS 'fisioterapeuta_user'@'localhost' IDENTIFIED BY RANDOM PASSWORD;
CREATE USER IF NOT EXISTS 'estagiario_user'@'localhost' IDENTIFIED BY RANDOM PASSWORD;

GRANT 'Administrador' TO 'admin_user'@'localhost';
GRANT 'Fisioterapeuta' TO 'fisioterapeuta_user'@'localhost';
GRANT 'Estagiario' TO 'estagiario_user'@'localhost';
SET DEFAULT ROLE 'Administrador' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Fisioterapeuta' TO 'fisioterapeuta_user'@'localhost';
SET DEFAULT ROLE 'Estagiario' TO 'estagiario_user'@'localhost';

-- ==========================================
-- 2. GATILHOS E AUDITORIA (B6)
-- ==========================================
-- usuario_db guarda USER() (usuario@host): até 32 + 1 + 255 caracteres.
-- Com VARCHAR(50), um host longo estouraria a coluna e o gatilho faria
-- o UPDATE/DELETE da evolução falhar.
CREATE TABLE IF NOT EXISTS auditoria_evolucao (
    id_auditoria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_tratamento INT UNSIGNED NOT NULL,
    numero_sessao INT UNSIGNED NOT NULL,
    acao VARCHAR(10) NOT NULL,
    conduta_anterior TEXT,
    conduta_nova TEXT,
    resposta_anterior TEXT,
    resposta_nova TEXT,
    usuario_db VARCHAR(288) NOT NULL,
    data_hora DATETIME NOT NULL
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_auditoria_evolucao_upd;
DROP TRIGGER IF EXISTS trg_auditoria_evolucao_del;
DROP TRIGGER IF EXISTS trg_auditoria_evolucao_del_sessao;
DROP TRIGGER IF EXISTS trg_auditoria_evolucao_del_tratamento;
DELIMITER $$

-- USER() devolve quem está conectado. CURRENT_USER() dentro de gatilho devolve
-- o DEFINER (quem criou o gatilho), então o log registraria sempre o mesmo usuário.
CREATE TRIGGER trg_auditoria_evolucao_upd
AFTER UPDATE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'UPDATE', OLD.conduta_aplicada, NEW.conduta_aplicada, OLD.resposta_observada, NEW.resposta_observada, USER(), NOW()
    );
END$$

CREATE TRIGGER trg_auditoria_evolucao_del
AFTER DELETE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'DELETE', OLD.conduta_aplicada, NULL, OLD.resposta_observada, NULL, USER(), NOW()
    );
END$$

-- Exclusões em cascata (ON DELETE CASCADE) NÃO disparam gatilhos no MySQL.
-- Sem os dois gatilhos abaixo, apagar uma sessão ou um tratamento removeria
-- as evoluções sem deixar rastro na auditoria.
CREATE TRIGGER trg_auditoria_evolucao_del_sessao
BEFORE DELETE ON sessao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    )
    SELECT e.id_tratamento, e.numero_sessao, 'DEL_CASC', e.conduta_aplicada, NULL, e.resposta_observada, NULL, USER(), NOW()
    FROM evolucao e
    WHERE e.id_tratamento = OLD.id_tratamento
      AND e.numero_sessao = OLD.numero_sessao;
END$$

CREATE TRIGGER trg_auditoria_evolucao_del_tratamento
BEFORE DELETE ON tratamento
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    )
    SELECT e.id_tratamento, e.numero_sessao, 'DEL_CASC', e.conduta_aplicada, NULL, e.resposta_observada, NULL, USER(), NOW()
    FROM evolucao e
    WHERE e.id_tratamento = OLD.id_tratamento;
END$$
DELIMITER ;

-- ==========================================
-- 3. OTIMIZAÇÃO E ÍNDICES (B4)
-- ==========================================
-- O MySQL não tem CREATE INDEX IF NOT EXISTS nem DROP INDEX IF EXISTS.
-- Os dois procedimentos auxiliares abaixo verificam o catálogo antes de agir,
-- para que este script possa ser executado mais de uma vez sem erro 1061/1091.
DROP PROCEDURE IF EXISTS sp_criar_indice_se_nao_existe;
DROP PROCEDURE IF EXISTS sp_remover_indice_se_existe;
DELIMITER $$

CREATE PROCEDURE sp_criar_indice_se_nao_existe(
    IN p_tabela VARCHAR(64), IN p_indice VARCHAR(64), IN p_colunas VARCHAR(255))
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = p_tabela AND index_name = p_indice
    ) THEN
        SET @ddl = CONCAT('CREATE INDEX ', p_indice, ' ON ', p_tabela, ' (', p_colunas, ')');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

CREATE PROCEDURE sp_remover_indice_se_existe(
    IN p_tabela VARCHAR(64), IN p_indice VARCHAR(64))
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = p_tabela AND index_name = p_indice
    ) THEN
        SET @ddl = CONCAT('DROP INDEX ', p_indice, ' ON ', p_tabela);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

-- Atende a consulta 5 (faixa de nascimento, convênio e telefone).
CALL sp_criar_indice_se_nao_existe('paciente', 'idx_paciente_busca', 'data_nascimento, id_convenio, telefone');
-- Atende as consultas 10 e 14 (filtro por situação da sessão e junção por tratamento).
CALL sp_criar_indice_se_nao_existe('sessao', 'idx_sessao_situacao', 'situacao, id_tratamento');
-- Atende as consultas 11 e 14 (avaliações por paciente e nível de dor).
CALL sp_criar_indice_se_nao_existe('avaliacao_fisica', 'idx_avaliacao_dor', 'id_paciente, nivel_dor');

-- idx_avaliacao_paciente (id_paciente), criado no DDL, passou a ser redundante:
-- idx_avaliacao_dor já começa por id_paciente e a FK continua atendida.
CALL sp_remover_indice_se_existe('avaliacao_fisica', 'idx_avaliacao_paciente');

DROP PROCEDURE sp_criar_indice_se_nao_existe;
DROP PROCEDURE sp_remover_indice_se_existe;