import '../domain/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Character IDs
// ─────────────────────────────────────────────────────────────────────────────
const int _player  = 0;
const int _tatiana = 1;
const int _carmen  = 2;
const int _manuela = 3;
const int _patricia= 4;
const int _samuel  = 5;
const int _jorge   = 6;
const int _nando   = 7;
const int _isabel  = 8;
const int _estrela = 9;
const int _helder  = 10;
const int _abel    = 11;
const int _rui     = 12;

// ─────────────────────────────────────────────────────────────────────────────
// State-flag IDs
// ─────────────────────────────────────────────────────────────────────────────
const int _fViuCMP        = 1; // player witnessed CMP conversation
const int _fSabeVitima    = 2; // player knows Tatiana is the victim
const int _fFalouTatiana  = 3; // player spoke with Tatiana
const int _fApoiouTatiana = 4; // player supported Tatiana
const int _fConfrontouCarmen = 5; // player confronted Carmen

// ─────────────────────────────────────────────────────────────────────────────
// Dialogue helpers
// ─────────────────────────────────────────────────────────────────────────────
DialogueNode _line(int speaker, String text, {DialogueNode? next}) {
  final n = DialogueNode(line: DialogueLine(speakerId: speaker, text: text));
  if (next != null) n.setNext(next);
  return n;
}

/// Chains a list of [DialogueLine] nodes and returns the head.
DialogueNode _chain(List<(int, String)> lines) {
  assert(lines.isNotEmpty);
  DialogueNode? tail;
  for (final (spk, txt) in lines.reversed) {
    tail = _line(spk, txt, next: tail);
  }
  return tail!;
}

