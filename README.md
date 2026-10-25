# Clínica de Fisioterapia

Projeto de Laboratório de Banco de Dados - 2026/2.

Equipe: David Fernandes dos Santos, Felipe Romero, Caio e Felipe Sena.

## Documentação

A parte de David está em [docs](docs/):

- [Relatório do projeto](docs/relatorio.pdf): etapas 1 e 2, testes, decisões, backup e crescimento.
- [Dicionário de dados](docs/dicionario-dados.pdf): colunas, tipos, chaves e restrições.

As fontes editáveis e os registros dos testes estão nas pastas de apoio dentro de `docs`.

## Banco de dados

MySQL 8.0.18 ou superior na linha 8.x. Execute, nesta ordem:

```sql
SOURCE SQL/etapa01.sql;
SOURCE SQL/etapa02.sql;
```

**A etapa 1 apaga e recria o banco clinica_fisioterapia. Use apenas dados descartáveis.**

A primeira etapa reúne estrutura, carga fictícia e 15 consultas. A segunda acrescenta perfis de acesso, view restrita, auditoria e índices. Guarde as senhas geradas fora do repositório.

## Pastas

- `SQL/`: scripts das duas etapas.
- `interface/`: aplicação Java.
- `docs/`: documentação, modelos e recursos de validação.

Os arquivos SQL, a aplicação e os modelos originais foram preservados. A situação da integração com a interface está descrita no relatório.
