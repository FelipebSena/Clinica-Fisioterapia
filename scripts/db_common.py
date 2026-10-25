"""Conexão e leitura dos scripts MySQL do projeto (incluindo DELIMITER)."""
import os
from pathlib import Path
import pymysql

ROOT = Path(__file__).resolve().parents[1]


def connect(database=None, user=None, password=None):
    return pymysql.connect(
        host=os.environ.get('MYSQL_HOST', '127.0.0.1'),
        port=int(os.environ.get('MYSQL_PORT', '3306')),
        user=user or os.environ.get('MYSQL_USER', 'root'),
        password=os.environ.get('MYSQL_PASSWORD', '') if password is None else password,
        database=database, charset='utf8mb4', autocommit=True,
    )


def statements(path):
    delimiter, pending = ';', []
    for line in Path(path).read_text(encoding='utf-8-sig').splitlines():
        if line.strip().upper().startswith('DELIMITER '):
            if pending:
                raise ValueError('DELIMITER dentro de instrução incompleta')
            delimiter = line.strip().split()[1]
        elif line.strip() and not line.lstrip().startswith('--'):
            pending.append(line)
            if line.rstrip().endswith(delimiter):
                yield '\n'.join(pending).rstrip()[:-len(delimiter)]
                pending = []
    if pending:
        raise ValueError('Instrução SQL sem terminador')


def execute_script(connection, path):
    count = 0
    with connection.cursor() as cursor:
        for sql in statements(path):
            cursor.execute(sql)
            # CREATE USER retorna senha aleatória: nunca persistir esse result set.
            while cursor.nextset():
                pass
            count += 1
    return count
