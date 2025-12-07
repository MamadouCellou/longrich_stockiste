import 'package:flutter/material.dart';

const int PV_D2 = 1680;
const int PV_D3 = 3600;
const int PV_D4 = 15000;

class GradeCheckerApp extends StatefulWidget {
  const GradeCheckerApp({super.key});

  @override
  State<GradeCheckerApp> createState() => _GradeCheckerAppState();
}

class _GradeCheckerAppState extends State<GradeCheckerApp> {
  @override
  Widget build(BuildContext context) {
    return GradeCheckerPage()
    ;
  }
}

class CandidateD3 {
  final TextEditingController candidatePv = TextEditingController();
  final TextEditingController sub1Pv = TextEditingController();
  final TextEditingController sub2Pv = TextEditingController();

  void dispose() {
    candidatePv.dispose();
    sub1Pv.dispose();
    sub2Pv.dispose();
  }
}

class GradeCheckerPage extends StatefulWidget {
  const GradeCheckerPage({super.key});

  @override
  State<GradeCheckerPage> createState() => _GradeCheckerPageState();
}

class _GradeCheckerPageState extends State<GradeCheckerPage> {
  String selectedGrade = 'D2';
  final mainPvController = TextEditingController();

  // Pour D3
  final branch1TopController = TextEditingController();
  final branch2TopController = TextEditingController();

  // Pour D4 (un seul candidat par branche)
  final branch1Candidate = CandidateD3();
  final branch2Candidate = CandidateD3();

  String resultText = '';

  @override
  void dispose() {
    mainPvController.dispose();
    branch1TopController.dispose();
    branch2TopController.dispose();
    branch1Candidate.dispose();
    branch2Candidate.dispose();
    super.dispose();
  }

