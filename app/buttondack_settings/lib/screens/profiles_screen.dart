import 'package:flutter/material.dart';
import 'dart:math';
import '../models/config_model.dart';

/// Screen to manage all profiles and their buttons.
class ProfilesScreen extends StatefulWidget {
  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;

  const ProfilesScreen({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  late List<Profile> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = List.from(widget.config.profiles);
  }

  void _save() {
    widget.config.profiles = _profiles;
    widget.onChanged(widget.config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles & Buttons')),
      body: _profiles.isEmpty
          ? const Center(child: Text('No profiles yet. Add one!'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
                return _ProfileCard(
                  profile: profile,
                  onChanged: (_) => _save(),
                  onDelete: () {
                    setState(() {
                      _profiles.removeAt(index);
                    });
                    _save();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _profiles.add(Profile(name: 'New Profile'));
          });
          _save();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Profile'),
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final ValueChanged<Profile> onChanged;
  final VoidCallback onDelete;

  const _ProfileCard({
    required this.profile,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
        title: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Profile Name',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) {
            widget.profile.name = v;
            widget.onChanged(widget.profile);
          },
        ),
        subtitle: Text('${widget.profile.buttons.length} buttons'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: widget.onDelete,
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Buttons:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addButton,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          ...widget.profile.buttons.entries.map((entry) {
            return _ButtonEditor(
              buttonId: entry.key,
              button: entry.value,
              onChanged: (_) => widget.onChanged(widget.profile),
              onDelete: () {
                setState(() {
                  widget.profile.buttons.remove(entry.key);
                });
                widget.onChanged(widget.profile);
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _addButton() {
    final id = 'btn${widget.profile.buttons.length}';
    setState(() {
      widget.profile.buttons[id] = ButtonConfig(name: 'New Button');
    });
    widget.onChanged(widget.profile);
  }
}

class _ButtonEditor extends StatefulWidget {
  final String buttonId;
  final ButtonConfig button;
  final ValueChanged<ButtonConfig> onChanged;
  final VoidCallback onDelete;

  const _ButtonEditor({
    required this.buttonId,
    required this.button,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ButtonEditor> createState() => _ButtonEditorState();
}

class _ButtonEditorState extends State<_ButtonEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _cmdCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.button.name);
    _cmdCtrl = TextEditingController(text: widget.button.command);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Button Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        widget.button.name = v;
                        widget.onChanged(widget.button);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _cmdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'e.g. systemctl reboot -i',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  widget.button.command = v;
                  widget.onChanged(widget.button);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: widget.button.withError,
                    onChanged: (v) {
                      setState(() {
                        widget.button.withError = v ?? false;
                      });
                      widget.onChanged(widget.button);
                    },
                  ),
                  const Text('Show error on failure'),
                  const Spacer(),
                  Text(
                    'ID: ${widget.buttonId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
