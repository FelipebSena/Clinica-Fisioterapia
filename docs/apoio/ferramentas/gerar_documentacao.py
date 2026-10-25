"""Gera documentação a partir das evidências, sem conectar ou alterar o banco."""
import html
import json
import re
import textwrap
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, LongTable, TableStyle, Preformatted, KeepTogether

ROOT = Path(__file__).resolve().parents[3]
DOCS = ROOT/'docs'
EVID = DOCS/'apoio/evidencias.json'
FONTES = DOCS/'fontes'


def read_json(name):
    return json.loads(EVID.read_text(encoding='utf-8'))[name.removesuffix('.json')]


def replace_section(path, name, content):
    text = path.read_text(encoding='utf-8')
    pattern = r'<!-- '+name+r'_INICIO -->.*?<!-- '+name+r'_FIM -->'
    text, count = re.subn(pattern, '<!-- '+name+'_INICIO -->\n'+content+'\n<!-- '+name+'_FIM -->', text, flags=re.S)
    if count != 1:
        raise ValueError('Marcador ausente ou duplicado: '+name)
    path.write_text(text, encoding='utf-8')


TABLE_DESC = {
 'convenio':'Catálogo de convênios; paciente pode não possuir vínculo.',
 'paciente':'Cadastro de pacientes e situação administrativa.',
 'profissional':'Dados comuns aos dois subtipos de profissionais.',
 'fisioterapeuta':'Subtipo profissional habilitado a responder por tratamento.',
 'estagiario':'Subtipo com instituição de ensino e supervisor fisioterapeuta.',
 'especialidade':'Catálogo de especialidades de atendimento.',
 'habilitacao_profissional':'Associação N:N entre profissional e especialidade, com data.',
 'tratamento':'Plano de atendimento vinculado a paciente, responsável e especialidade.',
 'sala':'Local físico; a capacidade é descritiva e não controla concorrência de agenda.',
 'sessao':'Atendimento identificado dentro de um tratamento.',
 'evolucao':'Registro de conduta e resposta de uma sessão realizada.',
 'exercicio':'Catálogo de exercícios terapêuticos.',
 'aplicacao_exercicio':'Exercício aplicado em sessão, com parâmetros de execução.',
 'avaliacao_fisica':'Histórico de avaliações por paciente e data.',
 'auditoria_evolucao':'Registro técnico de alterações/exclusões de evolução; etapa 2.'}

FIELD_DESC = {
 'cpf':'CPF em texto, sem pontuação. Os dígitos verificadores não são validados.',
 'nome':'Nome usado no cadastro.',
 'data_nascimento':'Data de nascimento. Gatilhos impedem data futura.',
 'telefone':'Um contato principal; NULL indica ausência.',
 'situacao':'Situação registrada no cadastro.',
 'email':'Um endereço de e-mail; formato não validado por CHECK.',
 'crefito':'Registro profissional único; formato não validado pelo banco.',
 'instituicao_ensino':'Instituição do estagiário.',
 'id_supervisor':'Fisioterapeuta supervisor; obrigatório; não pode ser o próprio estagiário.',
 'descricao':'Descrição livre opcional do catálogo.',
 'data_habilitacao':'Data em que o profissional obteve habilitação na especialidade.',
 'descricao_condicao':'Condição ou objetivo terapêutico do tratamento.',
 'data_inicio':'Início do tratamento; obrigatório.',
 'data_alta':'Alta do tratamento; NULL indica aberto; não anterior ao início.',
 'id_especialidade_em_andamento':'Campo gerado: especialidade se alta é NULL; caso contrário NULL. Não preencher manualmente.',
 'codigo':'Código único de identificação da sala.',
 'capacidade':'Capacidade declarada positiva; não calcula ocupação.',
 'numero_sessao':'Número positivo dentro do tratamento. Não há garantia de sequência sem lacunas.',
 'data_hora':'Data e horário da sessão; sem fuso armazenado.',
 'conduta_aplicada':'Texto da conduta da sessão realizada.',
 'resposta_observada':'Texto da resposta observada na sessão.',
 'regiao_corpo':'Região corporal trabalhada pelo exercício.',
 'series':'Quantidade positiva de séries.',
 'repeticoes':'Quantidade positiva de repetições por série.',
 'carga':'Carga não negativa ou NULL. A unidade não está definida no esquema.',
 'data_avaliacao':'Data da avaliação; única por paciente.',
 'nivel_dor':'Inteiro de 0 a 10, conforme CHECK.',
 'amplitude_movimento':'Descrição textual até 100 caracteres; unidade/padrão clínico não definido.',
 'observacoes':'Observações livres opcionais.',
 'acao':'Gatilhos registram UPDATE, DELETE ou DEL_CASC. VARCHAR sem CHECK de domínio.',
 'conduta_anterior':'Conduta antes da alteração/exclusão.',
 'conduta_nova':'Conduta após UPDATE; NULL na exclusão.',
 'resposta_anterior':'Resposta antes da alteração/exclusão.',
 'resposta_nova':'Resposta após UPDATE; NULL na exclusão.',
 'usuario_db':'Usuário e host da conexão, obtidos por USER().'}


