import '../domain/models.dart';

WorldBlueprint buildSeedWorld() {
  final areas = <int, Area>{
    1: const Area(
      id: 1,
      name: 'Corredor',
      backgroundPath: 'editor/areas/area (1).jpg',
      connectionIds: [1, 2],
    ),
    2: const Area(
      id: 2,
      name: 'Sala de Aula',
      backgroundPath: 'editor/areas/area (2).jpg',
      connectionIds: [1, 3],
    ),
    3: const Area(
      id: 3,
      name: 'Cantina',
      backgroundPath: 'editor/areas/area (3).jpg',
      connectionIds: [2, 4],
    ),
    4: const Area(
      id: 4,
      name: 'Pátio',
      backgroundPath: 'editor/areas/area (4).jpg',
      connectionIds: [3, 4],
    ),
  };

  final connections = <int, Connection>{
    1: const Connection(
      id: 1, areaA: 1, areaB: 2,
      label: 'Sala de Aula',
      hotspotAx: 0.82, hotspotAy: 0.65,
      hotspotBx: 0.12, hotspotBy: 0.70,
    ),
    2: const Connection(
      id: 2, areaA: 1, areaB: 3,
      label: 'Cantina',
      hotspotAx: 0.50, hotspotAy: 0.85,
      hotspotBx: 0.50, hotspotBy: 0.15,
    ),
    3: const Connection(
      id: 3, areaA: 2, areaB: 4,
      label: 'Pátio',
      hotspotAx: 0.80, hotspotAy: 0.78,
      hotspotBx: 0.20, hotspotBy: 0.15,
    ),
    4: const Connection(
      id: 4, areaA: 3, areaB: 4,
      label: 'Pátio',
      hotspotAx: 0.82, hotspotAy: 0.70,
      hotspotBx: 0.75, hotspotBy: 0.82,
    ),
  };

  final characters = <int, Character>{
    1: const Character(
      id: 1,
      name: 'Ana',
      colorHex: '#e91e8c',
      portraitPath: 'editor/portraits/portrait (1).png',
      areaId: 1,
      bodyPath: 'editor/bodies/body (1).png',
    ),
    2: const Character(
      id: 2,
      name: 'Tiago',
      colorHex: '#f44336',
      portraitPath: 'editor/portraits/portrait (2).png',
      areaId: 2,
      bodyPath: 'editor/bodies/body (2).png',
    ),
    3: const Character(
      id: 3,
      name: 'Sofia',
      colorHex: '#2196f3',
      portraitPath: 'editor/portraits/portrait (3).png',
      areaId: 3,
      bodyPath: 'editor/bodies/body (3).png',
    ),
  };

  // 1 = Apoiou Ana, 2 = Confrontou Tiago, 3 = Falou com Sofia
  // 4 = Tiago arrependido, 5 = Ana recuperou
  final gamestates = <int, StateFlag>{
    1: const StateFlag(id: 1, name: 'Apoiou Ana', value: false),
    2: const StateFlag(id: 2, name: 'Confrontou Tiago', value: false),
    3: const StateFlag(id: 3, name: 'Falou com Sofia', value: false),
    4: const StateFlag(id: 4, name: 'Tiago arrependido', value: false),
    5: const StateFlag(id: 5, name: 'Ana recuperou', value: false),
  };

  final dialogues = <int, Dialogue>{
    1: _buildAnaIntro(),
    2: _buildTiagoConfrontation(),
    3: _buildSofiaWitness(),
    4: _buildAnaFollowUp(),
    5: _buildEnding(),
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

// ---------------------------------------------------------------------------
// Dialogue 1 — Ana intro (auto-triggers in Corredor, priority 10)
// ---------------------------------------------------------------------------
Dialogue _buildAnaIntro() {
  final line1 = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text:
          'Não sei o que fazer... O Tiago partilhou fotos minhas do grupo de WhatsApp nas histórias do Instagram. Toda a gente está a comentar coisas horríveis.',
    ),
  );

  final choice = DialogueNode(
    choice: DialogueChoice(choices: {
      3: 'Isso deve ser devastador. Sinto muito que estejas a passar por isto.',
      6: 'Respira fundo. Vamos pensar juntos no que fazer.',
      0: 'Que absurdo! Isso não pode ficar assim!',
      1: 'Estou preocupado/a contigo. Estás bem?',
    }),
  );

  final anaTriste = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text: 'Obrigada... Às vezes parece que ninguém se importa. O facto de estares aqui já ajuda muito.',
    ),
    branchConsequences: {1: true},
  );
  final playerTriste = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Isso deve ser devastador. Sinto muito que estejas a passar por isto.'));
  playerTriste.nextNode = anaTriste;

  final anaCalmo = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text: 'Tens razão. Preciso de pensar com calma em vez de entrar em pânico. Obrigada por estares aqui.',
    ),
    branchConsequences: {1: true},
  );
  final playerCalmo = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Respira fundo. Vamos pensar juntos no que fazer.'));
  playerCalmo.nextNode = anaCalmo;

  final anaFurioso = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text: 'Também estou furiosa... mas tenho medo que confrontá-lo diretamente piore tudo. Cuidado.',
    ),
  );
  final playerFurioso = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Que absurdo! Isso não pode ficar assim!'));
  playerFurioso.nextNode = anaFurioso;

  final anaNervoso = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text: 'Que te preocupes comigo... significa muito. Obrigada por perguntares.',
    ),
    branchConsequences: {1: true},
  );
  final playerNervoso = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Estou preocupado/a contigo. Estás bem?'));
  playerNervoso.nextNode = anaNervoso;

  choice.children = {
    3: playerTriste,
    6: playerCalmo,
    0: playerFurioso,
    1: playerNervoso,
  };
  line1.nextNode = choice;

  return Dialogue(
    id: 1,
    name: 'Ecrã Partido',
    characterIds: [1],
    parentNode: line1,
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    priority: 10,
    areaId: 1,
    topic:
        'cyberbullying — Tiago shared Ana\'s private photos online without consent and classmates are leaving cruel comments',
  );
}

