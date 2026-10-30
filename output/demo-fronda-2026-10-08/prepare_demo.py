"""Prepare demonstration records through Fronda's public CLI, without storage access."""
import copy
import json
from pathlib import Path
import subprocess
import time
import uuid

ROOT = Path('/Users/pedronazarito/Developer/Harness-me')
REPOSITORY = Path('/Users/pedronazarito/Developer/fronda-demo-formulario')
CLI = str(ROOT / 'dist/fronda')
NODE = '/Users/pedronazarito/.local/bin/node'
MANIFEST = Path(__file__).with_name('manifest.json')
state = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'runs': {}}

def save():
    MANIFEST.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')

def rpc(action, **fields):
    request = {'requestID': str(uuid.uuid4()), 'action': action, 'id': '', 'relatedID': '',
               'text': '', 'path': '', 'arguments': [], 'flag': False, 'number': 0}
    request.update(fields)
    result = subprocess.run([CLI, 'rpc'], input=json.dumps(request), text=True, capture_output=True, timeout=120)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    response = json.loads(result.stdout)
    if response.get('error'):
        raise RuntimeError(response['error'])
    return response

def get_run(identity):
    return rpc('run.get', id=identity)['run']

def wait_run(identity):
    deadline = time.monotonic() + 50
    while time.monotonic() < deadline:
        run = get_run(identity)
        if run['state'] not in ['RUNNING', 'PREPARING', 'QUEUED']:
            return run
        time.sleep(.35)
    raise RuntimeError('A preparação não terminou. Retome pelo ID já registrado no manifesto.')

def create(key, title, book, criteria, budget=32000):
    if key in state['runs']:
        return get_run(state['runs'][key]['id'])
    args = [CLI, '--json', 'create', state['projectID'], title, '--runbook', book,
            '--provider', 'Codex', '--mode', 'Guiado', '--scope', 'src/contact.ts', '--budget', str(budget)]
    for criterion in criteria:
        args += ['--criterion', criterion]
    response = json.loads(subprocess.check_output(args, text=True, timeout=50))
    state['runs'][key] = {'id': response['id'], 'title': title}
    save()
    return wait_run(response['id'])

def command(identity, name, files, approved=True, required=True):
    return {'id': identity, 'name': name, 'executable': NODE,
            'arguments': ['check-syntax.mjs', *files], 'timeoutSeconds': 20,
            'required': required, 'approved': approved, 'readOnly': True}

def summary(run):
    return {'id': run['id'], 'title': run['title'], 'state': run['state'], 'reason': run['reason'],
            'workspace': run['workspace'], 'sequence': run['sequence'],
            'validations': [{'name': v['validator']['name'], 'status': v['status'], 'exitCode': v.get('exitCode')} for v in run['validations']]}

