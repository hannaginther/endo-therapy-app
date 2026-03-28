import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/session_record.dart';
import '../providers/session_history_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionHistoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(provider)),
            _ClearAllButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SessionHistoryProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.sessions.isEmpty) {
      return const Center(
        child: Text('No sessions recorded yet.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _SessionCard(session: provider.sessions[index]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionRecord session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(session.startedAt),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Icon(
                  session.wasSuccessful ? Icons.check_circle : Icons.remove_circle_outline,
                  color: session.wasSuccessful ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Pain: '),
                Text(
                  '${session.initialPain} → ${session.finalPain}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: session.painDelta > 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  session.painDelta > 0
                      ? '(−${session.painDelta})'
                      : '(${session.painDelta == 0 ? '±0' : '+${session.painDelta.abs()}'  })',
                  style: TextStyle(
                    fontSize: 12,
                    color: session.painDelta > 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(_exerciseLabel(session.exerciseType),
                    style: const TextStyle(color: Colors.grey)),
                const Text(' · ', style: TextStyle(color: Colors.grey)),
                Text(_formatDuration(session),
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            if (session.safetyEvent != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Safety event',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$day ${dt.day} $month · $time';
  }

  String _exerciseLabel(String type) {
    switch (type) {
      case 'breathing':
        return 'Breathing';
      case 'physical':
        return 'Physical';
      case 'both':
        return 'Both';
      default:
        return 'No exercise';
    }
  }

  String _formatDuration(SessionRecord session) {
    final mins = (session.actualDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (session.actualDurationSeconds % 60).toString().padLeft(2, '0');
    if (session.endedEarly) return 'Ended early ($mins:$secs)';
    return '$mins:$secs';
  }
}

class _ClearAllButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        onPressed: () => _confirmClear(context),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Clear all data'),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all session data?'),
        content: const Text(
          'This will permanently delete all recorded sessions. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SessionHistoryProvider>().clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
  }
}
