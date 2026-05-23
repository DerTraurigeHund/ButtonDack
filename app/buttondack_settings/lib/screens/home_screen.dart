import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/config_service.dart';
import '../services/daemon_engine.dart';
import '../services/action_runner.dart';
import '../models/config_model.dart';
import 'spotify_settings_screen.dart';

/// Main screen: grid editor for ButtonDack.
/// Shows the same button grid as the mobile app with edit capabilities.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _loading = true;
  String? _activeProfileName;
  String? _draggingButtonId;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final cfg = context.read<ConfigService>();
    await cfg.load();
    final engine = context.read<DaemonEngine>();
    await engine.start();
    if (cfg.config.profiles.isNotEmpty) {
      _activeProfileName = cfg.config.profiles.first.name;
    }
    setState(() => _loading = false);
  }

  Profile? get _activeProfile {
    if (_activeProfileName == null) return null;
    final cfg = context.read<ConfigService>().config;
    for (final p in cfg.profiles) {
      if (p.name == _activeProfileName) return p;
    }
    return null;
  }

  void _saveAndSync() {
    final cfg = context.read<ConfigService>();
    cfg.save();
    // Broadcast to WebSocket clients
    final engine = context.read<DaemonEngine>();
    engine.notifyListeners();
  }

  List<Profile> get _profiles => context.read<ConfigService>().config.profiles;

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<DaemonEngine>();
    final cfg = context.watch<ConfigService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ButtonDack'),
        centerTitle: false,
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DaemonStatusChip(engine: engine),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting ButtonDack...'),
                ],
              ),
            )
          : _buildBody(engine, cfg),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Grid'),
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Spotify'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Daemon'),
        ],
      ),
    );
  }

  Widget _buildBody(DaemonEngine engine, ConfigService cfg) {
    switch (_selectedIndex) {
      case 0:
        return _GridEditorTab(
          profiles: _profiles,
          activeProfileName: _activeProfileName,
          onProfileChanged: (name) => setState(() => _activeProfileName = name),
          onSave: _saveAndSync,
        );
      case 1:
        return SpotifySettingsScreen(
          config: cfg.config,
          onChanged: (updatedConfig) {
            cfg.update(updatedConfig);
            engine.restart();
          },
          engine: engine,
        );
      case 2:
        return _DaemonSettingsTab(engine: engine, cfg: cfg);
      default:
        return const SizedBox();
    }
  }
}

// ─── Grid Editor Tab ──────────────────────────────────────────────────────────

class _GridEditorTab extends StatefulWidget {
  final List<Profile> profiles;
  final String? activeProfileName;
  final ValueChanged<String> onProfileChanged;
  final VoidCallback onSave;

  const _GridEditorTab({
    required this.profiles,
    required this.activeProfileName,
    required this.onProfileChanged,
    required this.onSave,
  });

  @override
  State<_GridEditorTab> createState() => _GridEditorTabState();
}

class _GridEditorTabState extends State<_GridEditorTab> {
  String? _draggingButtonId;