if __name__ == '__main__':
    snapshot = rpc('snapshot')['snapshot']
    project = next((p for p in snapshot['projects'] if p['path'] == str(REPOSITORY)), None)
    if project is None:
        project_id = rpc('project.add', path=str(REPOSITORY))['id']
        project = next(p for p in rpc('snapshot')['snapshot']['projects'] if p['id'] == project_id)
    deadline = time.monotonic() + 40
    while project['indexState'] not in ['READY', 'DEGRADED'] and time.monotonic() < deadline:
        time.sleep(.3)
        project = next(p for p in rpc('snapshot')['snapshot']['projects'] if p['id'] == project['id'])
    state['projectID'] = project['id']
    state['repository'] = str(REPOSITORY)
    save()
    if not state.get('configured') or not any(v['id'] == 'demo-domain' for v in project['validators']):
        project['name'] = 'Demo Fronda · Cadastro de contato'
        project['validators'] = [
            command('demo-domain', 'Sintaxe da regra e dos tipos', ['src/contact.types.ts', 'src/contact.ts']),
            command('demo-form', 'Sintaxe da interface', ['src/form.ts']),
            command('demo-server', 'Sintaxe do servidor local', ['serve.mjs']),
        ]
        project['allowedPaths'] = ['src/**', 'index.html', 'styles.css', 'serve.mjs', 'check-syntax.mjs', 'README.md', 'CENARIOS.md', 'AGENTS.md']
        project['lockedPaths'] = ['AGENTS.md', 'CENARIOS.md', 'check-syntax.mjs', 'serve.mjs']
        project['allowNetwork'] = False
        rpc('project.update', project=project)
        main_book = copy.deepcopy(next(b for b in snapshot['runbooks'] if b['name'] == 'Corrigir bug'))
        main_book['id'] = 'fronda-demo-cadastro-v1'
        main_book['name'] = 'Demo Fronda · Corrigir cadastro'
        main_book['subtitle'] = 'Apelido opcional: reprodução, plano, correção, conferência e revisão.'
        main_book['budget'] = 64000
        rpc('runbook.save', runbook=main_book)
        diagnostic = copy.deepcopy(main_book)
        diagnostic['id'] = 'fronda-demo-diagnostico-v1'
        diagnostic['name'] = 'Demo Fronda · Estados de validação'
        diagnostic['subtitle'] = 'Demonstração local de comandos e evidências, sem agente de IA.'
        diagnostic['workKind'] = None
        diagnostic['steps'] = [s for s in diagnostic['steps'] if s['kind'] in ['context', 'validation', 'evidence']]
        for index, step in enumerate(diagnostic['steps']):
            step['dependencies'] = [diagnostic['steps'][index - 1]['id']] if index else []
        rpc('runbook.save', runbook=diagnostic)
        blocked = copy.deepcopy(diagnostic)
        blocked['id'] = 'fronda-demo-aprovacao-v1'
        blocked['name'] = 'Demo Fronda · Comando sem aprovação'
        blocked['validationCommands'] = [command('demo-unapproved', 'Aprovação pendente: conferir regra', ['src/contact.ts'], approved=False)]
        rpc('runbook.save', runbook=blocked)
        state['configured'] = True
        save()

    criteria = [
        'Salvar um contato com nome e e-mail válidos quando o apelido está vazio.',
        'Tratar apelido somente com espaços como ausente, sem mensagem de erro.',
        'Preservar a validação de nome obrigatório com pelo menos dois caracteres e e-mail válido.',
        'Preservar o salvamento com apelido preenchido e a normalização de espaços e e-mail.',
        'Preservar mensagens acessíveis, campos digitados, tratamento de duplicidade e duplo envio.',
        'Alterar somente src/contact.ts, sem criar testes, mocks, dependências ou publicar alterações.',
        'Distinguir sintaxe aprovada dos cenários funcionais observados antes e depois.',
    ]
    main = create('start', '01 · Começar aqui: corrigir cadastro sem apelido', 'Demo Fronda · Corrigir cadastro', criteria)
    passed = create('pass', '02 · PASS: comando de sintaxe aprovado', 'Demo Fronda · Estados de validação', ['Observar comandos reais com saída zero. Isso não representa correção funcional concluída.'])
    failed = create('fail', '03 · FAIL: erro de sintaxe na worktree da demo', 'Demo Fronda · Estados de validação', ['Observar falha real de sintaxe sem alterar o repositório original.'])
    blocked = create('approval', '04 · BLOCKED: comando aguarda aprovação', 'Demo Fronda · Comando sem aprovação', ['Um comando não aprovado deve ser bloqueado antes da execução.'])
    stale = create('stale', '05 · STALE: código mudou após a validação', 'Demo Fronda · Estados de validação', ['Uma alteração posterior torna a evidência anterior desatualizada.'])
    paused = create('paused', '06 · Pausa: tarefa pronta para retomar', 'Demo Fronda · Corrigir cadastro', criteria)
    cancelled = create('cancelled', '07 · Cancelamento: trabalho preservado', 'Demo Fronda · Corrigir cadastro', criteria)
    budget = create('budget', '08 · Orçamento: contexto maior que o limite', 'Demo Fronda · Corrigir cadastro', criteria, budget=1000)
    live = create('live', '09 · Correção real: cadastro com apelido opcional', 'Demo Fronda · Corrigir cadastro', criteria, budget=64000)

    for key in ['pass', 'fail', 'approval', 'stale', 'paused', 'cancelled']:
        if state['runs'][key].get('prepared'):
            continue
        run = get_run(state['runs'][key]['id'])
        if key == 'fail':
            source = Path(run['workspace']) / 'src/contact.ts'
            source.write_text(source.read_text() + '\n// Erro controlado somente nesta worktree de demonstração.\nexport const sintaxeInterrompida = ;\n')
            rpc('run.reconcile', id=run['id'])
        if key in ['pass', 'fail', 'stale']:
            rpc('validation.run', id=run['id'])
            run = wait_run(run['id'])
        if key == 'approval':
            rpc('validation.run', id=run['id'], relatedID='demo-unapproved')
            run = wait_run(run['id'])
        if key == 'stale':
            source = Path(run['workspace']) / 'src/contact.ts'
            source.write_text(source.read_text() + '\n// Alteração posterior para demonstrar invalidação de evidências.\n')
            rpc('run.reconcile', id=run['id'])
        if key == 'paused':
            rpc('run.pause', id=run['id'])
        if key == 'cancelled':
            rpc('run.cancel', id=run['id'])
        state['runs'][key]['prepared'] = True
        save()

    for key, entry in state['runs'].items():
        observed = summary(get_run(entry['id']))
        state['runs'][key].update(observed)
        print(json.dumps({'scenario': key, **observed}, ensure_ascii=False), flush=True)
    save()
