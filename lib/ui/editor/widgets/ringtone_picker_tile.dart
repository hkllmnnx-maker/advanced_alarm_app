import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Static catalog of built-in ringtones that the editor can pick from.
///
/// The actual playback is the job of another agent / service; here we
/// only deal with the user-visible name and the stable `id` (which is
/// what gets stored in [Alarm.ringtonePath]).
@immutable
class Ringtone {
  const Ringtone({required this.id, required this.name});

  final String id;
  final String name;

  static const Ringtone defaultRingtone = Ringtone(
    id: 'asset:default',
    name: 'Default',
  );

  static const List<Ringtone> all = <Ringtone>[
    defaultRingtone,
    Ringtone(id: 'asset:classic', name: 'Classic Bell'),
    Ringtone(id: 'asset:digital', name: 'Digital Beep'),
    Ringtone(id: 'asset:morning', name: 'Morning Birds'),
    Ringtone(id: 'asset:gentle', name: 'Gentle Chime'),
    Ringtone(id: 'asset:radar', name: 'Radar'),
    Ringtone(id: 'asset:ocean', name: 'Ocean Waves'),
  ];

  /// Look up a ringtone by id, returning [defaultRingtone] when the
  /// stored id is unknown or empty.
  static Ringtone resolve(String? id) {
    if (id == null || id.isEmpty) return defaultRingtone;
    for (final Ringtone r in all) {
      if (r.id == id) return r;
    }
    return defaultRingtone;
  }
}

/// Tappable tile that opens a modal bottom sheet listing all built-in
/// ringtones. Emits the chosen ringtone id through [onChanged].
class RingtonePickerTile extends StatelessWidget {
  const RingtonePickerTile({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    HapticFeedback.selectionClick();
    final String? chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _RingtoneList(selectedId: selectedId),
          ),
        );
      },
    );
    if (chosen != null && chosen != selectedId) {
      onChanged(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Ringtone current = Ringtone.resolve(selectedId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.music_note_outlined),
      title: const Text('Ringtone'),
      subtitle: Text(current.name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openPicker(context),
    );
  }
}

class _RingtoneList extends StatelessWidget {
  const _RingtoneList({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            'Choose ringtone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: Ringtone.all.length,
            itemBuilder: (BuildContext context, int index) {
              final Ringtone r = Ringtone.all[index];
              final bool isSelected = r.id == selectedId;
              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(r.name),
                onTap: () => Navigator.of(context).pop(r.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