// ---------------------------------------------------------------------------
// Dialogue 2 — Tiago confrontation (Sala de Aula, priority 5)
// ---------------------------------------------------------------------------
Dialogue _buildTiagoConfrontation() {
  final line1 = DialogueNode(
    line: DialogueLine(
      speakerId: 2,
      text: 'Ah, és o/a amigo/a da Ana? Ela leva tudo demasiado a sério.',
    ),
  );

  final line2 = DialogueNode(
    line: DialogueLine(
      speakerId: 2,
      text:
          'Foi só uma brincadeira. As fotos não eram assim tão privadas. Toda a gente partilha esse tipo de coisa.',
    ),
  );

  final choice = DialogueNode(
    choice: DialogueChoice(choices: {
      0: 'O que fizeste é violência online. Tem consequências reais.',
      6: 'Coloca-te no lugar dela. Como te sentirias se fosse contigo?',
      3: 'A Ana está a sofrer muito por causa do que fizeste.',
      2: 'Podemos resolver isto sem drama — pede desculpa e apaga.',
    }),
  );

  final tiagoFurioso = DialogueNode(
    line: DialogueLine(speakerId: 2, text: 'É só a internet, ninguém leva isso a sério... mas ok, talvez tenha exagerado.'),
    branchConsequences: {2: true},
  );
  final playerFurioso = DialogueNode(line: DialogueLine(speakerId: 0, text: 'O que fizeste é violência online. Tem consequências reais.'));
  playerFurioso.nextNode = tiagoFurioso;

  final tiagoCalmo = DialogueNode(
    line: DialogueLine(speakerId: 2, text: '...Nunca pensei nisso assim. Se fosse comigo... não gostava. Vou apagar e pedir desculpa a ela.'),
    branchConsequences: {2: true, 4: true},
  );
  final playerCalmo = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Coloca-te no lugar dela. Como te sentirias se fosse contigo?'));
  playerCalmo.nextNode = tiagoCalmo;

  final tiagoTriste = DialogueNode(
    line: DialogueLine(speakerId: 2, text: 'Eu não sabia que ela estava assim tão mal. Podia ter pensado melhor antes de agir.'),
    branchConsequences: {2: true},
  );
  final playerTriste = DialogueNode(line: DialogueLine(speakerId: 0, text: 'A Ana está a sofrer muito por causa do que fizeste.'));
  playerTriste.nextNode = tiagoTriste;

  final tiagoAlegre = DialogueNode(
    line: DialogueLine(speakerId: 2, text: 'Sim, sim... deixa estar. Não era para ser grande coisa.'),
    branchConsequences: {2: true},
  );
  final playerAlegre = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Podemos resolver isto sem drama — pede desculpa e apaga.'));
  playerAlegre.nextNode = tiagoAlegre;

  choice.children = {
    0: playerFurioso,
    6: playerCalmo,
    3: playerTriste,
    2: playerAlegre,
  };

  line1.nextNode = line2;
  line2.nextNode = choice;

  return Dialogue(
    id: 2,
    name: 'Frente a Frente',
    characterIds: [2],
    parentNode: line1,
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    priority: 5,
    areaId: 2,
    topic:
        'confronting Tiago about sharing Ana\'s photos without consent and the impact of cyberbullying',
  );
}