WorldBlueprint buildSeedWorld() {
  // ── Areas ──────────────────────────────────────────────────────────────────
  // IDs: 1=Pátio 2=Corredor 3=Sala A 4=Biblioteca 5=Gabinete 6=Escadas 7=Sala B
  const areas = <int, Area>{
    1: Area(id: 1, name: 'Pátio',        backgroundPath: 'areas/patio1.jpg',  connectionIds: [1, 2]),
    2: Area(id: 2, name: 'Corredor',     backgroundPath: 'areas/corr1.jpg',   connectionIds: [1, 3, 4, 5]),
    3: Area(id: 3, name: 'Sala de Aula', backgroundPath: 'areas/sala1.jpg',   connectionIds: [3]),
    4: Area(id: 4, name: 'Biblioteca',   backgroundPath: 'areas/biblio1a.jpg',connectionIds: [4, 6]),
    5: Area(id: 5, name: 'Gabinete',     backgroundPath: 'areas/gab1b.jpg',   connectionIds: [5]),
    6: Area(id: 6, name: 'Escadas',      backgroundPath: 'areas/esc1a.jpg',   connectionIds: [2, 6, 7]),
    7: Area(id: 7, name: 'Sala B',       backgroundPath: 'areas/sala2.jpg',   connectionIds: [7]),
  };

  // ── Connections ────────────────────────────────────────────────────────────
  const connections = <int, Connection>{
    1: Connection(id: 1, areaA: 1, areaB: 2, label: 'Corredor',
       hotspotAx: 0.85, hotspotAy: 0.60, hotspotBx: 0.10, hotspotBy: 0.65),
    2: Connection(id: 2, areaA: 1, areaB: 6, label: 'Escadas',
       hotspotAx: 0.50, hotspotAy: 0.80, hotspotBx: 0.50, hotspotBy: 0.20),
    3: Connection(id: 3, areaA: 2, areaB: 3, label: 'Sala de Aula',
       hotspotAx: 0.80, hotspotAy: 0.55, hotspotBx: 0.15, hotspotBy: 0.60),
    4: Connection(id: 4, areaA: 2, areaB: 4, label: 'Biblioteca',
       hotspotAx: 0.25, hotspotAy: 0.55, hotspotBx: 0.80, hotspotBy: 0.60),
    5: Connection(id: 5, areaA: 2, areaB: 5, label: 'Gabinete',
       hotspotAx: 0.50, hotspotAy: 0.85, hotspotBx: 0.50, hotspotBy: 0.20),
    6: Connection(id: 6, areaA: 4, areaB: 6, label: 'Escadas',
       hotspotAx: 0.15, hotspotAy: 0.60, hotspotBx: 0.80, hotspotBy: 0.55),
    7: Connection(id: 7, areaA: 6, areaB: 7, label: 'Sala B',
       hotspotAx: 0.80, hotspotAy: 0.55, hotspotBx: 0.15, hotspotBy: 0.60),
  };

  // ── Characters ─────────────────────────────────────────────────────────────
  const characters = <int, Character>{
    _player:   Character(id: _player,   name: 'Jogador',   colorHex: '#808080', portraitPath: '',                       areaId: 1, bodyPath: ''),
    _tatiana:  Character(id: _tatiana,  name: 'Tatiana',   colorHex: '#7B68EE', portraitPath: 'portraits/tatiana.png',  areaId: 4, bodyPath: 'bodies/tatiana.png'),
    _carmen:   Character(id: _carmen,   name: 'Carmen',    colorHex: '#DC143C', portraitPath: 'portraits/carmen.png',   areaId: 2, bodyPath: 'bodies/carmen.png'),
    _manuela:  Character(id: _manuela,  name: 'Manuela',   colorHex: '#CD853F', portraitPath: 'portraits/manuela.png',  areaId: 2, bodyPath: 'bodies/manuela.png'),
    _patricia: Character(id: _patricia, name: 'Patrícia',  colorHex: '#20B2AA', portraitPath: 'portraits/patricia.png', areaId: 2, bodyPath: 'bodies/patricia.png'),
    _samuel:   Character(id: _samuel,   name: 'Samuel',    colorHex: '#4169E1', portraitPath: 'portraits/samuel.png',   areaId: 3, bodyPath: 'bodies/samuel.png'),
    _jorge:    Character(id: _jorge,    name: 'Jorge',     colorHex: '#2E8B57', portraitPath: 'portraits/jorge.png',    areaId: 1, bodyPath: 'bodies/jorge.png'),
    _nando:    Character(id: _nando,    name: 'Nando',     colorHex: '#FF8C00', portraitPath: 'portraits/nando.png',    areaId: 1, bodyPath: 'bodies/nando.png'),
    _isabel:   Character(id: _isabel,   name: 'Isabel',    colorHex: '#DA70D6', portraitPath: 'portraits/isabel.png',   areaId: 4, bodyPath: 'bodies/isabel.png'),
    _estrela:  Character(id: _estrela,  name: 'Estrela',   colorHex: '#FFD700', portraitPath: 'portraits/estrela.png',  areaId: 3, bodyPath: 'bodies/estrela.png'),
    _helder:   Character(id: _helder,   name: 'Helder',    colorHex: '#00CED1', portraitPath: 'portraits/helder.png',   areaId: 3, bodyPath: 'bodies/helder.png'),
    _abel:     Character(id: _abel,     name: 'Abel',      colorHex: '#32CD32', portraitPath: 'portraits/abel.png',     areaId: 1, bodyPath: 'bodies/abel.png'),
    _rui:      Character(id: _rui,      name: 'Rui',       colorHex: '#FF6347', portraitPath: 'portraits/rui.png',      areaId: 3, bodyPath: 'bodies/rui.png'),
  };

  // ── State flags ────────────────────────────────────────────────────────────
  const gamestates = <int, StateFlag>{
    _fViuCMP:          StateFlag(id: _fViuCMP,          name: 'Viu conversa CMP',       value: false),
    _fSabeVitima:      StateFlag(id: _fSabeVitima,      name: 'Sabe que Tatiana é vítima', value: false),
    _fFalouTatiana:    StateFlag(id: _fFalouTatiana,    name: 'Falou com Tatiana',       value: false),
    _fApoiouTatiana:   StateFlag(id: _fApoiouTatiana,   name: 'Apoiou Tatiana',          value: false),
    _fConfrontouCarmen:StateFlag(id: _fConfrontouCarmen,name: 'Confrontou Carmen',       value: false),
  };

  // ── Dialogues ──────────────────────────────────────────────────────────────

  // 1. CMP — bullies discussing the post (observer; consequences: viu_cmp)
  final d1 = Dialogue(
    id: 1, name: 'Conversa das Bullies',
    characterIds: [_carmen, _manuela, _patricia],
    singleTrigger: true,
    preconditions: {},
    consequences: {_fViuCMP: true},
    selfRemove: true,
    priority: 2,
    parentNode: _chain([
      (_carmen,   '"O título da foto podia ser: A Baleia fora de água."'),
      (_patricia, 'Eu meti um like. Se fosse eu a andar assim de biquíni, morria!'),
      (_carmen,   'Era o que ela devia fazer.'),
      (_manuela,  '*Risos*'),
      (_carmen,   'Da próxima vez escrevo isso mesmo. Mata-te!'),
      (_manuela,  'Sim, não fazes falta a ninguém. Vai morrer longe!'),
      (_carmen,   '*Risos*'),
      (_patricia, 'Para, tá ali um stôr. Esconde o telemóvel.'),
    ]),
  );

  // 2. Jorge e Samuel (observer)
  final d2 = Dialogue(
    id: 2, name: 'Jorge e Samuel',
    characterIds: [_jorge, _samuel],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_samuel, 'Sempre vens a minha casa hoje à tarde?'),
      (_jorge,  'Népia, hoje não posso.'),
      (_samuel, 'Então? Tavas todo entusiasmado no outro dia, e agora não podes?'),
      (_jorge,  'Pois eu sei, mas hoje não dá mesmo jeito.'),
      (_jorge,  '*telefone a tocar* Pera aí, preciso de atender, nós depois falamos.'),
      (_samuel, 'Ok na boa, até já.'),
    ]),
  );

  // 3. Abel e Nando (observer)
  final d3 = Dialogue(
    id: 3, name: 'Abel e Nando',
    characterIds: [_abel, _nando],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_nando, 'Vais estar na sexta-feira, não é, Abel? Estou a contar contigo!'),
      (_abel,  'Já sabes que sim Nando, futebol é comigo.'),
      (_nando, 'Também convidei o Jorge, tou só à espera de resposta dele.'),
      (_abel,  'Se ele vier, ficamos com a equipa cheia.'),
      (_nando, 'Yeap, e ele joga bem, por isso já tá ganho.'),
      (_abel,  'Calma campeão, é o Jorge, não é o Ronaldo! *risos*'),
    ]),
  );

  // 4. Tatiana sozinha — sinais de alerta (observer; sem precondições)
  final d4 = Dialogue(
    id: 4, name: 'Tatiana sozinha',
    characterIds: [_tatiana],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_tatiana, '*a olhar para o telemóvel*'),
      (_tatiana, '*som de mensagem*'),
      (_tatiana, '...'),
    ]),
  );

  // 5. Isabel e Tatiana (observer; alerta)
  final d5 = Dialogue(
    id: 5, name: 'Isabel e Tatiana',
    characterIds: [_isabel, _tatiana],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_tatiana, 'Tens um comprimido para a dor de cabeça?'),
      (_isabel,  'Acho que sim, deixa ver na mala. Tens a certeza que estás bem?'),
      (_tatiana, 'Não tenho conseguido dormir nada de jeito, é só isso...'),
    ]),
  );

  // 6. Estrela e Samuel — sabem de algo (observer; precondição: viu_cmp)
  final d6 = Dialogue(
    id: 6, name: 'Estrela e Samuel',
    characterIds: [_estrela, _samuel],
    singleTrigger: true,
    preconditions: {_fViuCMP: true},
    consequences: {},
    selfRemove: true,
    priority: 1,
    parentNode: _chain([
      (_estrela, 'A Tatiana? Sabes dela?'),
      (_samuel,  'Tem estado na casa de banho a maior parte do dia.'),
      (_estrela, 'Então? Ela está mal disposta ou algo assim?'),
      (_samuel,  'Não, tu não viste o que lhe fizeram?'),
      (_estrela, 'Não...'),
      (_samuel,  'Eu depois desta aula conto-te.'),
    ]),
  );

  // 7. Helder e Isabel (observer)
  final d7 = Dialogue(
    id: 7, name: 'Helder e Isabel',
    characterIds: [_helder, _isabel],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_helder, 'Sempre consegues vir este fim de semana ao Centro de Apoio?'),
      (_isabel, 'Sim! Tenho tarde livre por isso só preciso das horas.'),
      (_helder, 'Fixe, em princípio podes aparecer lá a partir das 9h. Precisas de boleia?'),
      (_isabel, 'Aquilo fica perto da estação não é?'),
      (_helder, 'Sim, são por volta de 10 minutos a pé.'),
      (_isabel, 'Então sem problema, eu vou de comboio e depois faço o resto a pé.'),
      (_helder, 'Ok, então eu depois falo com eles e confirmo-te as horas.'),
    ]),
  );

  // 8. Jorge e Nando — Nando evasivo (observer; precondição: viu_cmp)
  final d8 = Dialogue(
    id: 8, name: 'Jorge e Nando',
    characterIds: [_jorge, _nando],
    singleTrigger: true,
    preconditions: {_fViuCMP: true},
    consequences: {},
    selfRemove: true,
    priority: 1,
    parentNode: _chain([
      (_nando, 'Na sexta vamos ter aquele torneio de futebol.'),
      (_jorge, 'Huh-huh.'),
      (_nando, 'Queres aparecer lá?'),
      (_jorge, 'Hum não sei, tenho de ver.'),
      (_nando, 'Meu, como assim tens de ver. Parece que tás com a cabeça na lua...'),
      (_jorge, 'Desculpa Nando, tou só a pensar noutras cenas. Futebol? Ya, parece-me bem, mas amanhã confirmo-te, sem falta.'),
      (_nando, 'Pronto, era só isso que eu queria.'),
    ]),
  );

  // 9. Abel e Rui — desconfiam de Nando (observer; precondição: viu_cmp)
  final d9 = Dialogue(
    id: 9, name: 'Abel e Rui',
    characterIds: [_abel, _rui],
    singleTrigger: true,
    preconditions: {_fViuCMP: true},
    consequences: {},
    selfRemove: true,
    priority: 1,
    parentNode: _chain([
      (_abel, 'Chegaste a ver o último episódio?'),
      (_rui,  'Sim! Não estava nada à espera do final, apanhou-me completamente de surpresa...'),
      (_abel, 'É né?!'),
      (_rui,  'Também não percebo o que anda a fazer o Jorge. Hoje de manhã não apareceu na aula.'),
      (_abel, 'Eu acho que ele foi sair ontem à tarde com mais pessoal, mas não tenho a certeza.'),
    ]),
  );

  // 10. Revelação na sala — turma reage (observer; precondição: viu_cmp; consequência: sabe_vitima)
  final d10 = Dialogue(
    id: 10, name: 'Revelação na Sala',
    characterIds: [_isabel, _estrela, _samuel, _carmen, _helder],
    singleTrigger: true,
    preconditions: {_fViuCMP: true},
    consequences: {_fSabeVitima: true},
    selfRemove: true,
    priority: 2,
    parentNode: _chain([
      (_isabel,  'Malta, já sabem o que aconteceu à Tatiana?'),
      (_estrela, 'O quê? Não sei de nada.'),
      (_isabel,  'Andam a partilhar uma foto dela em biquíni a dizer que ela é feia e gorda.'),
      (_samuel,  'Eu até acho que ela está bem gira.'),
      (_isabel,  'Isto é bué grave! Ela tem estado fechada na casa de banho.'),
      (_carmen,  'Ela é que leva tudo a sério! Foi só no gozo.'),
      (_estrela, 'Dizes isso porque não é contigo!'),
      (_samuel,  'Temos de fazer alguma coisa para a ajudar.'),
      (_helder,  'Epá não sei se me vou meter nesse filme. Ainda sobra para nós!'),
    ]),
  );

  // 11. Tatiana — sinais de alerta visíveis (observador; precondição: sabe_vitima)
  final d11 = Dialogue(
    id: 11, name: 'Tatiana — Sinal de Alerta',
    characterIds: [_tatiana],
    singleTrigger: true,
    preconditions: {_fSabeVitima: true},
    consequences: {},
    selfRemove: true,
    priority: 1,
    parentNode: _chain([
      (_tatiana, '*a ouvir música com os auscultadores*'),
      (_tatiana, '*colegas apontam e riem*'),
      (_tatiana, '*esconde a cabeça entre os braços*'),
    ]),
  );

  // 12. Samuel apoia Tatiana (observer; precondição: sabe_vitima)
  final d12 = Dialogue(
    id: 12, name: 'Samuel e Tatiana',
    characterIds: [_samuel, _tatiana],
    singleTrigger: true,
    preconditions: {_fSabeVitima: true},
    consequences: {},
    selfRemove: true,
    priority: 1,
    parentNode: _chain([
      (_samuel,  'Estás melhor?'),
      (_tatiana, 'Sim, está tudo bem. Mais do mesmo.'),
      (_samuel,  'Que tal irmos sair hoje à tarde? Podemos passar naquele parque ao pé do rio.'),
      (_tatiana, 'Boa ideia, talvez me dê um bocadinho de sossego.'),
      (_samuel,  'Ok, depois das aulas passo pela biblioteca e depois vou ter contigo à entrada.'),
      (_tatiana, 'Está bem.'),
    ]),
  );

  // 13. EHR — Estrela, Helder, Rui (observer; sem precondições)
  final d13 = Dialogue(
    id: 13, name: 'Estrela, Helder e Rui',
    characterIds: [_estrela, _helder, _rui],
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    selfRemove: true,
    priority: 0,
    parentNode: _chain([
      (_helder,  'Obrigado pela ajuda pessoal. Estrela, posso ficar com o teu caderno hoje?'),
      (_estrela, 'Sem problema, mas não te esqueças de entregar amanhã!'),
      (_helder,  'Claro, não te preocupes.'),
      (_rui,     'Olhem, vocês conseguiram resolver o exercício 3.2 do teste modelo?'),
      (_estrela, 'O 3.2? Esse acho que não fiz.'),
      (_helder,  'Não consegui o exercício 3 inteiro, por isso é que vim pedir apontamentos.'),
      (_rui,     'Hmm ok, eu depois pergunto ao professor na aula.'),
    ]),
  );

  // ── Interactive dialogues ─────────────────────────────────────────────────

  // 14. Player fala com Tatiana — com ramificações emocionais
  // precondição: sabe_vitima; consequência: falou_tatiana
  // Choice: 3=Triste, 6=Calmo, 0=Furioso
  final _d14branchTriste = _chain([
    (_tatiana, '*respira fundo* Obrigada... A sério. Às vezes sinto que ninguém liga.'),
    (_tatiana, 'Não sei quanto tempo mais consigo aguentar. Já não quero vir à escola.'),
    (_player,  'Não és tu que tens de mudar — são elas. Vais aguentar, não estás sozinha.'),
    (_tatiana, '*acena com a cabeça lentamente* Obrigada.'),
  ]);
  final _d14branchCalmo = _chain([
    (_tatiana, 'Estou... a tentar. O Samuel já me disse isso mas é difícil não ligar.'),
    (_tatiana, 'O pior é entrar no Com@Viver e ver tudo aquilo.'),
    (_player,  'Talvez valha a pena falar com a psicologa no gabinete. Ela pode ajudar.'),
    (_tatiana, 'Nunca pensei nisso. Se calhar tens razão.'),
  ]);
  final _d14branchFurioso = _chain([
    (_tatiana, 'Não, espera! Não precisas de ir falar com ninguém. Fica ainda pior.'),
    (_tatiana, 'A última vez que alguém foi falar com os professores, elas ficaram furiosas comigo.'),
    (_player,  'Tens razão, desculpa. Então o que queres que eu faça?'),
    (_tatiana, 'Só... fica aqui um bocado. Isso já ajuda.'),
  ]);
  final _d14choice = DialogueNode(
    choice: DialogueChoice(choices: {
      3: 'Sinto muito, não mereces isto. Estou aqui.',
      6: 'Queria só saber como estás. Tens apoio.',
      0: 'Isto é inadmissível. Vou resolver já.',
    }),
  )
    ..addChild(3, _d14branchTriste)
    ..addChild(6, _d14branchCalmo)
    ..addChild(0, _d14branchFurioso);
  final d14opening = _line(_tatiana, 'Olá... *olha para cima surpreendida* Precisas de alguma coisa?', next: _d14choice);
  final d14 = Dialogue(
    id: 14, name: 'Falar com Tatiana',
    characterIds: [_player, _tatiana],
    singleTrigger: true,
    preconditions: {_fSabeVitima: true},
    consequences: {_fFalouTatiana: true},
    selfRemove: true,
    priority: 2,
    parentNode: d14opening,
  );

  // 15. Player confronta Carmen — com ramificações emocionais
  // precondição: falou_tatiana; consequência: confrontou_carmen
  final _d15branchFurioso = _chain([
    (_carmen,  '*olha para ti com arrogância* Tens noção do que é que me estás a dizer?'),
    (_carmen,  'Que drama! Foi só uma foto no grupo, ninguém foi morrer por isso.'),
    (_player,  'Uma foto com insultos que toda a escola viu. Isso é bullying.'),
    (_carmen,  '... *vira-se e vai-se embora sem dizer nada*'),
  ]);
  final _d15branchCalmo = _chain([
    (_carmen,  '*para um momento* Que esperas que eu diga?'),
    (_carmen,  'Ela exagera sempre. Nós apenas partilhámos uma foto.'),
    (_player,  'Com legendas a dizer-lhe para se matar. Pensa nisso.'),
    (_carmen,  '*fica em silêncio* ... Estava só a brincar.'),
    (_player,  'Ela não está a brincar. Está a sofrer a sério.'),
    (_carmen,  '*desvia o olhar* Não sabia que ela levava assim tão a sério...'),
  ]);
  final _d15branchTriste = _chain([
    (_carmen,  'Porque? Tu és amiga dela ou quê?'),
    (_player,  'Não preciso de ser amiga dela para saber que isso está errado.'),
    (_carmen,  '*fica na defensiva* Toda a gente partilha esse tipo de coisas.'),
    (_player,  'Não, não toda a gente. E há uma diferença entre partilhar e atacar uma pessoa.'),
    (_carmen,  '*olha para o chão* ... Okay.'),
  ]);
  final _d15choice = DialogueNode(
    choice: DialogueChoice(choices: {
      0: 'O que fizeste é cyberbullying. Tem consequências.',
      6: 'Já pensaste como a Tatiana se sente?',
      3: 'Não percebo porque a tratas assim.',
    }),
  )
    ..addChild(0, _d15branchFurioso)
    ..addChild(6, _d15branchCalmo)
    ..addChild(3, _d15branchTriste);
  final d15opening = _line(_carmen, 'Ó, o que queres? *amigos a observar ao fundo*', next: _d15choice);
  final d15 = Dialogue(
    id: 15, name: 'Confrontar Carmen',
    characterIds: [_player, _carmen],
    singleTrigger: true,
    preconditions: {_fFalouTatiana: true},
    consequences: {_fConfrontouCarmen: true},
    selfRemove: true,
    priority: 2,
    parentNode: d15opening,
  );

  // 16. Apoio final — Tatiana reage ao confronto (precondição: confrontou_carmen)
  final d16 = Dialogue(
    id: 16, name: 'Tatiana — Depois do Confronto',
    characterIds: [_tatiana, _player],
    singleTrigger: true,
    preconditions: {_fConfrontouCarmen: true},
    consequences: {_fApoiouTatiana: true},
    selfRemove: true,
    priority: 3,
    isEnding: true,
    parentNode: _chain([
      (_tatiana, 'Ouvi que foste falar com a Carmen...'),
      (_tatiana, 'Ninguém fez isso por mim antes. Obrigada.'),
      (_player,  'Ela precisava de perceber o impacto do que fez.'),
      (_tatiana, 'Não sei se vai mudar alguma coisa, mas sinto-me menos sozinha.'),
      (_tatiana, '*sorri ligeiramente* Isso importa.'),
    ]),
  );

  final dialogues = <int, Dialogue>{
    for (final d in [d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16])
      d.id: d,
  };

  return WorldBlueprint(
    startingAreaId: 1,
    areas: areas,
    connections: connections,
    characters: characters,
    gamestates: gamestates,
    dialogues: dialogues,
    events: {},
    groups: {},
  );
}
