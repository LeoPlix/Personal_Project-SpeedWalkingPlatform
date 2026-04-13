import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; //

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MarchaApp());
}

class MarchaApp extends StatelessWidget {
  const MarchaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const ProvaScreen(competitionId: 'prova_teste_123');
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- ECRÃ DE LOGIN (Simplificado conforme falámos) ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Login Juízes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signInWithEmailAndPassword(
                email: emailCtrl.text.trim(),
                password: passCtrl.text.trim(),
              ),
              child: const Text('Entrar'),
            )
          ],
        ),
      ),
    );
  }
}

// --- ECRÃ DA PROVA (Com Escalão e Formulário) ---
class ProvaScreen extends StatefulWidget {
  final String competitionId;
  const ProvaScreen({super.key, required this.competitionId});
  @override
  State<ProvaScreen> createState() => _ProvaScreenState();
}

class _ProvaScreenState extends State<ProvaScreen> {
  String? _escalao;
  String? _atletaId;
  final _tempoCtrl = TextEditingController();
  final _tipoFaltaCtrl = TextEditingController();

  Future<void> _submeterFalta() async {
    if (_atletaId == null || _tempoCtrl.text.isEmpty || _tipoFaltaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha tudo!')));
      return;
    }

    await FirebaseFirestore.instance.collection('infractions').add({
      'competition_id': widget.competitionId,
      'judge_id': FirebaseAuth.instance.currentUser?.uid,
      'athlete_id': _atletaId,
      'time': _tempoCtrl.text,
      'type': _tipoFaltaCtrl.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _atletaId = null;
      _tempoCtrl.clear();
      _tipoFaltaCtrl.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta Registada!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registo em Pista'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Escolha do Escalão
            DropdownButtonFormField<String>(
              hint: const Text('Escolha o Escalão'),
              value: _escalao,
              items: ['Sub-18', 'Sub-20', 'Seniores'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() { _escalao = val; _atletaId = null; }),
            ),
            const SizedBox(height: 20),
            
            // 2. Escolha do Atleta (Dinâmico do Firestore)
            if (_escalao != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('athletes')
                    .where('category', isEqualTo: _escalao)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return DropdownButtonFormField<String>(
                    hint: const Text('Selecione o Atleta'),
                    value: _atletaId,
                    items: snapshot.data!.docs.map((doc) {
                      return DropdownMenuItem(value: doc.id, child: Text("${doc['bib_number']} - ${doc['name']}"));
                    }).toList(),
                    onChanged: (val) => setState(() => _atletaId = val),
                  );
                },
              ),
            
            const SizedBox(height: 20),
            
            // 3. Tempo e Tipo
            TextField(controller: _tempoCtrl, decoration: const InputDecoration(labelText: 'Tempo da Falta (ex: 01:23:45)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _tipoFaltaCtrl, decoration: const InputDecoration(labelText: 'Tipo de Falta (ex: Flexão)', border: OutlineInputBorder())),
            
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: _submeterFalta, 
              child: const Text('SUBMETER REGISTO'),
            )
          ],
        ),
      ),
    );
  }
}