// ---------------------------------------------------------------------------
// Dialogue 3 — Sofia witness (Cantina, priority 3)
// ---------------------------------------------------------------------------
Dialogue _buildSofiaWitness() {
  final line1 = DialogueNode(
    line: DialogueLine(
      speakerId: 3,
      text:
          'Já vi o que o Tiago fez à Ana. Toda a gente viu. É horrível.',
    ),
  );

  final line2 = DialogueNode(
    line: DialogueLine(
      speakerId: 3,
      text:
          'Honestamente? Tenho medo de dizer alguma coisa. E se virar contra mim também?',
    ),
  );

  final choice = DialogueNode(
    choice: DialogueChoice(choices: {
      6: 'Percebo o teu medo. Mas o silêncio também é uma escolha.',
      0: 'Tens de falar! Ele não pode continuar a fazer isto.',
      1: 'Também tenho medo. Mas a Ana precisa de testemunhas.',
      7: 'Não precisas de fazer nada sozinha — podemos falar juntos.',
    }),
  );

  final sofiaCalmo = DialogueNode(
    line: DialogueLine(speakerId: 3, text: 'Tens razão... Não me tinha apercebido que o silêncio também é uma forma de concordar. Vou pensar nisso.'),
    branchConsequences: {3: true},
  );
  final playerCalmo = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Percebo o teu medo. Mas o silêncio também é uma escolha.'));
  playerCalmo.nextNode = sofiaCalmo;

  final sofiaFurioso = DialogueNode(
    line: DialogueLine(speakerId: 3, text: 'É fácil dizer isso... mas está bem. Não consigo ficar de braços cruzados enquanto a Ana sofre.'),
    branchConsequences: {3: true},
  );
  final playerFurioso = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Tens de falar! Ele não pode continuar a fazer isto.'));
  playerFurioso.nextNode = sofiaFurioso;

  final sofiaNervoso = DialogueNode(
    line: DialogueLine(speakerId: 3, text: 'Pois... Juntos é mais fácil. Ok, estou contigo.'),
    branchConsequences: {3: true},
  );
  final playerNervoso = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Também tenho medo. Mas a Ana precisa de testemunhas.'));
  playerNervoso.nextNode = sofiaNervoso;

  final sofiaContente = DialogueNode(
    line: DialogueLine(speakerId: 3, text: 'Se não estiver sozinha... talvez consiga. Obrigada.'),
    branchConsequences: {3: true},
  );
  final playerContente = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Não precisas de fazer nada sozinha — podemos falar juntos.'));
  playerContente.nextNode = sofiaContente;

  choice.children = {
    6: playerCalmo,
    0: playerFurioso,
    1: playerNervoso,
    7: playerContente,
  };

  line1.nextNode = line2;
  line2.nextNode = choice;

  return Dialogue(
    id: 3,
    name: 'Testemunha',
    characterIds: [3],
    parentNode: line1,
    singleTrigger: true,
    preconditions: {},
    consequences: {},
    priority: 3,
    areaId: 3,
    topic:
        'Sofia witnessed the cyberbullying but is afraid to speak up about what Tiago did to Ana',
  );
}