def dictionary():
    schema = read_json('catalogo.json')
    lines = ['# Dicionário de dados', '',
        'Clínica de Fisioterapia | David Fernandes dos Santos | 25/10/2026', '',
        'As 15 tabelas abaixo correspondem às duas etapas do banco, executadas no MySQL 8.0.46. '
        'O catálogo completo está em docs/apoio/evidencias.json. Todas as tabelas usam InnoDB, '
        'utf8mb4 e collation utf8mb4_0900_ai_ci.', '',
        '**Legenda:** PK = chave primária; FK = chave estrangeira; único = valor ou combinação sem repetição. '
        'NULL representa ausência. AUTO_INCREMENT e campos gerados são preenchidos pelo banco. '
        'FK sem ação explícita usa RESTRICT/NO ACTION.', '',
        'NOT NULL não impede texto vazio. O banco não valida todos os formatos de CPF, e-mail e telefone. '
        'As situações ENUM foram testadas em modo SQL estrito. TEXT armazena até 65.535 bytes, '
        'e VARCHAR limita a quantidade de caracteres. O relatório reúne as demais regras e os testes.', '']
    for number, (table, desc) in enumerate(TABLE_DESC.items(), 1):
        data = schema[table]
        lines += [f'## {number}. {table}', '', desc, '',
            '| Coluna | Tipo físico | NULL? | Padrão/geração | Significado |',
            '| --- | --- | --- | --- | --- |']
        for col in data['colunas']:
            name=col['COLUMN_NAME']; extra=col['EXTRA']
            default = str(col['COLUMN_DEFAULT']) if col['COLUMN_DEFAULT'] is not None else ('NULL' if col['IS_NULLABLE']=='YES' else 'Sem padrão')
            if 'auto_increment' in extra: default='AUTO_INCREMENT'
            if col['GENERATION_EXPRESSION']: default='Gerada STORED; ver expressão abaixo'
            labels={'convenio':'do convênio','paciente':'do paciente','profissional':'do profissional','especialidade':'da especialidade','tratamento':'do tratamento','sala':'da sala','exercicio':'do exercício','avaliacao':'da avaliação','auditoria':'do registro de auditoria','fisioterapeuta':'do fisioterapeuta responsável'}
            meaning=FIELD_DESC.get(name, 'Identificador '+labels.get(name.removeprefix('id_'),name.removeprefix('id_'))+'.')
            if name=='situacao': meaning='Situação da sessão.' if table=='sessao' else 'Situação cadastral do paciente.'
            if name=='data_hora' and table=='auditoria_evolucao': meaning='Data e horário da alteração ou exclusão; sem fuso armazenado.'
            if table=='auditoria_evolucao' and name=='numero_sessao':
                meaning='Número da sessão de origem, copiado pelo gatilho; sem FK ou CHECK nesta tabela.'
            lines.append(f"| `{name}` | {col['COLUMN_TYPE']} | {'Sim' if col['IS_NULLABLE']=='YES' else 'Não'} | {default} | {meaning} |")
        lines += ['', '**Chaves e restrições**', '']
        indexes=[]
        for ddl_line in data['ddl'].splitlines():
            value=ddl_line.strip().rstrip(',').replace('`','')
            if value.startswith('PRIMARY KEY'):
                lines.append('- PK: '+value.removeprefix('PRIMARY KEY '))
            elif value.startswith('UNIQUE KEY'):
                lines.append('- Único: '+value[value.index('('):])
            elif value.startswith('KEY '):
                indexes.append(value[value.index('('):])
            elif ' FOREIGN KEY ' in value:
                value=value.split(' FOREIGN KEY ',1)[1]
                lines.append('- FK: '+value.replace(' REFERENCES ',' -> ').replace(' ON DELETE ','; exclusão ').replace(' ON UPDATE ','; atualização '))
            elif ' CHECK ' in value:
                lines.append('- CHECK: '+value.split(' CHECK ',1)[1])
        if indexes: lines += ['', 'Índices adicionais: '+', '.join(indexes)+'.']
        for col in data['colunas']:
            if col['GENERATION_EXPRESSION']:
                lines += ['', 'Expressão gerada: `'+col['GENERATION_EXPRESSION']+'`.']
        lines += ['']
    lines += ['## View e gatilhos', '',
        'A view vw_paciente_restrito expõe id, nome, nascimento e situação do paciente, com SQL SECURITY DEFINER. '
        'Não limita linhas por supervisor. A etapa 1 cria 11 gatilhos de integridade; a etapa 2 acrescenta quatro '
        'de auditoria. O relatório descreve suas funções e limites.', '',
        'A auditoria não possui FK para a sessão, para manter os registros após a exclusão dos dados de origem. '
        'Na etapa 2, idx_avaliacao_dor substitui idx_avaliacao_paciente no suporte à FK; os procedimentos auxiliares '
        'de índices são removidos ao fim da execução.', '',
        'Houve apoio de IA na organização e conferência deste documento.', '']
    (FONTES/'dicionario-dados.md').write_text('\n'.join(lines),encoding='utf-8')


