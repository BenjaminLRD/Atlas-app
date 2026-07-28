import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../data/profile_provider.dart';
import 'profile_picture.dart';

class CustomTopAppBar extends StatelessWidget {
  final VoidCallback? onProfileUpdated;
  const CustomTopAppBar({super.key, this.onProfileUpdated});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              ).then((_) {
                if (onProfileUpdated != null) {
                  onProfileUpdated!();
                }
              });
            },
            child: Row(
              children: [
                ProfileImage(
                  path: ProfileProvider().profilePic,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Aizawl Gym',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
