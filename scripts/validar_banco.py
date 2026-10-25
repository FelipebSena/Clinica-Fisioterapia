"""Validação reproduzível em servidor MySQL DESCARTÁVEL; nunca usar em produção.

MYSQL_HOST/PORT/USER/PASSWORD configuram a conexão. A opção de confirmação é
obrigatória porque etapa01.sql apaga clinica_fisioterapia. Não exporta senhas.
"""
import argparse
import hashlib
import json
import os
import re
import secrets
import subprocess
import statistics
import time
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo
import pymysql
from db_common import ROOT, connect, execute_script

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--confirmar-base-descartavel', action='store_true')
args = parser.parse_args()
if not args.confirmar_base_descartavel:
    parser.error('Use somente em servidor descartável e informe --confirmar-base-descartavel.')

out = ROOT / 'docs/evidencias'
out.mkdir(parents=True, exist_ok=True)
results = []
c = connect()


def rows(sql, params=None):
    with c.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def scalar(sql, params=None):
    return rows(sql, params)[0][0]


def check(name, condition, detail=''):
    results.append({'teste': name, 'resultado': 'PASSOU' if condition else 'FALHOU', 'detalhe': str(detail)})
    if not condition:
        raise AssertionError(name + ': ' + str(detail))


def reject(name, sql, expected):
    c.begin()
    try:
        rows(sql)
    except pymysql.MySQLError as ex:
        check(name, ex.args[0] in expected, 'código MySQL ' + str(ex.args[0]))
    else:
        check(name, False, 'operação inválida aceita')
    finally:
        c.rollback()


def transaction_test(name, operation):
    c.begin()
    try:
        operation()
        check(name, True)
    finally:
        c.rollback()


def snapshot():
    return {t[0]: {'linhas': scalar('SELECT COUNT(*) FROM `' + t[0] + '`'),
        'sha256_dados': hashlib.sha256(json.dumps(sorted(
            rows('SELECT * FROM `' + t[0] + '`'), key=repr), default=str,
            ensure_ascii=False).encode()).hexdigest()}
        for t in rows("SHOW FULL TABLES WHERE Table_type='BASE TABLE'")}


source = (ROOT / 'SQL/etapa01.sql').read_text(encoding='utf-8')
queries = {}
for n in (5, 10, 14):
    section = source.split('-- ' + str(n) + '. ')[1].split(';', 1)[0]
    queries[str(n)] = section[section.index('SELECT'):].strip()


def plans():
    rows('ANALYZE TABLE paciente, convenio, tratamento, sessao, avaliacao_fisica')
    data = {}
    for n, sql in queries.items():
        result = rows(sql)  # aquecimento; mesmos dados nos dois cenários
        timings = []
        for _ in range(15):
            start = time.perf_counter()
            rows(sql)
            timings.append((time.perf_counter()-start)*1000)
        data[n] = {'sql': sql, 'explain': json.loads(scalar('EXPLAIN FORMAT=JSON ' + sql)),
            'analyze': '\n'.join(str(r[0]) for r in rows('EXPLAIN ANALYZE ' + sql)),
            'linhas_resultado': len(result),
            'sha256_resultado': hashlib.sha256(json.dumps(result,default=str,ensure_ascii=False).encode()).hexdigest(),
            'tempos_cliente_ms': timings, 'mediana_cliente_ms': statistics.median(timings)}
    return data