def evidence_sections():
    perf=read_json('explain.json')
    lines=['| Consulta | Resultado (linhas) | Custo antes/depois | Mediana antes/depois (ms) |', '| --- | --- | --- | --- |']
    for n in ('5','10','14'):
        a,b=perf['antes'][n],perf['depois'][n]
        costs=[x['explain']['query_block'].get('cost_info',{}).get('query_cost','não informado') for x in (a,b)]
        lines.append(f"| {n} | {a['linhas_resultado']} | {' / '.join(x.replace('.',',') for x in costs)} | {format(a['mediana_cliente_ms'],'.4f').replace('.',',')} / {format(b['mediana_cliente_ms'],'.4f').replace('.',',')} |")
    replace_section(FONTES/'relatorio.md','PERF','\n'.join(lines))
    data=read_json('validacao.json'); backup=data['backup']
    text=f"Foram concluídos {data['resumo']['passaram']} testes, sem falhas, em MySQL {data['mysql']}, no dia 25/10/2026. "
    text+=f"O dump completo teve {format(backup['bytes'],',').replace(',','.')} bytes; levou {format(backup['segundos_backup'],'.3f').replace('.',',')} s para gerar e {format(backup['segundos_restauracao'],'.3f').replace('.',',')} s para restaurar. "
    text+="Esses tempos se referem à base acadêmica local e não estimam a recuperação de uma clínica em produção."
    replace_section(FONTES/'relatorio.md','TESTES',text)


def inline(text):
    text=text.replace('—','-').replace('–','-').replace('\u2011','-')
    text=re.sub(r'\[([^]]+)\]\(([^)]+)\)',r'\1',text)
    text=html.escape(text)
    text=re.sub(r'`([^`]+)`',r'<font name="Courier">\1</font>',text)
    text=re.sub(r'\*\*([^*]+)\*\*',r'<b>\1</b>',text)
    return text


