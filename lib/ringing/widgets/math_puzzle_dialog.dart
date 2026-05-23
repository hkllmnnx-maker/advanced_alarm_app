import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/math_puzzle.dart';

/// Modal dialog that forces the user to solve a [MathPuzzle] before
/// dismissing the alarm.
///
/// * Wrong answers generate a fresh puzzle (so the user can't dismiss
///   by guessing repeatedly with the same prompt on screen).
/// * The dialog cannot be dismissed by tapping outside or pressing
///   Back — the user must either solve the puzzle or explicitly cancel
///   through the "Keep ringing" button.
class MathPuzzleDialog extends StatefulWidget {
  const MathPuzzleDialog({super.key, required this.difficulty, this.generator});

  final MathPuzzleDifficulty difficulty;

  /// Injectable generator — defaults to a fresh [MathPuzzleGenerator]
  /// per dialog. Tests pass a seeded one for determinism.
  final MathPuzzleGenerator? generator;

  /// Convenience launcher. Returns `true` if the user solved the puzzle,
  /// `false` if they bailed out via "Keep ringing".
  static Future<bool> show(
    BuildContext context, {
    MathPuzzleDifficulty difficulty = MathPuzzleDifficulty.medium,
    MathPuzzleGenerator? generator,
  }) async {
    final bool? solved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) =>
          MathPuzzleDialog(difficulty: difficulty, generator: generator),
    );
    return solved ?? false;
  }

  @override
  State<MathPuzzleDialog> createState() => _MathPuzzleDialogState();
}

class _MathPuzzleDialogState extends State<MathPuzzleDialog> {
  late final MathPuzzleGenerator _generator;
  late MathPuzzle _puzzle;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _wrongAttempts = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _generator = widget.generator ?? MathPuzzleGenerator();
    _puzzle = _generator.next(difficulty: widget.difficulty);
    // Auto-focus the text field once the dialog is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text;
    if (_puzzle.isCorrect(value)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrongAttempts++;
      _puzzle = _generator.next(difficulty: widget.difficulty);
      _controller.clear();
      _errorText = 'Wrong answer — try the new one ($_wrongAttempts ❌)';
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Solve to dismiss',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Answer the math problem to stop the alarm.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${_puzzle.question} = ?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,6}$')),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '...',
                  errorText: _errorText,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: const Text('Submit'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep ringing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