try:
    version = scalar('SELECT VERSION()')
    check('Servidor MySQL 8 (não MariaDB)', version.startswith('8.') and 'MariaDB' not in version, version)
    n = execute_script(c, ROOT / 'SQL/etapa01.sql')
    check('Etapa 1: criação, carga e 15 consultas', n == 69, f'{n} instruções sem erro')
    c.select_db('clinica_fisioterapia')
    before = plans()
    n = execute_script(c, ROOT / 'SQL/etapa02.sql')
    check('Etapa 2: perfis, views, auditoria e índices', n > 0, f'{n} instruções sem erro')
    after = plans()
    for n in queries:
        check('Consulta '+n+': mesmo resultado antes/depois dos índices', before[n]['sha256_resultado'] == after[n]['sha256_resultado'])
    initial = snapshot()
    execute_script(c, ROOT / 'SQL/etapa02.sql')
    check('Reexecução da etapa 2 preserva dados', snapshot() == initial)
    check('14 tabelas de domínio e 1 de auditoria', len(initial) == 15, len(initial))

    reject('RN01: CPF de paciente duplicado', "INSERT INTO paciente(cpf,nome,data_nascimento) SELECT cpf,'Teste','1990-01-01' FROM paciente LIMIT 1", {1062})
    reject('RN02: nascimento futuro INSERT', "INSERT INTO paciente(cpf,nome,data_nascimento) VALUES('99999999999','Teste',CURRENT_DATE+INTERVAL 1 DAY)", {1644})
    reject('RN02: nascimento futuro UPDATE', "UPDATE paciente SET data_nascimento=CURRENT_DATE+INTERVAL 1 DAY WHERE id_paciente=1", {1644})
    reject('RN04: situação inválida', "UPDATE paciente SET situacao='INVALIDA' WHERE id_paciente=1", {1265})
    reject('RN05: subtipos exclusivos', "INSERT INTO estagiario VALUES(1,'Instituição teste',2)", {1644})
    reject('RN06: CREFITO único', "UPDATE fisioterapeuta SET crefito=(SELECT x.crefito FROM (SELECT crefito FROM fisioterapeuta WHERE id_profissional=1) x) WHERE id_profissional=2", {1062})
    reject('RN07: supervisor inexistente', "UPDATE estagiario SET id_supervisor=999999 WHERE id_profissional=(SELECT id FROM (SELECT MIN(id_profissional) id FROM estagiario) x)", {1452})
    reject('RN09: habilitação duplicada', "INSERT INTO habilitacao_profissional SELECT * FROM habilitacao_profissional LIMIT 1", {1062})
    reject('RN10: tratamento sem paciente válido', "UPDATE tratamento SET id_paciente=999999 WHERE id_tratamento=1", {1452})
    reject('RN12: alta anterior ao início', "UPDATE tratamento SET data_alta=data_inicio-INTERVAL 1 DAY WHERE id_tratamento=1", {3819})
    reject('RN13: dois tratamentos abertos na mesma especialidade', "INSERT INTO tratamento(descricao_condicao,data_inicio,id_paciente,id_fisioterapeuta,id_especialidade) SELECT descricao_condicao,data_inicio,id_paciente,id_fisioterapeuta,id_especialidade FROM tratamento WHERE data_alta IS NULL LIMIT 1", {1062})
    reject('RN14: excluir paciente com tratamento', "DELETE FROM paciente WHERE id_paciente=(SELECT id_paciente FROM tratamento LIMIT 1)", {1451})
    reject('RN15: sessão duplicada', "INSERT INTO sessao SELECT * FROM sessao LIMIT 1", {1062})
    reject('RN15: número de sessão zero', "INSERT INTO sessao VALUES(1,0,'2026-01-01 01:00:00','REALIZADA',1)", {3819})
    reject('RN17: sala e horário duplicados', "INSERT INTO sessao SELECT id_tratamento,999999,data_hora,situacao,id_sala FROM sessao LIMIT 1", {1062})
    reject('RN18: situação de sessão inválida', "INSERT INTO sessao VALUES(1,999999,'2026-01-01 01:00:00','INVALIDA',1)", {1265})
    reject('RN19: evolução em sessão não realizada', "INSERT INTO evolucao SELECT id_tratamento,numero_sessao,'Teste','Teste' FROM sessao WHERE situacao<>'REALIZADA' LIMIT 1", {1644})
    reject('RN19: sessão com evolução deixa de ser realizada', "UPDATE sessao s JOIN evolucao e USING(id_tratamento,numero_sessao) SET s.situacao='CANCELADA' WHERE s.id_tratamento=1", {1644})
    reject('RN21: carga negativa', "UPDATE aplicacao_exercicio SET carga=-1 LIMIT 1", {3819})
    reject('Séries positivas', "UPDATE aplicacao_exercicio SET series=0 LIMIT 1", {3819})
    reject('Repetições positivas', "UPDATE aplicacao_exercicio SET repeticoes=0 LIMIT 1", {3819})
    reject('RN22: avaliação duplicada por paciente e data', "INSERT INTO avaliacao_fisica(data_avaliacao,nivel_dor,id_paciente) SELECT data_avaliacao,nivel_dor,id_paciente FROM avaliacao_fisica LIMIT 1", {1062})
    reject('RN23: dor acima de 10', "UPDATE avaliacao_fisica SET nivel_dor=11 LIMIT 1", {3819})
    reject('RN24: nome de convênio duplicado', "INSERT INTO convenio(nome) SELECT nome FROM convenio LIMIT 1", {1062})
    reject('RN25: capacidade zero', "UPDATE sala SET capacidade=0 LIMIT 1", {3819})
    reject('RN26: nome de exercício duplicado', "INSERT INTO exercicio(nome,regiao_corpo) SELECT nome,regiao_corpo FROM exercicio LIMIT 1", {1062})
    check('Carga: todo profissional tem exatamente um subtipo', scalar('SELECT COUNT(*) FROM profissional p LEFT JOIN fisioterapeuta f USING(id_profissional) LEFT JOIN estagiario e USING(id_profissional) WHERE (f.id_profissional IS NOT NULL)+(e.id_profissional IS NOT NULL)<>1') == 0)
    check('Carga: fisioterapeutas habilitados no tratamento', scalar('SELECT COUNT(*) FROM tratamento t LEFT JOIN habilitacao_profissional h ON h.id_profissional=t.id_fisioterapeuta AND h.id_especialidade=t.id_especialidade WHERE h.id_profissional IS NULL') == 0)
    check('Carga: sessões dentro do período do tratamento', scalar('SELECT COUNT(*) FROM sessao s JOIN tratamento t USING(id_tratamento) WHERE DATE(s.data_hora)<t.data_inicio OR (t.data_alta IS NOT NULL AND DATE(s.data_hora)>t.data_alta)') == 0)
    check('View restrita não expõe CPF/telefone/convênio', set(r[0] for r in rows('SHOW COLUMNS FROM vw_paciente_restrito')) == {'id_paciente','nome','data_nascimento','situacao'})

    def audit_update():
        old = rows('SELECT id_tratamento,numero_sessao,conduta_aplicada FROM evolucao LIMIT 1')[0]
        rows("UPDATE evolucao SET conduta_aplicada='Teste de auditoria' WHERE id_tratamento=%s AND numero_sessao=%s", old[:2])
        log = rows('SELECT acao,conduta_anterior,conduta_nova,usuario_db FROM auditoria_evolucao ORDER BY id_auditoria DESC LIMIT 1')[0]
        assert log == ('UPDATE', old[2], 'Teste de auditoria', scalar('SELECT USER()'))
    transaction_test('Auditoria UPDATE: antes/depois e usuário conectado', audit_update)

    for target in ('evolucao','sessao','tratamento'):
        def audit_delete(target=target):
            key = rows('SELECT id_tratamento,numero_sessao FROM evolucao LIMIT 1')[0]
            expected = scalar('SELECT COUNT(*) FROM evolucao WHERE id_tratamento=%s', (key[0],)) if target == 'tratamento' else 1
            sql = 'DELETE FROM ' + target + ' WHERE id_tratamento=%s'
            params = (key[0],)
            if target != 'tratamento': sql += ' AND numero_sessao=%s'; params = key
            rows(sql, params)
            action = 'DELETE' if target == 'evolucao' else 'DEL_CASC'
            assert scalar('SELECT COUNT(*) FROM auditoria_evolucao WHERE acao=%s', (action,)) == expected
        transaction_test('Auditoria exclusão via ' + target, audit_delete)

    # Senhas de teste apenas no servidor descartável e em memória.
    for user, role in [('admin_user','Administrador'),('fisioterapeuta_user','Fisioterapeuta'),('estagiario_user','Estagiario')]:
        password = secrets.token_urlsafe(24)
        rows('ALTER USER %s@\'localhost\' IDENTIFIED BY %s', (user, password))
        with connect('clinica_fisioterapia', user, password) as profile:
            with profile.cursor() as cur:
                cur.execute('SELECT CURRENT_ROLE()')
                check('Perfil ativo: ' + role, role in cur.fetchone()[0])
                if role == 'Estagiario':
                    cur.execute('SELECT * FROM vw_paciente_restrito LIMIT 1')
                    check('Estagiário consulta view restrita', cur.fetchone() is not None)
                    try: cur.execute('SELECT cpf FROM paciente LIMIT 1')
                    except pymysql.MySQLError as ex: check('Estagiário não lê tabela paciente', ex.args[0] in (1142,1143))
                    else: check('Estagiário não lê tabela paciente', False)
                if role == 'Fisioterapeuta':
                    cur.execute('SELECT * FROM paciente LIMIT 1')
                    check('Fisioterapeuta consulta pacientes', cur.fetchone() is not None)
                    try: cur.execute('DELETE FROM paciente WHERE id_paciente=0')
                    except pymysql.MySQLError as ex: check('Fisioterapeuta não exclui paciente', ex.args[0] == 1142)
                    else: check('Fisioterapeuta não exclui paciente', False)

    check('Testes transacionais preservam dados', snapshot() == initial)
    schema = {}
    with c.cursor(pymysql.cursors.DictCursor) as cur:
        for table in initial:
            cur.execute('SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COLUMN_DEFAULT,COLUMN_KEY,EXTRA,GENERATION_EXPRESSION FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s ORDER BY ORDINAL_POSITION', (table,))
            columns = cur.fetchall()
            cur.execute('SHOW CREATE TABLE `' + table + '`')
            ddl = cur.fetchone()['Create Table']
            schema[table] = {'colunas': columns, 'ddl': ddl}
    (out/'catalogo.json').write_text(json.dumps(schema, ensure_ascii=False, indent=2, default=str)+'\n', encoding='utf-8')
    (out/'explain.json').write_text(json.dumps({'antes': before, 'depois': after}, ensure_ascii=False, indent=2, default=str)+'\n', encoding='utf-8')
    (out/'carga.json').write_text(json.dumps(initial, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

    # Round-trip real de dump, incluindo views e gatilhos, na mesma base descartável.
    mysql_bin = Path(os.environ.get('MYSQL_BIN', ''))
    dump_exe = str(mysql_bin/'mysqldump') if mysql_bin.name else 'mysqldump'
    mysql_exe = str(mysql_bin/'mysql') if mysql_bin.name else 'mysql'
    auth = ['--no-defaults', '--host='+os.environ.get('MYSQL_HOST','127.0.0.1'), '--port='+os.environ.get('MYSQL_PORT','3306'), '--user='+os.environ.get('MYSQL_USER','root')]
    private = ROOT/'.review'; private.mkdir(exist_ok=True)
    dump = private/'restauracao-teste.sql'
    env = os.environ.copy(); env['MYSQL_PWD'] = os.environ.get('MYSQL_PASSWORD','')
    started = datetime.now()
    subprocess.run([dump_exe, *auth, '--single-transaction', '--routines', '--triggers', '--events', '--no-tablespaces', '--set-gtid-purged=OFF', '--add-drop-database', '--databases', 'clinica_fisioterapia', '--result-file='+str(dump)], env=env, check=True, capture_output=True)
    backup_seconds = (datetime.now()-started).total_seconds()
    started = datetime.now()
    with dump.open('rb') as stream:
        subprocess.run([mysql_exe, *auth, '--default-character-set=utf8mb4'], stdin=stream, env=env, check=True, capture_output=True)
    restore_seconds = (datetime.now()-started).total_seconds()
    check('Backup/restauração: contagem e SHA-256 de todas as tabelas', snapshot() == initial)
    check('Backup/restauração: view restrita', scalar("SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE()") == 1)
    check('Backup/restauração: 15 gatilhos', scalar("SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE()") == 15)
    transaction_test('Backup/restauração: gatilho de auditoria funciona', audit_update)
    backup = {'ferramenta': 'mysqldump', 'tipo': 'lógico completo', 'bytes': dump.stat().st_size,
        'sha256': hashlib.sha256(dump.read_bytes()).hexdigest(), 'segundos_backup': backup_seconds,
        'segundos_restauracao': restore_seconds, 'escopo': 'base acadêmica pequena em servidor local descartável; não é RTO de produção'}
finally:
    report = {'data': datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat(),
        'mysql': locals().get('version'), 'sql_mode': scalar('SELECT @@sql_mode'),
        'arquivos_sha256': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'SQL').glob('etapa*.sql')},
        'testes': results, 'backup': locals().get('backup'),
        'resumo': {'passaram': sum(r['resultado']=='PASSOU' for r in results), 'falharam': sum(r['resultado']=='FALHOU' for r in results)}}
    (out/'validacao.json').write_text(json.dumps(report, ensure_ascii=False, indent=2, default=str)+'\n', encoding='utf-8')
    c.close()
    print(json.dumps(report['resumo'], ensure_ascii=False))
