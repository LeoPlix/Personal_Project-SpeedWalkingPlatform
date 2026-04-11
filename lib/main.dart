import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  // Garante que o motor do Flutter está iniciado antes de chamar código nativo (Firebase)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase (na prática, precisas do ficheiro firebase_options.dart gerado pelo FlutterFire)
  // await Firebase.initializeApp(); 
  
  runApp(const MarchaApp());
}

class MarchaApp extends StatelessWidget {
  const MarchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Juízes - Marcha',
      theme: ThemeData(primarySwatch: Colors.blue),
      // O StreamBuilder "ouve" o estado do utilizador. 
      // Se fez login, vai para a prova. Se não, vai para o Login.
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const ProvaScreen(competitionId: 'prova_teste_123');
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

// ==========================================
// ECRÃ 1: LOGIN DO JUIZ
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  Future<void> _fazerLogin() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // Se tiver sucesso, o StreamBuilder no main() muda de ecrã automaticamente!
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no login: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso Restrito - Juízes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fazerLogin,
              child: const Text('Entrar na Prova'),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ECRÃ 2: LISTA DE ATLETAS E REGISTO DE FALTAS
// ==========================================
class ProvaScreen extends StatelessWidget {
  final String competitionId;
  const ProvaScreen({super.key, required this.competitionId});

  // Função core: Registar a falta na base de dados
  Future<void> _registarFalta(BuildContext context, String atletaId, String tipoFalta) async {
    final juizAtual = FirebaseAuth.instance.currentUser;
    if (juizAtual == null) return;

    // Criar um novo documento na coleção 'infractions'
    await FirebaseFirestore.instance.collection('infractions').add({
      'competition_id': competitionId,
      'athlete_id': atletaId,
      'judge_id': juizAtual.uid, // Regra de segurança: Só o próprio juiz regista com o seu ID
      'infraction_type': tipoFalta, // Ex: 'flexao_joelho' ou 'contacto_continuo'
      'timestamp': FieldValue.serverTimestamp(), // Fica registado o segundo exato pelo servidor, não pelo telemóvel
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Falta registada com sucesso!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registo em Pista'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(), // Faz logout instantâneo
          )
        ],
      ),
      // O StreamBuilder aqui puxa os atletas em tempo real do Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('athletes')
            .where('competition_id', isEqualTo: competitionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final atletas = snapshot.data!.docs;

          return ListView.builder(
            itemCount: atletas.length,
            itemBuilder: (context, index) {
              final atleta = atletas[index];
              return ListTile(
                leading: CircleAvatar(child: Text(atleta['bib_number'].toString())),
                title: Text(atleta['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botão para falta de Flexão
                    IconButton(
                      icon: const Icon(Icons.warning_amber, color: Colors.orange),
                      onPressed: () => _registarFalta(context, atleta.id, 'flexao'),
                    ),
                    // Botão para falta de Contacto
                    IconButton(
                      icon: const Icon(Icons.do_not_step, color: Colors.red),
                      onPressed: () => _registarFalta(context, atleta.id, 'contacto'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}