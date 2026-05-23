import 'package:flutter/material.dart';
import "dart:math";
import "package:file_picker/file_picker.dart";
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
      appBar: AppBar(title: const Text('Profile & Buttons')),
      body: _profiles.isEmpty
          ? const Center(child: Text('Noch keine Profile. Erstelle eins!'))
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
            _profiles.add(Profile(name: 'Neues Profil'));
          });
          _save();
        },
        icon: const Icon(Icons.add),
        label: const Text('Profil hinzufügen'),
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
        leading:
            Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
        title: TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Profilname',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) {
            widget.profile.name = v;
            widget.onChanged(widget.profile);
          },
        ),
        subtitle: Text('${widget.profile.buttons.length} Buttons'),
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
                const Text('Buttons:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addButton,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Hinzufügen'),
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
      widget.profile.buttons[id] = ButtonConfig(name: 'Neuer Button');
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
  late TextEditingController _bgColorCtrl;

  // Vordefinierte Farben zur Auswahl
  static const _presetColors = [
    '#6B4EFF', '#FF4444', '#44BB44', '#4488FF',
    '#FF8844', '#FF44FF', '#44DDDD', '#888888',
    '#1a1a2e', '#16213e', '#282a36', '#2d2d2d',
    '#E91E63', '#9C27B0', '#00BCD4', '#FF5722',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.button.name);
    _cmdCtrl = TextEditingController(text: widget.button.command);
    _bgColorCtrl = TextEditingController(text: widget.button.bgColor);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    _bgColorCtrl.dispose();
    super.dispose();
  }

  Color? _parseColor(String hex) {
    if (hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return null;
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final btn = widget.button;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _parseColor(btn.bgColor) ?? Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    btn.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Name + Delete
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Button-Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        btn.name = v;
                        widget.onChanged(btn);
                        setState(() {}); // refresh preview
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

              // Command
              TextField(
                controller: _cmdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'z.B. systemctl reboot -i',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  btn.command = v;
                  widget.onChanged(btn);
                },
              ),
              const SizedBox(height: 8),

              // Background Image + Color
              Text('Hintergrund',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'bg_image',
                        hintText: 'wallpaper.png',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        btn.bgImage = v;
                        widget.onChanged(btn);
                      },
                      controller: TextEditingController(text: btn.bgImage),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_search, size: 20),
                    tooltip: 'Bild auswählen',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.name.isNotEmpty) {
                        setState(() {
                          btn.bgImage = result.files.single.name;
                        });
                        widget.onChanged(btn);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bgColorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Farbe (Hex)',
                        hintText: '#6B4EFF',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: btn.bgColor.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _parseColor(btn.bgColor) ??
                                      Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                width: 24,
                                height: 24,
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        btn.bgColor = v;
                        widget.onChanged(btn);
                        setState(() {}); // refresh preview + swatch
                      },
                    ),
                  ),
                ],
              ),

              // Color presets
              const SizedBox(height: 6),
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _presetColors.map((hex) {
                    final isSelected = btn.bgColor == hex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          btn.bgColor = hex;
                          _bgColorCtrl.text = hex;
                        });
                        widget.onChanged(btn);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _parseColor(hex),
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Logo Image
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Logo (logo_image)',
                        hintText: 'steam_logo.png',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        btn.logoImage = v;
                        widget.onChanged(btn);
                      },
                      controller: TextEditingController(text: btn.logoImage),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_search, size: 20),
                    tooltip: 'Logo auswählen',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.name.isNotEmpty) {
                        setState(() {
                          btn.logoImage = result.files.single.name;
                        });
                        widget.onChanged(btn);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Options
              Row(
                children: [
                  Checkbox(
                    value: btn.withError,
                    onChanged: (v) {
                      setState(() {
                        btn.withError = v ?? false;
                      });
                      widget.onChanged(btn);
                    },
                  ),
                  const Text('Fehler melden'),
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
