import 'package:flutter/material.dart';

import '../services/admin_api.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<ManagedUser> _users = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.api.listUsers();
      if (mounted) setState(() => _users = users);
    } on AdminApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(ManagedUser user, String role) async {
    try {
      await widget.api.setRole(user.studentCode, role);
      if (!mounted) return;
      setState(() {
        _users = [
          for (final current in _users)
            if (current.studentCode == user.studentCode)
              ManagedUser(
                studentCode: current.studentCode,
                name: current.name,
                email: current.email,
                course: current.course,
                role: role,
              )
            else
              current,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Хэрэглэгчийн эрх шинэчлэгдлээ.')),
      );
    } on AdminApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _roleLabel(String role) => switch (role) {
    'teacher' => 'Багш',
    'admin' => 'Сургалтын алба',
    _ => 'Оюутан',
  };

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _users.where((user) {
      return query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.studentCode.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Хэрэглэгчийн эрх'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Нэр, мэйл эсвэл оюутны кодоор хайх',
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Дахин оролдох')),
                      ],
                    ),
                  )
                : visible.isEmpty
                ? const Center(child: Text('Хэрэглэгч олдсонгүй.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final user = visible[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(user.name.isEmpty ? '?' : user.name[0]),
                          ),
                          title: Text(user.name.isEmpty ? user.studentCode : user.name),
                          subtitle: Text(
                            '${user.email}\n${user.studentCode}${user.course == null ? '' : ' • ${user.course}-р курс'}',
                          ),
                          isThreeLine: true,
                          trailing: DropdownButton<String>(
                            value: user.role,
                            onChanged: (role) {
                              if (role != null && role != user.role) {
                                _setRole(user, role);
                              }
                            },
                            items: [
                              for (final role in ['student', 'teacher', 'admin'])
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
