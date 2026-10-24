USE clinica_fisioterapia;

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
CREATE TABLE IF NOT EXISTS auditoria_evolucao (
    id_auditoria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_tratamento INT UNSIGNED NOT NULL,
    numero_sessao INT UNSIGNED NOT NULL,
    acao VARCHAR(10) NOT NULL,
    conduta_anterior TEXT,
    conduta_nova TEXT,
    resposta_anterior TEXT,
    resposta_nova TEXT,
    usuario_db VARCHAR(50) NOT NULL,
    data_hora DATETIME NOT NULL
) ENGINE=InnoDB;

DROP TRIGGER IF EXISTS trg_auditoria_evolucao_upd;
DROP TRIGGER IF EXISTS trg_auditoria_evolucao_del;
DELIMITER $$
CREATE TRIGGER trg_auditoria_evolucao_upd
AFTER UPDATE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'UPDATE', OLD.conduta_aplicada, NEW.conduta_aplicada, OLD.resposta_observada, NEW.resposta_observada, CURRENT_USER(), NOW()
    );
END$$

CREATE TRIGGER trg_auditoria_evolucao_del
AFTER DELETE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, resposta_anterior, resposta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'DELETE', OLD.conduta_aplicada, NULL, OLD.resposta_observada, NULL, CURRENT_USER(), NOW()
    );
END$$
DELIMITER ;

-- ==========================================
-- 3. OTIMIZAÇÃO E ÍNDICES (B4)
-- ==========================================
CREATE INDEX idx_paciente_busca ON paciente (data_nascimento, id_convenio, telefone);
CREATE INDEX idx_sessao_situacao ON sessao (situacao, id_tratamento);
CREATE INDEX idx_avaliacao_dor ON avaliacao_fisica (id_paciente, nivel_dor);