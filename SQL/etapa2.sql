USE clinica_fisioterapia;

-- ==========================================
-- 1. SEGURANÇA E PERFIS (B5)
-- ==========================================
CREATE ROLE 'Administrador', 'Fisioterapeuta', 'Estagiario';

GRANT ALL PRIVILEGES ON clinica_fisioterapia.* TO 'Administrador';

GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.* TO 'Fisioterapeuta';
REVOKE DELETE ON clinica_fisioterapia.paciente FROM 'Fisioterapeuta';

CREATE VIEW vw_paciente_restrito AS
SELECT id_paciente, nome, data_nascimento, situacao
FROM paciente;

GRANT SELECT ON clinica_fisioterapia.vw_paciente_restrito TO 'Estagiario';
GRANT SELECT ON clinica_fisioterapia.tratamento TO 'Estagiario';
GRANT SELECT, INSERT, UPDATE ON clinica_fisioterapia.evolucao TO 'Estagiario';

CREATE USER IF NOT EXISTS 'admin_user'@'localhost' IDENTIFIED BY 'senha_forte_123';
GRANT 'Administrador' TO 'admin_user'@'localhost';
SET DEFAULT ROLE 'Administrador' TO 'admin_user'@'localhost';

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
    usuario_db VARCHAR(50) NOT NULL,
    data_hora DATETIME NOT NULL
) ENGINE=InnoDB;

DELIMITER $$
CREATE TRIGGER trg_auditoria_evolucao_upd
AFTER UPDATE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'UPDATE', OLD.conduta_aplicada, NEW.conduta_aplicada, CURRENT_USER(), NOW()
    );
END$$

CREATE TRIGGER trg_auditoria_evolucao_del
AFTER DELETE ON evolucao
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_evolucao (
        id_tratamento, numero_sessao, acao, conduta_anterior, conduta_nova, usuario_db, data_hora
    ) VALUES (
        OLD.id_tratamento, OLD.numero_sessao, 'DELETE', OLD.conduta_aplicada, NULL, CURRENT_USER(), NOW()
    );
END$$
DELIMITER ;

-- ==========================================
-- 3. OTIMIZAÇÃO E ÍNDICES (B4)
-- ==========================================
CREATE INDEX idx_paciente_busca ON paciente (data_nascimento, id_convenio, telefone);
CREATE INDEX idx_sessao_situacao ON sessao (situacao, id_tratamento);
CREATE INDEX idx_avaliacao_dor ON avaliacao_fisica (id_paciente, nivel_dor);