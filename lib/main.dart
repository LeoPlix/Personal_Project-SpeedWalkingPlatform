import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'firebase_options.dart';

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
      title: 'Race Walking System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData) return const MainNavigation();
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- LOGIN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('R.F.E.A. System - LOGIN')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'USER NAME')),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'PASSWORD'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('LOG IN')),
          ],
        ),
      ),
    );
  }
}

// --- NAVEGAÇÃO ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 1; 
  
  // --- ALTERAÇÃO: competitionId agora é um INTEIRO (int) ---
  final int competitionId = 1; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Walking System'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const Center(child: Text('HOME PAGE')),
          NewInfractionScreen(competitionId: competitionId),
          const Center(child: Text('LISTS PAGE')),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'NEW'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'LISTS'),
        ],
      ),
    );
  }
}

// --- ECRÃ DE REGISTO ---
class NewInfractionScreen extends StatefulWidget {
  final int competitionId; // Tipo alterado para int
  const NewInfractionScreen({super.key, required this.competitionId});
  @override
  State<NewInfractionScreen> createState() => _NewInfractionScreenState();
}

class _NewInfractionScreenState extends State<NewInfractionScreen> {
  final _bibCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  @override
  void initState() { super.initState(); _resetTime(); }
  void _resetTime() { _timeCtrl.text = DateFormat('HH:mm:ss').format(DateTime.now()); }

  Future<void> _confirmAndSend(String type, String category) async {
    final String bibValue = _bibCtrl.text.trim();
    final String timeValue = _timeCtrl.text.trim();
    if (bibValue.isEmpty) return;

    String athleteName = "Atleta Desconhecido";
    
    try {
      // Procura o documento pelo ID (Dorsal)
      final athleteDoc = await FirebaseFirestore.instance
          .collection('athletes')
          .doc(bibValue)
          .get();

      if (athleteDoc.exists) {
        final data = athleteDoc.data();
        
        // --- COMPARAÇÃO COMO INT ---
        // Se na Firebase for int64, o Dart lê como int automaticamente.
        if (data?['competition_id'] == widget.competitionId) {
          athleteName = data?['name'] ?? "Sem Nome";
        }
      }
    } catch (e) { 
      print("Erro ao procurar: $e"); 
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Notificação?'),
        content: Text('Atleta: $athleteName\nBib: $bibValue\nHora: $timeValue\nTipo: $category ($type)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('infractions').add({
                'competition_id': widget.competitionId, // Gravado como int
                'judge_id': FirebaseAuth.instance.currentUser?.uid,
                'bib_number': bibValue,
                'athlete_name': athleteName,
                'time': timeValue,
                'infraction_type': type,
                'card_category': category,
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Navigator.pop(context);
                _bibCtrl.clear();
                _resetTime();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SENT!'), backgroundColor: Colors.green));
              }
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(controller: _bibCtrl, decoration: const InputDecoration(labelText: 'BIB NUMBER', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 15),
          TextField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'TIME', border: OutlineInputBorder())),
          const SizedBox(height: 30),
          const Text('YELLOW PADDLES (YP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircleButton(Colors.yellow, Colors.black, 'flexao', '>', 'YP'),
              _buildCircleButton(Colors.yellow, Colors.black, 'contacto', '~', 'YP'),
            ],
          ),
          const SizedBox(height: 40),
          const Text('RED CARDS (RC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircleButton(Colors.red, Colors.white, 'flexao', '>', 'RC'),
              _buildCircleButton(Colors.red, Colors.white, 'contacto', '~', 'RC'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(Color bgColor, Color textColor, String type, String symbol, String category) {
    return GestureDetector(
      onTap: () => _confirmAndSend(type, category),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 4))]),
            child: Center(child: Text(symbol, style: TextStyle(color: textColor, fontSize: 40, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(height: 8),
          Text(type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}