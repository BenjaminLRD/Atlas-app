import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/coach_note.dart';
import '../providers/fitness_provider.dart';

/// Trainer view of an assigned member's profile, fitness stats, AI summary, and coach notes timeline.
class MemberDetailScreen extends StatefulWidget {
  final AppUser member;

  const MemberDetailScreen({
    super.key,
    required this.member,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  List<CoachNote> _notes = [];
  bool _isLoadingNotes = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await FitnessProvider.instance.getMemberCoachNotes(widget.member.id);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoadingNotes = false;
      });
    }
  }

  void _showAddNoteDialog(BuildContext context) {
    final noteController = TextEditingController();
    String selectedCategory = 'training';

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Add Coach Note',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF2D2B55),
                    style: const TextStyle(color: Colors.white),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'training', child: Text('Training & Form')),
                      DropdownMenuItem(value: 'nutrition', child: Text('Nutrition & Macros')),
                      DropdownMenuItem(value: 'injury', child: Text('Injury / Rehab')),
                      DropdownMenuItem(value: 'general', child: Text('General Advice')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter observation, feedback, or plan adjustment...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (noteController.text.trim().isEmpty) return;
                    final text = noteController.text.trim();
                    Navigator.pop(context);

                    await FitnessProvider.instance.addCoachNote(
                      memberId: widget.member.id,
                      noteText: text,
                      category: selectedCategory,
                    );
                    _loadNotes();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Note'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final contextSnapshot = provider.buildFitnessContext();
    final summary = provider.generateMemberAISummary(
      memberContext: contextSnapshot,
      memberName: widget.member.displayName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: Text(
          widget.member.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Stats Header Card
            _buildAthleteCard(widget.member),
            const SizedBox(height: 20),

            // AI Coach Insights Card
            _buildAISummaryCard(summary),
            const SizedBox(height: 24),

            // Coach Notes Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coach Notes Timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => _showAddNoteDialog(context),
                  icon: const Icon(Icons.add_comment_rounded, color: Color(0xFF6C5CE7)),
                  tooltip: 'Add Coach Note',
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoadingNotes)
              const Center(child: CircularProgressIndicator())
            else if (_notes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No notes recorded for this athlete yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              ..._notes.map(_buildNoteCard),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteCard(AppUser member) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF00B894).withValues(alpha: 0.2),
            child: Text(
              member.displayName.isNotEmpty ? member.displayName[0] : 'A',
              style: const TextStyle(
                color: Color(0xFF00B894),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryCard(dynamic summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2B55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              Text(
                summary.readinessStatus,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.summaryText,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(CoachNote note) {
    Color categoryColor;
    switch (note.category) {
      case 'training':
        categoryColor = const Color(0xFF6C5CE7);
        break;
      case 'nutrition':
        categoryColor = const Color(0xFF00B894);
        break;
      case 'injury':
        categoryColor = const Color(0xFFFF7675);
        break;
      default:
        categoryColor = const Color(0xFF0984E3);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note.category.toUpperCase(),
                  style: TextStyle(
                    color: categoryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatDate(note.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note.noteText,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