def pdf_from_markdown(path):
    is_dict=path.stem=='dicionario-dados'
    pagesize=landscape(A4) if is_dict else A4
    width=pagesize[0]-88
    styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name='BodyDoc',fontName='Helvetica',fontSize=9.5,leading=12.5,spaceAfter=6,splitLongWords=True))
    styles.add(ParagraphStyle(name='CellDoc',fontName='Helvetica',fontSize=8,leading=10.5,spaceAfter=0,splitLongWords=True))
    styles.add(ParagraphStyle(name='CodeDoc',fontName='Courier',fontSize=7,leading=9,spaceAfter=8))
    if path.stem=='relatorio':
        styles['BodyDoc'].fontSize=9
        styles['BodyDoc'].leading=11.5
        styles['BodyDoc'].spaceAfter=5
        styles['CellDoc'].fontSize=7.8
        styles['CellDoc'].leading=9.5
    styles['Title'].textColor=colors.HexColor('#123047'); styles['Title'].fontSize=24; styles['Title'].leading=29
    for name in ('Heading1','Heading2'):
        styles[name].textColor=colors.HexColor('#13596A'); styles[name].keepWithNext=True
        styles[name].spaceBefore=13; styles[name].spaceAfter=8
    story=[]; lines=path.read_text(encoding='utf-8').splitlines(); i=0
    while i<len(lines):
        line=lines[i].strip()
        if not line or line.startswith('<!--'): i+=1; continue
        if line.startswith('```'):
            block=[]; i+=1
            while i<len(lines) and not lines[i].startswith('```'):
                block.extend(textwrap.wrap(lines[i],width=112 if is_dict else 95,replace_whitespace=False,drop_whitespace=False) or [''])
                i+=1
            story.append(Preformatted('\n'.join(block),styles['CodeDoc'])); i+=1; continue
        if line.startswith('|'):
            table=[]
            while i<len(lines) and lines[i].strip().startswith('|'):
                cells=[x.strip() for x in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r'[:\- ]+',x) for x in cells):
                    table.append([Paragraph(inline(x),styles['CellDoc']) for x in cells])
                i+=1
            n=len(table[0])
            weights=([.22,.18,.06,.16,.38] if is_dict and n==5 else
                ([.12,.42,.46] if n==3 else [.24,.23,.25,.28] if n==4 else [1/n]*n))
            if path.stem=='relatorio' and n==3: weights=[.17,.41,.42]
            t=LongTable(table,colWidths=[width*w for w in weights],repeatRows=1,hAlign='LEFT',splitByRow=1,splitInRow=1)
            t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#E5F0F2')),
                ('VALIGN',(0,0),(-1,-1),'TOP'),('GRID',(0,0),(-1,-1),.35,colors.HexColor('#B8C6CC')),
                ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
                ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
                ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F6F8FA')])]))
            story += [t,Spacer(1,9)]; continue
        if line.startswith('# '): story.append(Paragraph(inline(line[2:]),styles['Title']))
        elif line.startswith('## '): story.append(Paragraph(inline(line[3:]),styles['Heading1']))
        elif line.startswith('### '): story.append(Paragraph(inline(line[4:]),styles['Heading2']))
        elif line.startswith('- '): story.append(Paragraph('• '+inline(line[2:]),styles['BodyDoc']))
        else:
            following=next((x.strip() for x in lines[i+1:] if x.strip()),'')
            paragraph=Paragraph(inline(line),styles['BodyDoc'])
            if following.startswith(('|','```')) or line=='**Chaves e restrições**': paragraph.keepWithNext=True
            story.append(paragraph)
        i+=1
    def footer(canvas,doc):
        canvas.saveState(); canvas.setStrokeColor(colors.HexColor('#B8C6CC')); canvas.line(44,36,pagesize[0]-44,36)
        canvas.setFont('Helvetica',7); canvas.setFillColor(colors.HexColor('#425866'))
        canvas.drawString(44,24,'Clínica de Fisioterapia | Documentação e validação | 25/10/2026')
        canvas.drawRightString(pagesize[0]-44,24,str(doc.page)); canvas.restoreState()
    doc=SimpleDocTemplate(str(DOCS/(path.stem+'.pdf')),pagesize=pagesize,rightMargin=44,leftMargin=44,topMargin=42,bottomMargin=50,
        title=lines[0].lstrip('# '),author='Equipe Clínica de Fisioterapia - documentação: David')
    doc.build(story,onFirstPage=footer,onLaterPages=footer)


if __name__=='__main__':
    dictionary(); evidence_sections()
    for name in ('dicionario-dados','relatorio'):
        pdf_from_markdown(FONTES/(name+'.md'))
        print('Gerado:',name+'.pdf')
