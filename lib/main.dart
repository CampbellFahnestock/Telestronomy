import 'package:flutter/material.dart';

void main() {
  runApp(const TelestronomyApp());
}

class TelestronomyApp extends StatelessWidget {
  const TelestronomyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF050C14),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9BC6FF),
        brightness: Brightness.dark,
        primary: const Color(0xFF9BC6FF),
        secondary: const Color(0xFF1D3447),
        tertiary: const Color(0xFF2C4B67),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: const Color(0xFFEAF3FF),
        displayColor: const Color(0xFFEAF3FF),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF0D2438),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A1F30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF3E5C72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF3E5C72)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: const Color(0xFF9BC6FF).withOpacity(0.9)),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Telestronomy',
      theme: base.copyWith(
        textTheme: base.textTheme.copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    TelescopeDashboardPage(),
    ScopeyPage(),
    AccountSettingsPage(),
    PlateSolveWorkflowPage(),
  ];

  final List<String> _titles = [
    'Telestronomy',
    'Scopey',
    'Account settings',
    'Plate solve workflow',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050C14),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF0D1014),
          elevation: 0,
          toolbarHeight: 100,
          titleSpacing: 0,
          title: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                const SizedBox(width: 12),
                if (_index != 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: () => setState(() => _index = 0),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 30),
                      color: const Color(0xFFEAF3FF),
                      splashRadius: 24,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_rounded, size: 32),
                      color: const Color(0xFFEAF3FF),
                      splashRadius: 24,
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: Text(
                      _titles[_index],
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 39,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                ),
                if (_index == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Row(
                      children: const [
                        Icon(Icons.arrow_outward_rounded, size: 31),
                        SizedBox(width: 12),
                        Icon(Icons.auto_awesome_rounded, size: 31),
                      ],
                    ),
                  )
                else if (_index == 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.lock_outline_rounded, size: 30),
                      color: const Color(0xFFEAF3FF),
                      splashRadius: 24,
                    ),
                  )
                else
                  const SizedBox(width: 54),
              ],
            ),
          ),
        ),
      ),
      body: _pages[_index],
    );
  }
}

class TelescopeDashboardPage extends StatelessWidget {
  const TelescopeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _InfoCard(
            title: 'Current telescope state',
            rows: const [
              _InfoRow(label: 'Altitude', value: '38.0°'),
              _InfoRow(label: 'Azimuth', value: '105.0°'),
            ],
          ),
          const SizedBox(height: 22),
          _InfoCard(
            title: 'Target position',
            rows: const [
              _InfoRow(label: 'Altitude', value: '48.0°'),
              _InfoRow(label: 'Azimuth', value: '96.0°'),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0D2438),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF234765), width: 1.2),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guidance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Move telescope UP',
                  style: TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.8),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Move telescope LEFT',
                  style: TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.8),
                ),
                const SizedBox(height: 24),
                Text(
                  'Adjust and continue tracking.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: const Color(0xFFE8C94B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Alignment error: 13.45°',
                  style: TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.7),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 14,
                      value: 0.68,
                      backgroundColor: const Color(0xFF647C8F),
                      color: const Color(0xFF98C2F7),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9BC6FF),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Open plate solve workflow',
                      style: TextStyle(fontSize: 26, color: Color(0xFFEAF3FF), letterSpacing: -0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScopeyPage extends StatelessWidget {
  const ScopeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      'Search targets',
      'Connect a USB-C camera',
      'Set location, date & time',
      'Explain push-to errors',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What can I assist you with?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: prompts
                .map(
                  (prompt) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1F24),
                      border: Border.all(color: const Color(0xFF4D5F6F), width: 1.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Color(0xFFEAF3FF),
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF11314B),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              "Hi! I'm Scopey, Telestronomy's Co-Pilot AI Chat Bot.",
              style: TextStyle(fontSize: 30, color: Color(0xFFEAF3FF), letterSpacing: -0.9),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.only(left: 20, right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF091E2F),
              border: Border.all(color: const Color(0xFF4B6478), width: 1.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ask about the sky or telescope guidance',
                    style: TextStyle(fontSize: 24, color: Color(0xFFB7C8D6), letterSpacing: -0.5),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9BC6FF),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 30, color: Color(0xFF071B2A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Signed-in account',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: const [
              Icon(Icons.email_outlined, size: 30, color: Color(0xFFEAF3FF)),
              SizedBox(width: 14),
              Text(
                'cfahnestock28@hackaday.org',
                style: TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.7),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Your password is not displayed or stored in the app.',
            style: TextStyle(fontSize: 22, color: Color(0xFFBBD4E9), letterSpacing: -0.4),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2438),
              border: Border.all(color: const Color(0xFF456783), width: 1.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.location_off_rounded, size: 28, color: Color(0xFFEAF3FF)),
                SizedBox(width: 12),
                Text(
                  'Reset location',
                  style: TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.6),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFB1D1F4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, size: 30, color: Color(0xFF071B2A)),
                SizedBox(width: 14),
                Text(
                  'Sign out',
                  style: TextStyle(
                    fontSize: 28,
                    color: Color(0xFF071B2A),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlateSolveWorkflowPage extends StatelessWidget {
  const PlateSolveWorkflowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Target: Sun',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2438),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF234765), width: 1.2),
            ),
            child: Column(
              children: [
                const _KeyValueRow(label: 'Location', value: 'Lat 32.9089°, Lng -96.8275°'),
                const _KeyValueRow(label: 'Camera', value: 'Not detected'),
                const _KeyValueRow(label: 'Driver path', value: 'bundled://not-configured'),
                const _KeyValueRow(label: 'GPS fix', value: 'Connected'),
                const _KeyValueRow(label: 'Current angle', value: '38.0° / 105.0°'),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2438),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF234765), width: 1.2),
            ),
            child: Column(
              children: const [
                _KeyValueRow(label: 'RA', value: '0h 0m 0s'),
                _KeyValueRow(label: 'Dec', value: '+0° 0\' 0\"'),
                _KeyValueRow(label: 'Estimated error', value: '13.45°'),
                _KeyValueRow(label: 'Quality', value: 'Tracking'),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Alignment progress',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(
                minHeight: 14,
                value: 0.67,
                backgroundColor: Color(0xFF7C8DA0),
                color: Color(0xFF9BC6FF),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Move the telescope until the plate-solved position matches the target.',
            style: TextStyle(fontSize: 23, color: Color(0xFFEAF3FF), letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2438),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF234765), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 35,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 18),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.7),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 28, color: Color(0xFFEAF3FF), letterSpacing: -0.7),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value, this.isPrompt = false});

  final String label;
  final String value;
  final bool isPrompt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 28,
                color: isPrompt ? const Color(0xFFEAF3FF) : const Color(0xFFEAF3FF),
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 310,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 28,
                color: Color(0xFFEAF3FF),
                letterSpacing: -0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
