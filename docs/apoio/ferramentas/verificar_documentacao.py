"""Confere cobertura do dicionário, evidências, links locais e escopo da revisão."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[3]
EVID=ROOT/'docs/apoio/evidencias.json'
evidence=json.loads(EVID.read_text(encoding='utf-8'))
BASE='02e1469'
checks=[]


def check(name, ok, detail=''):
    checks.append({'verificacao':name,'resultado':'PASSOU' if ok else 'FALHOU','detalhe':detail})


schema=evidence['catalogo']
text=(ROOT/'docs/fontes/dicionario-dados.md').read_text(encoding='utf-8')
documented={}
for part in re.split(r'^## \d+\. ',text,flags=re.M)[1:]:
    table,body=part.split('\n',1)
    documented[table]=re.findall(r'^\| `([^`]+)` \|',body,flags=re.M)
check('Todas as tabelas do catálogo estão no dicionário',set(documented)==set(schema),f'{len(schema)} tabelas')
for table,metadata in schema.items():
    expected=[c['COLUMN_NAME'] for c in metadata['colunas']]
    check('Colunas completas e em ordem: '+table,documented.get(table)==expected,f'{len(expected)} colunas')

broken=[]
for path in [ROOT/'README.md',*list((ROOT/'docs').rglob('*.md'))]:
    for label,target in re.findall(r'\[([^]]+)\]\(([^)]+)\)',path.read_text(encoding='utf-8')):
        if '://' in target or target.startswith('#'):continue
        target=target.split('#',1)[0]
        if not (path.parent/target).exists():broken.append(str(path.relative_to(ROOT))+': '+target)
check('Links locais resolvem',not broken,'; '.join(broken))

protected=['SQL/etapa01.sql','SQL/etapa02.sql','interface/ClinicaApp.java','docs/modelo-logico.pdf',
    'docs/escopo-regras-negocio.pdf','docs/mer-conceitual.drawio','docs/mer-conceitual.png']
for name in protected:
    original=subprocess.check_output(['git','rev-parse',BASE+':'+name],cwd=ROOT).strip()
    atual=subprocess.check_output(['git','hash-object','--path='+name,name],cwd=ROOT).strip()
    check('Arquivo de outro escopo preservado: '+name,atual==original,'Comparação dos objetos Git, respeitando conversão CRLF/LF do checkout')
report=evidence['validacao']
for name,expected_hash in report['arquivos_sha256'].items():
    check('Evidência corresponde ao SQL: '+name,hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected_hash)
check('Validação de banco aprovada e restauração registrada',report['resumo']['falharam']==0 and report['resumo']['passaram']==54 and bool(report['backup']))

for name in ('dicionario-dados','relatorio'):
    reader=PdfReader(ROOT/'docs'/(name+'.pdf'))
    texts=[p.extract_text() or '' for p in reader.pages]
    check('PDF tem texto legível: '+name,all(len(t.strip())>100 and '\ufffd' not in t and '\u25a0' not in t for t in texts),f'{len(texts)} páginas; inspeção visual complementar realizada separadamente')

result={'base_preservada':BASE,'verificacoes':checks,'resumo':{
    'passaram':sum(c['resultado']=='PASSOU' for c in checks),'falharam':sum(c['resultado']=='FALHOU' for c in checks)}}
evidence['verificacao-documental']=result
EVID.write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result['resumo'],ensure_ascii=False))
if result['resumo']['falharam']:
    for c in checks:
        if c['resultado']=='FALHOU':print(c)
    raise SystemExit(1)
