import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/models.dart';
import 'src/validators.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TelestronomyBootstrap());
}

class TelestronomyBootstrap extends StatefulWidget {
  const TelestronomyBootstrap({super.key});

  @override
  State<TelestronomyBootstrap> createState() => _TelestronomyBootstrapState();
}

class _TelestronomyBootstrapState extends State<TelestronomyBootstrap> {
  final AppController controller = AppController();

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Telestronomy',
          debugShowCheckedModeBanner: false,
          themeMode: controller.settings.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: controller.isInitializing
              ? const SplashScreen()
              : controller.isAuthenticated
                  ? HomeShell(controller: controller)
                  : AuthScreen(controller: controller),
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2D6CDF),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF08111F)
        : const Color(0xFFF4F7FB),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: brightness == Brightness.dark
          ? const Color(0xFF101D31)
          : Colors.white,
    ),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.travel_explore_rounded, size: 56),
            SizedBox(height: 16),
            Text('Telestronomy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _signInKey = GlobalKey<FormState>();
  final _signUpKey = GlobalKey<FormState>();
  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();
  final _signUpName = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();
  final _signUpConfirm = TextEditingController();

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpName.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    _signUpConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.public_rounded, size: 52),
                            SizedBox(height: 24),
                            Text(
                              'Plan sharper observing sessions.',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Telestronomy turns your local time, location, telescope profile, and curated astronomy data into an observing dashboard for visible exoplanet transits and guide targets.',
                            ),
                            SizedBox(height: 24),
                            _Bullet(text: 'Responsive dashboard with observing readiness and darkness cues'),
                            _Bullet(text: 'Local-only account storage when no backend is configured'),
                            _Bullet(text: 'Target scoring based on altitude, brightness, and telescope capability'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24, height: 24),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: AnimatedBuilder(
                          animation: widget.controller,
                          builder: (context, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Welcome back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(widget.controller.authModeLabel),
                                const SizedBox(height: 24),
                                TabBar(
                                  controller: _tabController,
                                  tabs: const [Tab(text: 'Sign in'), Tab(text: 'Sign up')],
                                ),
                                const SizedBox(height: 24),
                                if (widget.controller.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(widget.controller.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                  ),
                                SizedBox(
                                  height: 420,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildSignIn(context),
                                      _buildSignUp(context),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignIn(BuildContext context) {
    return Form(
      key: _signInKey,
      child: Column(
        children: [
          TextFormField(
            controller: _signInEmail,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signInPassword,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: Validators.password,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: widget.controller.isBusy ? null : () => _handleSignIn(context),
            icon: widget.controller.isBusy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login_rounded),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUp(BuildContext context) {
    return Form(
      key: _signUpKey,
      child: Column(
        children: [
          TextFormField(
            controller: _signUpName,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: (value) => Validators.requiredText(value, fieldName: 'Display name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signUpEmail,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signUpPassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: Validators.password,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _signUpConfirm,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            validator: (value) {
              final required = Validators.requiredText(value, fieldName: 'Password confirmation');
              if (required != null) {
                return required;
              }
              if (value != _signUpPassword.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: widget.controller.isBusy ? null : () => _handleSignUp(context),
            icon: widget.controller.isBusy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Create account'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    if (!_signInKey.currentState!.validate()) {
      return;
    }
    final error = await widget.controller.signIn(
      email: _signInEmail.text,
      password: _signInPassword.text,
    );
    if (!context.mounted || error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _handleSignUp(BuildContext context) async {
    if (!_signUpKey.currentState!.validate()) {
      return;
    }
    final error = await widget.controller.signUp(
      displayName: _signUpName.text,
      email: _signUpEmail.text,
      password: _signUpPassword.text,
    );
    if (!context.mounted || error == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.travel_explore_outlined), selectedIcon: Icon(Icons.travel_explore_rounded), label: 'Discover'),
      NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
    ];
    final screens = [
      DashboardScreen(controller: widget.controller, onNavigate: _navigateTo),
      DiscoveryScreen(controller: widget.controller),
      ProfileScreen(controller: widget.controller),
      SettingsScreen(controller: widget.controller),
    ];

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Telestronomy'),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () async => widget.controller.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (value) => setState(() => index = value),
                    destinations: destinations
                        .map((destination) => NavigationRailDestination(
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              label: Text(destination.label),
                            ))
                        .toList(),
                  ),
                Expanded(
                  child: screens[index],
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  destinations: destinations,
                  onDestinationSelected: (value) => setState(() => index = value),
                ),
        );
      },
    );
  }

  void _navigateTo(int nextIndex) {
    setState(() => index = nextIndex);
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.controller, required this.onNavigate});

  final AppController controller;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final contextData = controller.observationContext;
    final solar = controller.solarSnapshot;
    final recommendations = controller.recommendations(limit: 4);
    final user = controller.currentUser!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _HeroCard(
                title: 'Welcome, ${user.displayName}',
                subtitle: 'Track when the sky is ready, which targets are visible, and what your telescope can realistically follow tonight.',
                actionLabel: 'Update location',
                onAction: () => onNavigate(2),
              ),
              _MetricCard(
                title: 'Observing position',
                value: controller.locationLabel ?? 'Missing',
                supporting: contextData == null ? 'Add a saved or device location to compute visibility.' : 'Visibility updates automatically using your active observing context.',
              ),
              _MetricCard(
                title: 'Darkness status',
                value: solar == null ? 'Unknown' : solar.label,
                supporting: solar == null ? 'Location is required to estimate sky darkness.' : 'Solar altitude ${solar.altitude.toStringAsFixed(1)}°',
              ),
              _MetricCard(
                title: 'Telescope profile',
                value: controller.telescopeProfile?.name ?? 'Not configured',
                supporting: controller.telescopeProfile == null
                    ? 'Save aperture, focal length, and eyepiece data in Settings.'
                    : 'Approx. ${controller.telescopeProfile!.magnification.toStringAsFixed(0)}× at ${controller.telescopeProfile!.trueFieldOfView.toStringAsFixed(2)}° true field.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (contextData == null)
            EmptyStateCard(
              title: 'Location required for live recommendations',
              body: 'Add a saved observing site or enable device location to turn the exoplanet catalogue into altitude-aware recommendations.',
              actionLabel: 'Open profile',
              onAction: () => onNavigate(2),
            )
          else ...[
            const Text('Tonight\'s highest confidence targets', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: recommendations
                  .map((report) => SizedBox(width: 320, child: TargetCard(controller: controller, report: report)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController searchController = TextEditingController();
  bool favoritesOnly = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final reports = widget.controller.recommendations(
          query: searchController.text,
          favoritesOnly: favoritesOnly,
        );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search targets or catalogues',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('Favorites only'),
                  selected: favoritesOnly,
                  onSelected: (value) => setState(() => favoritesOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.controller.observationContext == null
                  ? 'Save a location to unlock discovery.'
                  : '${reports.length} targets match the current observing context.',
            ),
            const SizedBox(height: 16),
            if (widget.controller.observationContext == null)
              const EmptyStateCard(
                title: 'No observing context yet',
                body: 'Telestronomy needs coordinates to convert celestial RA/Dec into your live altitude and azimuth.',
              )
            else if (reports.isEmpty)
              const EmptyStateCard(
                title: 'No targets matched',
                body: 'Broaden your search, disable favorites-only, or allow below-horizon targets in Settings.',
              )
            else
              ...reports.map((report) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TargetCard(controller: widget.controller, report: report),
                  )),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.currentUser!;
    _displayName = TextEditingController(text: user.displayName);
    _latitude = TextEditingController(text: user.homeLatitude?.toString() ?? '');
    _longitude = TextEditingController(text: user.homeLongitude?.toString() ?? '');
  }

  @override
  void dispose() {
    _displayName.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final user = widget.controller.currentUser!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(user.email),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _displayName,
                        decoration: const InputDecoration(labelText: 'Display name'),
                        validator: (value) => Validators.requiredText(value, fieldName: 'Display name'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Home latitude'),
                        validator: (value) => value == null || value.trim().isEmpty ? null : Validators.latitude(value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Home longitude'),
                        validator: (value) => value == null || value.trim().isEmpty ? null : Validators.longitude(value),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _save(context),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save profile'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _latitude.clear();
                              _longitude.clear();
                            },
                            icon: const Icon(Icons.location_off_rounded),
                            label: const Text('Clear saved coordinates'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Favorites',
              value: '${user.favoriteTargetIds.length}',
              supporting: 'Saved targets stay attached to this local account session.',
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final latitude = _latitude.text.trim().isEmpty ? null : double.parse(_latitude.text.trim());
    final longitude = _longitude.text.trim().isEmpty ? null : double.parse(_longitude.text.trim());
    await widget.controller.saveProfile(
      displayName: _displayName.text,
      latitude: latitude,
      longitude: longitude,
      clearCoordinates: latitude == null && longitude == null,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _telescopeKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _type;
  late final TextEditingController _aperture;
  late final TextEditingController _focalLength;
  late final TextEditingController _mount;
  late final TextEditingController _eyepiece;
  late final TextEditingController _afov;
  bool tracking = false;
  bool goTo = false;
  bool pushTo = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.telescopeProfile;
    _name = TextEditingController(text: profile?.name ?? '');
    _type = TextEditingController(text: profile?.type ?? 'Reflector');
    _aperture = TextEditingController(text: profile?.apertureMm.toString() ?? '');
    _focalLength = TextEditingController(text: profile?.focalLengthMm.toString() ?? '');
    _mount = TextEditingController(text: profile?.mountType ?? 'Alt-az');
    _eyepiece = TextEditingController(text: profile?.eyepieceFocalLengthMm.toString() ?? '');
    _afov = TextEditingController(text: profile?.eyepieceApparentFieldDeg.toString() ?? '');
    tracking = profile?.trackingEnabled ?? false;
    goTo = profile?.gotoEnabled ?? false;
    pushTo = profile?.pushToEnabled ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _aperture.dispose();
    _focalLength.dispose();
    _mount.dispose();
    _eyepiece.dispose();
    _afov.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Session settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use device location'),
                      subtitle: const Text('When enabled, live recommendations prefer your current device coordinates.'),
                      value: settings.useDeviceLocation,
                      onChanged: (value) => _updateSettings(settings.copyWith(useDeviceLocation: value)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show only observable targets'),
                      subtitle: const Text('Hide below-horizon targets from the discovery list.'),
                      value: settings.showOnlyObservable,
                      onChanged: (value) => _updateSettings(settings.copyWith(showOnlyObservable: value)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Local transit reminders'),
                      subtitle: const Text('Stored as a local preference for future notification integration.'),
                      value: settings.notificationsEnabled,
                      onChanged: (value) => _updateSettings(settings.copyWith(notificationsEnabled: value)),
                    ),
                    DropdownButtonFormField<ThemePreference>(
                      initialValue: settings.themePreference,
                      decoration: const InputDecoration(labelText: 'Theme'),
                      items: ThemePreference.values
                          .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _updateSettings(settings.copyWith(themePreference: value));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final message = await widget.controller.refreshLocation();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message ?? 'Device location updated.')),
                            );
                          },
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Refresh device location'),
                        ),
                        if (widget.controller.locationLabel != null)
                          Chip(label: Text(widget.controller.locationLabel!)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _telescopeKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Telescope profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Profile name'),
                        validator: (value) => Validators.requiredText(value, fieldName: 'Profile name'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _type,
                        decoration: const InputDecoration(labelText: 'Telescope type'),
                        validator: (value) => Validators.requiredText(value, fieldName: 'Telescope type'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _aperture,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Aperture (mm)'),
                        validator: (value) => Validators.positiveNumber(value, fieldName: 'Aperture'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _focalLength,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Focal length (mm)'),
                        validator: (value) => Validators.positiveNumber(value, fieldName: 'Focal length'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mount,
                        decoration: const InputDecoration(labelText: 'Mount type'),
                        validator: (value) => Validators.requiredText(value, fieldName: 'Mount type'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _eyepiece,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Eyepiece focal length (mm)'),
                        validator: (value) => Validators.positiveNumber(value, fieldName: 'Eyepiece focal length'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _afov,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Eyepiece apparent field (°)'),
                        validator: (value) => Validators.positiveNumber(value, fieldName: 'Eyepiece apparent field'),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tracking enabled'),
                        value: tracking,
                        onChanged: (value) => setState(() => tracking = value ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('GoTo enabled'),
                        value: goTo,
                        onChanged: (value) => setState(() => goTo = value ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Push-to enabled'),
                        value: pushTo,
                        onChanged: (value) => setState(() => pushTo = value ?? false),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _saveTelescope(context),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Save telescope'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await widget.controller.saveTelescopeProfile(null);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telescope profile removed.')));
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Remove profile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateSettings(AppSettings nextSettings) async {
    await widget.controller.saveSettings(nextSettings);
  }

  Future<void> _saveTelescope(BuildContext context) async {
    if (!_telescopeKey.currentState!.validate()) {
      return;
    }
    final profile = TelescopeProfile(
      name: _name.text.trim(),
      type: _type.text.trim(),
      apertureMm: double.parse(_aperture.text.trim()),
      focalLengthMm: double.parse(_focalLength.text.trim()),
      mountType: _mount.text.trim(),
      trackingEnabled: tracking,
      gotoEnabled: goTo,
      pushToEnabled: pushTo,
      eyepieceFocalLengthMm: double.parse(_eyepiece.text.trim()),
      eyepieceApparentFieldDeg: double.parse(_afov.text.trim()),
    );
    await widget.controller.saveTelescopeProfile(profile);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telescope profile saved.')));
  }
}

class TargetCard extends StatelessWidget {
  const TargetCard({super.key, required this.controller, required this.report});

  final AppController controller;
  final VisibilityReport report;

  @override
  Widget build(BuildContext context) {
    final favorite = controller.isFavorite(report.target.id);
    return Semantics(
      label: 'Target ${report.target.name}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.target.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(report.target.catalog),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: favorite ? 'Remove favorite' : 'Save favorite',
                    onPressed: () => controller.toggleFavorite(report.target.id),
                    icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoChip(label: 'Score ${report.score.toStringAsFixed(0)}'),
                  _InfoChip(label: report.visibilityLabel),
                  _InfoChip(label: '${report.altitude.toStringAsFixed(1)}° alt'),
                  _InfoChip(label: '${report.azimuth.toStringAsFixed(1)}° ${report.direction}'),
                  if (report.target.visualMagnitude != null)
                    _InfoChip(label: 'V ${report.target.visualMagnitude!.toStringAsFixed(1)}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(report.summary),
              if (report.nextTransit != null) ...[
                const SizedBox(height: 12),
                Text('Next transit: ${_formatDateTime(report.nextTransit!.toLocal())}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(body),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.nights_stay_rounded, size: 40),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(subtitle),
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.supporting});

  final String title;
  final String value;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(supporting),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_outline_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day $hour:$minute';
}
