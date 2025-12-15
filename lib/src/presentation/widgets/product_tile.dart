import 'package:flutter/material.dart';

class ProductTile extends StatelessWidget {
	final String title;
	final String subtitle;
	final int score;
	final DateTime? timestamp;
	const ProductTile({
		super.key,
		required this.title,
		required this.subtitle,
		required this.score,
		this.timestamp,
	});

	String get _grade {
		if (score >= 85) return 'A';
		if (score >= 70) return 'B';
		if (score >= 55) return 'C';
		if (score >= 40) return 'D';
		return 'E';
	}

	Color get _gradeColor {
		switch (_grade) {
			case 'A': return const Color(0xFF1B8A4E);
			case 'B': return const Color(0xFF7AC547);
			case 'C': return const Color(0xFFF9C74F);
			case 'D': return const Color(0xFFED8936);
			case 'E': return const Color(0xFFE53E3E);
			default: return Colors.grey;
		}
	}

	Color get _gradeBgColor {
		switch (_grade) {
			case 'A': return const Color(0xFFE8F5EE);
			case 'B': return const Color(0xFFF0F9E8);
			case 'C': return const Color(0xFFFFFBEB);
			case 'D': return const Color(0xFFFFF4E6);
			case 'E': return const Color(0xFFFEE9E9);
			default: return Colors.grey.shade100;
		}
	}

	String _formatTimestamp(DateTime dt) {
		final now = DateTime.now();
		final diff = now.difference(dt);
		
		if (diff.inMinutes < 1) {
			return 'Just now';
		} else if (diff.inMinutes < 60) {
			return '${diff.inMinutes}m ago';
		} else if (diff.inHours < 24) {
			return '${diff.inHours}h ago';
		} else if (diff.inDays < 7) {
			return '${diff.inDays}d ago';
		} else {
			// Format as date
			return '${dt.day}/${dt.month}/${dt.year}';
		}
	}

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: _gradeBgColor,
				borderRadius: BorderRadius.circular(12),
				boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: const Offset(0,2))],
			),
			child: Row(
				children: [
					Container(
						height: 52,
						width: 52,
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(10),
							color: _gradeColor.withValues(alpha: 0.15),
						),
						alignment: Alignment.center,
						child: Text(
							_grade,
							style: TextStyle(
								color: _gradeColor,
								fontSize: 24,
								fontWeight: FontWeight.bold,
							),
						),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
								const SizedBox(height: 2),
								Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
								if (timestamp != null) ...[
									const SizedBox(height: 4),
									Row(
										children: [
											Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
											const SizedBox(width: 4),
											Text(
												_formatTimestamp(timestamp!),
												style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
											),
										],
									),
								],
							],
						),
					),
					const SizedBox(width: 8),
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
						decoration: BoxDecoration(
							color: _gradeColor,
							borderRadius: BorderRadius.circular(16),
						),
						child: Text(
							score.toString(),
							style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
						),
					)
				],
			),
		);
	}
}