// ---------------------------------------------------------------------------
// Dialogue 4 — Ana follow-up (Corredor, requires apoiou Ana + confrontou Tiago)
// ---------------------------------------------------------------------------
Dialogue _buildAnaFollowUp() {
  final line1 = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text: 'Ouvi dizer que falaste com o Tiago.',
    ),
  );

  final line2 = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text:
          'Ainda dói muito. Mas saber que não estou completamente sozinha... faz diferença.',
    ),
  );

  final choice = DialogueNode(
    choice: DialogueChoice(choices: {
      6: 'Devíamos reportar isto à direção. Tens screenshots das publicações?',
      2: 'Vais conseguir superar isto. Estou aqui para ti sempre que precisares.',
      3: 'Lamento muito que isto te tenha acontecido. Não foi nada justo.',
      11: 'Ver-te a lutar por ti própria... dá-me esperança.',
    }),
  );

  final anaCalmo = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Tenho tudo guardado. Vamos lá juntos amanhã falar com a diretora.'),
    branchConsequences: {5: true},
  );
  final playerCalmo = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Devíamos reportar isto à direção. Tens screenshots das publicações?'));
  playerCalmo.nextNode = anaCalmo;

  final anaAlegre = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Obrigada. Às vezes só precisava de saber que havia alguém do meu lado.'),
    branchConsequences: {5: true},
  );
  final playerAlegre = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Vais conseguir superar isto. Estou aqui para ti sempre que precisares.'));
  playerAlegre.nextNode = anaAlegre;

  final anaTriste = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Não foi. Mas ouvir isso de alguém que se importa... ajuda a acreditar nisso.'),
    branchConsequences: {5: true},
  );
  final playerTriste = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Lamento muito que isto te tenha acontecido. Não foi nada justo.'));
  playerTriste.nextNode = anaTriste;

  final anaSatisfeito = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Obrigada. Isso significa muito vindo de ti.'),
    branchConsequences: {5: true},
  );
  final playerSatisfeito = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Ver-te a lutar por ti própria... dá-me esperança.'));
  playerSatisfeito.nextNode = anaSatisfeito;

  choice.children = {
    6: playerCalmo,
    2: playerAlegre,
    3: playerTriste,
    11: playerSatisfeito,
  };

  line1.nextNode = line2;
  line2.nextNode = choice;

  return Dialogue(
    id: 4,
    name: 'Não Estás Sozinha',
    characterIds: [1],
    parentNode: line1,
    singleTrigger: true,
    preconditions: {1: true, 2: true},
    consequences: {},
    priority: 8,
    areaId: 1,
    topic:
        'Ana processing the support she received after the cyberbullying incident with Tiago',
  );
}

// ---------------------------------------------------------------------------
// Dialogue 5 — Ending (Corredor, requires Ana recuperou, isEnding)
// ---------------------------------------------------------------------------
Dialogue _buildEnding() {
  final line1 = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text:
          'Reportámos à diretora. O Tiago foi chamado ao gabinete e os posts foram apagados.',
    ),
  );

  final line2 = DialogueNode(
    line: DialogueLine(
      speakerId: 1,
      text:
          'Ainda vou demorar a recuperar. Mas sei que fiz a coisa certa ao pedir ajuda.',
    ),
  );

  final choice = DialogueNode(
    choice: DialogueChoice(choices: {
      6: 'O importante é que tomámos as medidas certas juntos.',
      7: 'Estou contente que estejas melhor. Mereces.',
      11: 'Esta experiência vai tornar-te mais forte.',
      13: 'Finalmente. Que alívio saber que estás mais segura.',
    }),
  );

  final anaCalmo = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Sim. E da próxima vez que vir alguém a sofrer assim, também vou falar. Obrigada por me mostrares que é possível.'),
  );
  final playerCalmo = DialogueNode(line: DialogueLine(speakerId: 0, text: 'O importante é que tomámos as medidas certas juntos.'));
  playerCalmo.nextNode = anaCalmo;

  final anaContente = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Obrigada. Às vezes precisamos de alguém que acredite em nós para conseguirmos acreditar em nós próprios.'),
  );
  final playerContente = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Estou contente que estejas melhor. Mereces.'));
  playerContente.nextNode = anaContente;

  final anaSatisfeito = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Talvez. Mas não queria ter passado por isto para isso.'),
  );
  final playerSatisfeito = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Esta experiência vai tornar-te mais forte.'));
  playerSatisfeito.nextNode = anaSatisfeito;

  final anaAliviado = DialogueNode(
    line: DialogueLine(speakerId: 1, text: 'Eu também. Muito obrigada. Não me esqueço do que fizeste por mim.'),
  );
  final playerAliviado = DialogueNode(line: DialogueLine(speakerId: 0, text: 'Finalmente. Que alívio saber que estás mais segura.'));
  playerAliviado.nextNode = anaAliviado;

  choice.children = {
    6: playerCalmo,
    7: playerContente,
    11: playerSatisfeito,
    13: playerAliviado,
  };

  line1.nextNode = line2;
  line2.nextNode = choice;

  return Dialogue(
    id: 5,
    name: 'Fim: Nova Página',
    characterIds: [1],
    parentNode: line1,
    singleTrigger: true,
    preconditions: {5: true},
    consequences: {},
    priority: 15,
    areaId: 1,
    isEnding: true,
    topic:
        'Ana reflecting on the resolution of the cyberbullying situation and the outcome of reporting it',
  );
}

