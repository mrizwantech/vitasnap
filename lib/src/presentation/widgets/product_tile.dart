import 'package:flutter/material.dart';

class ProductTile extends StatelessWidget {
	final String title;
	final String subtitle;
	final String badgeText;
	const ProductTile({super.key, required this.title, required this.subtitle, this.badgeText = ''});

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: Colors.white,
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
							gradient: const LinearGradient(colors: [Color(0xFFEEF9F2), Color(0xFFDFF1E8)]),
						),
						child: const Icon(Icons.fastfood, color: Color(0xFF0EA76B)),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
								const SizedBox(height: 4),
								Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
							],
						),
					),
					const SizedBox(width: 8),
					CircleAvatar(
						radius: 18,
						backgroundColor: const Color(0xFFEEF9F2),
						child: Text(badgeText, style: const TextStyle(color: Color(0xFF0EA76B), fontWeight: FontWeight.bold)),
					)
				],
			),
		);
	}
}
