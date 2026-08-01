import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      // Cukup beri ruang agar konten terakhir tidak tertutup bottom nav
      padding: EdgeInsets.only(top: 16, bottom: 16 + bottomPadding),
      child: const Divider(indent: 60, endIndent: 60, thickness: 0.5),
    );
  }
}