  Profile? get profile {
    if (widget.activeProfileName == null) return null;
    for (final p in widget.profiles) {
      if (p.name == widget.activeProfileName) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No profile selected',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addProfile,
              icon: const Icon(Icons.add),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar: Grid size selector + profile switcher
        _buildToolbar(p),
        const Divider(height: 1),
        // Grid
        Expanded(child: _buildGrid(p)),
        // Bottom: Add button FAB area
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addButton(p),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Button'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save & Sync'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(Profile p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Grid size selector
          Text('Grid: ', style: Theme.of(context).textTheme.labelLarge),
          _GridSizeChip(
            label: '3×2',
            selected: p.gridCols == 3 && p.gridRows == 2,
            onTap: () => _setGridSize(p, 3, 2),
          ),
          const SizedBox(width: 4),
          _GridSizeChip(
            label: '6×4',
            selected: p.gridCols == 6 && p.gridRows == 4,
            onTap: () => _setGridSize(p, 6, 4),
          ),
          const SizedBox(width: 4),
          _GridSizeChip(
            label: '9×6',
            selected: p.gridCols == 9 && p.gridRows == 6,
            onTap: () => _setGridSize(p, 9, 6),
          ),
          const Spacer(),
          // Profile switcher
          _ProfileSwitcherButton(
            profiles: widget.profiles,
            activeProfileName: widget.activeProfileName,
            onChanged: widget.onProfileChanged,
            onAddProfile: _addProfile,
          ),
        ],
      ),
    );
  }

  void _setGridSize(Profile p, int cols, int rows) {
    setState(() {
      p.gridCols = cols;
      p.gridRows = rows;
    });
    widget.onSave();
  }

  void _addProfile() {
    final svc = context.read<ConfigService>();
    final cfg = svc.config;
    final name = 'Profile ${cfg.profiles.length + 1}';
    cfg.profiles.add(Profile(name: name, gridCols: 3, gridRows: 2));
    widget.onProfileChanged(name);
    svc.save();
  }

  void _addButton(Profile p) {
    // Find next available position
    int row = 0;
    int col = 0;
    bool found;
    for (int r = 0; r < p.gridRows; r++) {
      found = false;
      for (int c = 0; c < p.gridCols; c++) {
        final occupied = p.buttons.values.any((b) => b.row == r && b.col == c);
        if (!occupied) {
          row = r;
          col = c;
          found = true;
          break;
        }
      }
      if (found) break;
    }

    final id = 'btn${DateTime.now().millisecondsSinceEpoch}';
    p.buttons[id] = ButtonConfig(
      name: 'New Button',
      type: 'command',
      row: row,
      col: col,
      colSpan: 1,
      rowSpan: 1,
    );

    setState(() {});
    widget.onSave();
  }

  Widget _buildGrid(Profile p) {
    final cellWidth = 100.0;
    final cellHeight = 100.0;
    final totalWidth = p.gridCols * cellWidth + (p.gridCols - 1) * 6;
    final totalHeight = p.gridRows * cellHeight + (p.gridRows - 1) * 6;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            children: [
              // Grid background
              for (int _r = 0; _r < p.gridRows; _r++)
                for (int _c = 0; _c < p.gridCols; _c++)
                  Positioned(
                    left: _c * (cellWidth + 6),
                    top: _r * (cellHeight + 6),
                    width: cellWidth,
                    height: cellHeight,
                    child: DragTarget<MapEntry<String, ButtonConfig>>(
                      onAcceptWithDetails: (details) {
                        _handleDrop(p, details.data, _r, _c);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          decoration: BoxDecoration(
                            color: candidateData.isNotEmpty
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: candidateData.isNotEmpty
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.15),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

              // Buttons
              ...p.buttons.entries.map((entry) {
                final btn = entry.value;
                final isDragging = _draggingButtonId == entry.key;
                if (isDragging) return const SizedBox.shrink();

                return Positioned(
                  left: btn.col * (cellWidth + 6),
                  top: btn.row * (cellHeight + 6),
                  width: btn.colSpan * cellWidth + (btn.colSpan - 1) * 6,
                  height: btn.rowSpan * cellHeight + (btn.rowSpan - 1) * 6,
                  child: LongPressDraggable<MapEntry<String, ButtonConfig>>(
                    data: entry,
                    feedback: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: cellWidth,
                        height: cellHeight,
                        child: _buildButtonPreview(entry, cellWidth, cellHeight),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildButtonPreview(entry, cellWidth, cellHeight),
                    ),
                    onDragStarted: () {
                      setState(() => _draggingButtonId = entry.key);
                    },
                    onDragEnd: (_) {
                      setState(() => _draggingButtonId = null);
                    },
                    child: _GridButton(
                      entry: entry,
                      cellWidth: cellWidth,
                      cellHeight: cellHeight,
                      onTap: () => _editButton(p, entry),
                      onLongPress: () => _deleteButton(p, entry.key),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDrop(Profile p, MapEntry<String, ButtonConfig> dragged, int targetRow, int targetCol) {
    // Check if there's a button at the target position
    final targetEntry = p.buttons.entries.firstWhere(
      (e) => e.value.row == targetRow && e.value.col == targetCol,
      orElse: () => MapEntry('', ButtonConfig()),
    );

    if (targetEntry.key.isEmpty) {
      // Move to empty cell
      dragged.value.row = targetRow;
      dragged.value.col = targetCol;
    } else {
      // Swap positions
      final tmpRow = dragged.value.row;
      final tmpCol = dragged.value.col;
      dragged.value.row = targetEntry.value.row;
      dragged.value.col = targetEntry.value.col;
      targetEntry.value.row = tmpRow;
      targetEntry.value.col = tmpCol;
    }

    setState(() {});
    widget.onSave();
  }

  Widget _buildButtonPreview(MapEntry<String, ButtonConfig> entry, double w, double h) {
    return _buildButtonWidget(entry.value, w, h);
  }

  Widget _buildButtonWidget(ButtonConfig btn, double w, double h) {
    Color? bgColor;
    if (btn.bgColor.isNotEmpty) {
      final hex = btn.bgColor.replaceFirst('#', '');
      if (hex.length == 6) {
        bgColor = Color(int.parse('FF$hex', radix: 16));
      }
    }

    final isSpotify = btn.type == 'spotify';

    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? (isSpotify ? const Color(0xFF1DB954) : Colors.grey.shade700),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background image
          if (btn.bgImage.isNotEmpty)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/backgrounds/${btn.bgImage}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          // Content
          Center(
            child: btn.logoImage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/logos/${btn.logoImage}',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        btn.name.isNotEmpty ? btn.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSpotify)
                          const Icon(Icons.music_note, color: Colors.white, size: 20),
                        if (btn.name.isNotEmpty)
                          Text(
                            btn.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
          ),
          // Type badge
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isSpotify ? const Color(0xFF1DB954) : Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isSpotify ? 'SP' : btn.type[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Span indicator
          if (btn.colSpan > 1 || btn.rowSpan > 1)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${btn.colSpan}×${btn.rowSpan}',
                  style: const TextStyle(color: Colors.white70, fontSize: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editButton(Profile p, MapEntry<String, ButtonConfig> entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ButtonEditSheet(
        buttonId: entry.key,
        button: entry.value,
        profile: p,
        onChanged: () {
          setState(() {});
          widget.onSave();
        },
      ),
    );
  }

  void _deleteButton(Profile p, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Button'),
        content: Text('Delete "${p.buttons[id]?.name ?? 'unknown'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              p.buttons.remove(id);
              setState(() {});
              widget.onSave();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Button Edit Sheet ────────────────────────────────────────────────────────

class _ButtonEditSheet extends StatefulWidget {
  final String buttonId;
  final ButtonConfig button;
  final Profile profile;
  final VoidCallback onChanged;

  const _ButtonEditSheet({
    required this.buttonId,
    required this.button,
    required this.profile,
    required this.onChanged,
  });

  @override
  State<_ButtonEditSheet> createState() => _ButtonEditSheetState();
}

class _ButtonEditSheetState extends State<_ButtonEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _cmdCtrl;
  late TextEditingController _bgColorCtrl;
  String _selectedType = 'command';
  final List<TextEditingController> _hotkeyCtrls = [];

  static const _presetColors = [
    '#6B4EFF', '#FF4444', '#44BB44', '#4488FF',
    '#FF8844', '#FF44FF', '#44DDDD', '#888888',
    '#1a1a2e', '#16213e', '#282a36', '#2d2d2d',
    '#E91E63', '#9C27B0', '#00BCD4', '#FF5722',
    '#1DB954', '#FF6B35', '#0047AB', '#8B4513',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.button.name);
    _cmdCtrl = TextEditingController(text: widget.button.command);
    _bgColorCtrl = TextEditingController(text: widget.button.bgColor);
    _selectedType = widget.button.type;

    // Build hotkey controllers
    for (final hk in widget.button.hotkeys) {
      _hotkeyCtrls.add(TextEditingController(text: hk.join('+')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    _bgColorCtrl.dispose();
    for (final c in _hotkeyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Color? _parseColor(String hex) {
    if (hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return null;
    return Color(int.parse('FF$h', radix: 16));
  }

  /// Copy a picked file to ~/.config/buttondack/images/
  Future<String?> _copyToImages(String sourcePath) async {
    try {
      final file = File(sourcePath);
      final name = file.uri.pathSegments.last;
      final home = Platform.environment['HOME'] ?? '/tmp';
      final imagesDir = Directory('$home/.config/buttondack/images/');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      await file.copy('$home/.config/buttondack/images/$name');
      return name;
    } catch (e) {
      debugPrint('[Editor] Copy image failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final btn = widget.button;
    final isSpotify = _selectedType == 'spotify';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Edit Button: ${btn.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Button Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  btn.name = v;
                  widget.onChanged();
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),

              // Type selection
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'command', label: Text('Command'), icon: Icon(Icons.terminal)),
                  ButtonSegment(value: 'hotkey', label: Text('Hotkey'), icon: Icon(Icons.keyboard)),
                  ButtonSegment(value: 'spotify', label: Text('Spotify'), icon: Icon(Icons.music_note)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  setState(() => _selectedType = set.first);
                  btn.type = set.first;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 16),

              // Type-specific fields
              if (!isSpotify) ...[
                // Command
                TextField(
                  controller: _cmdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Shell Command',
                    hintText: 'e.g. systemctl reboot -i',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    btn.command = v;
                    widget.onChanged();
                  },
                ),
                const SizedBox(height: 12),

                // Hotkeys
                Text('Hotkeys',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                ..._hotkeyCtrls.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: 'Hotkey ${i + 1}',
                              hintText: 'ctrl+alt+t',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              _updateHotkeys();
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _hotkeyCtrls[i].dispose();
                              _hotkeyCtrls.removeAt(i);
                            });
                            _updateHotkeys();
                          },
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hotkeyCtrls.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Hotkey'),
                ),
              ],

              if (isSpotify) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Color(0xFF1DB954), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Spotify buttons auto-render Play/Pause, Next, Previous, Stop controls. Command and hotkeys are ignored.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(),

              // Background Image
              Text('Background Image',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'bgImage filename',
                        hintText: 'my_wallpaper.png',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        btn.bgImage = v;
                        widget.onChanged();
                      },
                      controller: TextEditingController(text: btn.bgImage),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Pick image file',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        final name = await _copyToImages(result.files.single.path!);
                        if (name != null) {
                          btn.bgImage = name;
                          widget.onChanged();
                          setState(() {});
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Logo Image
              Text('Logo Image',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'logoImage filename',
                        hintText: 'steam_logo.png',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        btn.logoImage = v;
                        widget.onChanged();
                      },
                      controller: TextEditingController(text: btn.logoImage),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    tooltip: 'Pick logo file',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );
                      if (result != null && result.files.single.path != null) {
                        final name = await _copyToImages(result.files.single.path!);
                        if (name != null) {
                          btn.logoImage = name;
                          widget.onChanged();
                          setState(() {});
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Background Color
              Text('Background Color',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bgColorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Hex Color',
                        hintText: '#6B4EFF',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: btn.bgColor.isNotEmpty
                            ? Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _parseColor(btn.bgColor) ?? Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                width: 24,
                                height: 24,
                              )
                            : null,
                      ),
                      onChanged: (v) {
                        btn.bgColor = v;
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Color presets
              SizedBox(
                height: 32,
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
                        widget.onChanged();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
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
              const SizedBox(height: 16),

              // Column Span slider
              Text('Column Span: ${btn.colSpan}',
                  style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: btn.colSpan.toDouble(),
                min: 1,
                max: widget.profile.gridCols.toDouble(),
                divisions: widget.profile.gridCols - 1,
                label: '${btn.colSpan}',
                onChanged: (v) {
                  setState(() {
                    btn.colSpan = v.round();
                  });
                  widget.onChanged();
                },
              ),

              const SizedBox(height: 12),

              // Options
              CheckboxListTile(
                value: btn.withError,
                onChanged: (v) {
                  setState(() {
                    btn.withError = v ?? false;
                  });
                  widget.onChanged();
                },
                title: const Text('Report errors'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateHotkeys() {
    widget.button.hotkeys = _hotkeyCtrls
        .map((c) => c.text.split('+').map((s) => s.trim()).where((s) => s.isNotEmpty).toList())
        .where((l) => l.isNotEmpty)
        .toList();
    widget.onChanged();
  }
}

// ─── Grid Button Widget ────────────────────────────────────────────────────────

class _GridButton extends StatelessWidget {
  final MapEntry<String, ButtonConfig> entry;
  final double cellWidth;
  final double cellHeight;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridButton({
    required this.entry,
    required this.cellWidth,
    required this.cellHeight,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final btn = entry.value;
    Color? bgColor;
    if (btn.bgColor.isNotEmpty) {
      final hex = btn.bgColor.replaceFirst('#', '');
      if (hex.length == 6) {
        bgColor = Color(int.parse('FF$hex', radix: 16));
      }
    }

    final isSpotify = btn.type == 'spotify';

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor ?? (isSpotify ? const Color(0xFF1DB954) : Colors.grey.shade700),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (btn.bgImage.isNotEmpty)
              Positioned.fill(
                child: Image.asset(
                  'assets/backgrounds/${btn.bgImage}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Content
            Center(
              child: btn.logoImage.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/logos/${btn.logoImage}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          btn.name.isNotEmpty ? btn.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSpotify) const Icon(Icons.music_note, color: Colors.white, size: 24),
                          if (btn.name.isNotEmpty)
                            Text(
                              btn.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
            ),
            // Type badge
            Positioned(top: 4, right: 4, child: _badge(btn.type)),
            if (btn.colSpan > 1 || btn.rowSpan > 1)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(3)),
                  child: Text('${btn.colSpan}×${btn.rowSpan}', style: const TextStyle(color: Colors.white70, fontSize: 8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: type == 'spotify' ? const Color(0xFF1DB954) : Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type == 'spotify' ? 'SP' : type[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────────

class _GridSizeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GridSizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _ProfileSwitcherButton extends StatelessWidget {
  final List<Profile> profiles;
  final String? activeProfileName;
  final ValueChanged<String> onChanged;
  final VoidCallback onAddProfile;

  const _ProfileSwitcherButton({
    required this.profiles,
    required this.activeProfileName,
    required this.onChanged,
    required this.onAddProfile,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.swap_horiz,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: 'Switch profile',
      onSelected: (name) {
        if (name == '__add__') {
          onAddProfile();
        } else {
          onChanged(name);
        }
      },
      itemBuilder: (ctx) => [
        ...profiles.map((p) => PopupMenuItem<String>(
              value: p.name,
              child: Row(
                children: [
                  Icon(
                    Icons.folder,
                    size: 18,
                    color: p.name == activeProfileName
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: p.name == activeProfileName ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (p.name == activeProfileName) ...[
                    const Spacer(),
                    Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
                  ],
                ],
              ),
            )),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__add__',
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('New Profile'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Daemon Status & Tab (unchanged) ───────────────────────────────────────────

/// Daemon status badge in the app bar.
class _DaemonStatusChip extends StatelessWidget {
  final DaemonEngine engine;
  const _DaemonStatusChip({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: engine.running
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: engine.running
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: engine.running ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            engine.running ? 'Port ${engine.port}' : 'Stopped',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: engine.running ? Colors.green : Colors.red.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

/// Daemon control tab.
class _DaemonSettingsTab extends StatelessWidget {
  final DaemonEngine engine;
  final ConfigService cfg;

  const _DaemonSettingsTab({required this.engine, required this.cfg});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud,
                      color: engine.running ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            engine.running ? 'Daemon Running' : 'Daemon Stopped',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            engine.running
                                ? '${engine.clientCount} client${engine.clientCount == 1 ? '' : 's'} connected'
                                : 'The WebSocket server is not running',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: engine.running,
                      onChanged: (v) {
                        if (v) {
                          engine.start();
                        } else {
                          engine.stop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Spotify now playing
        if (engine.currentTrack != null && !engine.currentTrack!.isEmpty)
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: engine.currentTrack!.albumArtUrl.isNotEmpty
                    ? Image.network(
                        engine.currentTrack!.albumArtUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.music_note),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.music_note),
                      ),
              ),
              title: Text(
                engine.currentTrack!.trackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                engine.currentTrack!.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(
                engine.currentTrack!.isPlaying
                    ? Icons.play_circle_fill
                    : Icons.pause_circle_outline,
                color: const Color(0xFF1DB954),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Connection info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connection',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _infoRow('Status', engine.running ? 'Running' : 'Stopped', context),
                _infoRow('Host', engine.host, context),
                _infoRow('Port', '${engine.port}', context),
                _infoRow('Clients', '${engine.clientCount}', context),
                _infoRow(
                    'Spotify', cfg.config.spotify.enabled ? 'Enabled' : 'Disabled', context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: engine.running
                            ? () => engine.restart()
                            : () => engine.start(),
                        icon: Icon(engine.running ? Icons.restart_alt : Icons.play_arrow),
                        label: Text(engine.running ? 'Restart' : 'Start'),
                      ),
                    ),
                    if (engine.running) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => engine.stop(),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Config info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuration',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _infoRow('Profiles', '${cfg.config.profiles.length}', context),
                _infoRow(
                    'Total Buttons',
                    '${cfg.config.profiles.fold<int>(0, (sum, p) => sum + p.buttons.length)}', context),
                _infoRow('Config Path', cfg.configPath, context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7))),
          ),
        ],
      ),
    );
  }
}
