import 'package:flutter/material.dart';
import '../../utils/theme.dart';
import '../diary/diary_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../scan/scan_screen.dart';
import '../scan/barcode_scan_screen.dart';
import '../diary/add_food_screen.dart';
import '../../models/meal_log.dart';

MealType _inferMealType() {
  final hour = DateTime.now().hour;
  if (hour < 10) return MealType.breakfast;
  if (hour < 15) return MealType.lunch;
  if (hour < 20) return MealType.dinner;
  return MealType.snack;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _screens = const [
    DiaryScreen(),
    DashboardScreen(),
  ];

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScanOptionsSheet(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      floatingActionButton: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showScanOptions,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Color(0xFF003300),
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(
              color: AppTheme.cardLight.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Diary',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanOptionsSheet extends StatelessWidget {
  final BuildContext parentContext;

  const _ScanOptionsSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Food',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            _ScanOption(
              icon: Icons.camera_alt_rounded,
              title: 'AI Scan',
              subtitle: 'Take a photo for instant analysis',
              gradient: AppTheme.primaryGradient,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => ScanScreen(mealType: _inferMealType()),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ScanOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Barcode Scanner',
              subtitle: 'Scan a packaged product',
              gradient: const LinearGradient(
                colors: [AppTheme.proteinColor, Color(0xFF039BE5)],
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => BarcodeScanScreen(mealType: _inferMealType()),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ScanOption(
              icon: Icons.edit_note_rounded,
              title: 'Manual Entry',
              subtitle: 'Enter food details by hand',
              gradient: const LinearGradient(
                colors: [AppTheme.carbColor, Color(0xFFFF8F00)],
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => AddFoodScreen(
                      mealType: _inferMealType(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.onBackground,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onCard,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.onCard),
          ],
        ),
      ),
    );
  }
}