  int parsePv(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  bool isD2FromPv(int pv) => pv >= PV_D2;
  bool isD3FromPvAndChildren(int pv, int child1, int child2) {
    return pv >= PV_D3 && isD2FromPv(child1) && isD2FromPv(child2);
  }

  void verify() {
    setState(() {
      resultText = '';
      if (selectedGrade == 'D2') {
        final pv = parsePv(mainPvController.text);
        if (isD2FromPv(pv)) {
          resultText = '✅ D2 atteint (PV = $pv, seuil = $PV_D2).';
        } else {
          final missing = PV_D2 - pv;
          resultText =
          '❌ Pas encore D2. PV actuel = $pv. Il manque $missing PV pour atteindre D2 (1680).';
        }
      } else if (selectedGrade == 'D3') {
        final mainPv = parsePv(mainPvController.text);
        final b1 = parsePv(branch1TopController.text);
        final b2 = parsePv(branch2TopController.text);

        final mainOk = mainPv >= PV_D3;
        final b1Ok = isD2FromPv(b1);
        final b2Ok = isD2FromPv(b2);

        final missingParts = <String>[];
        if (!mainOk) {
          missingParts.add(
              'Compte principal: il manque ${PV_D3 - mainPv} PV (seuil $PV_D3).');
        }
        if (!b1Ok) {
          missingParts.add(
              'Branche 1 (compte en tête): PV=$b1, il manque ${PV_D2 - b1} PV pour D2.');
        }
        if (!b2Ok) {
          missingParts.add(
              'Branche 2 (compte en tête): PV=$b2, il manque ${PV_D2 - b2} PV pour D2.');
        }

        if (mainOk && b1Ok && b2Ok) {
          resultText =
          '✅ D3 atteint !\nCompte principal PV=$mainPv, b1 PV=$b1 (D2), b2 PV=$b2 (D2).';
        } else {
          resultText = '❌ D3 non atteint.\n' + missingParts.join('\n');
        }
      } else if (selectedGrade == 'D4') {
        final mainPv = parsePv(mainPvController.text);

        // Vérif candidat D3 de la branche 1
        final c1pv = parsePv(branch1Candidate.candidatePv.text);
        final c1s1 = parsePv(branch1Candidate.sub1Pv.text);
        final c1s2 = parsePv(branch1Candidate.sub2Pv.text);
        final b1Ok = isD3FromPvAndChildren(c1pv, c1s1, c1s2);

        // Vérif candidat D3 de la branche 2
        final c2pv = parsePv(branch2Candidate.candidatePv.text);
        final c2s1 = parsePv(branch2Candidate.sub1Pv.text);
        final c2s2 = parsePv(branch2Candidate.sub2Pv.text);
        final b2Ok = isD3FromPvAndChildren(c2pv, c2s1, c2s2);

        final mainOk = mainPv >= PV_D4;

        if (mainOk && b1Ok && b2Ok) {
          resultText =
          '✅ D4 atteint !\nCompte principal PV=$mainPv (≥ $PV_D4).\nBranche 1: candidat D3 valide.\nBranche 2: candidat D3 valide.';
        } else {
          final missing = <String>[];
          if (!mainOk) {
            missing.add(
                'Compte principal: PV=$mainPv, il manque ${PV_D4 - mainPv} PV pour atteindre $PV_D4.');
          }
          if (!b1Ok) {
            missing.add(
                'Branche 1: candidat D3 invalide (PV=$c1pv, sous1=$c1s1, sous2=$c1s2).');
          }
          if (!b2Ok) {
            missing.add(
                'Branche 2: candidat D3 invalide (PV=$c2pv, sous1=$c2s1, sous2=$c2s2).');
          }
          resultText = '❌ D4 non atteint.\n' + missing.join('\n');
        }
      }
    });
  }

  Widget _buildD2Inputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PV du compte à vérifier (D2)'),
        const SizedBox(height: 8),
        TextField(
          controller: mainPvController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PV',
            hintText: 'Ex: 1800',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => verify(),
        ),
      ],
    );
  }

  Widget _buildD3Inputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PV du compte principal (doit être ≥ 3600)'),
        const SizedBox(height: 8),
        TextField(
          controller: mainPvController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'PV compte principal', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const Text(
            'PV des comptes en tête des deux branches (doivent être D2 ≥ 1680)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: branch1TopController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Branche 1 - top PV',
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: branch2TopController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Branche 2 - top PV',
                    border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: verify,
          icon: const Icon(Icons.check),
          label: const Text('Vérifier D3'),
        ),
      ],
    );
  }

  Widget _buildCandidateCard(CandidateD3 c) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            TextField(
              controller: c.candidatePv,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'PV du candidat (≥ 3600)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: c.sub1Pv,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Sous-compte 1 PV (≥1680)',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: c.sub2Pv,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Sous-compte 2 PV (≥1680)',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildD4Inputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PV du compte principal (doit être ≥ 15000)'),
        const SizedBox(height: 8),
        TextField(
          controller: mainPvController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'PV compte principal', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('Branche 1 — Candidat D3'),
        _buildCandidateCard(branch1Candidate),
        const SizedBox(height: 16),
        const Text('Branche 2 — Candidat D3'),
        _buildCandidateCard(branch2Candidate),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: verify,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Vérifier D4'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputSection = () {
      if (selectedGrade == 'D2') return _buildD2Inputs();
      if (selectedGrade == 'D3') return _buildD3Inputs();
      return _buildD4Inputs();
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérificateur de Grade Longrich', style: TextStyle(fontSize: 20),),
        centerTitle: true,
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Grade à vérifier:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedGrade,
                    items: const [
                      DropdownMenuItem(value: 'D2', child: Text('D2')),
                      DropdownMenuItem(value: 'D3', child: Text('D3')),
                      DropdownMenuItem(value: 'D4', child: Text('D4')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        selectedGrade = v;
                        resultText = '';
                      });
                    },
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        mainPvController.clear();
                        branch1TopController.clear();
                        branch2TopController.clear();
                        branch1Candidate.candidatePv.clear();
                        branch1Candidate.sub1Pv.clear();
                        branch1Candidate.sub2Pv.clear();
                        branch2Candidate.candidatePv.clear();
                        branch2Candidate.sub1Pv.clear();
                        branch2Candidate.sub2Pv.clear();
                        resultText = '';
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              inputSection,
              const SizedBox(height: 18),
              if (resultText.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SelectableText(resultText),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'Astuces :\n- Pour D3 tu saisis les PV des comptes en tête des 2 branches.\n- Pour D4 tu saisis les PV totaux du compte principal, et les PV des comptes qui doivent devenir D3 dans les deux branches.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
