import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// --- MODELS ---
class FastingSession {
  final String id;
  final DateTime date;
  final Duration duration;
  final String foodRecommendation;

  FastingSession({
    required this.id,
    required this.date,
    required this.duration,
    required this.foodRecommendation,
  });
}

// Represents the current state of the user's fast.
enum FastingStatus { idle, waiting, fasting, feeding }

// --- SERVICES ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _notifications.initialize(initSettings);
    await _requestPermissions();
    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showNotification(String title, String body) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'fasting_channel',
      'Fasting Notifications',
      channelDescription: 'Notifications for fasting start and completion',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macOSDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

class GeminiFoodRecommendationService {
  final String _apiKey = 'AIzaSyBvitWCi4oBadrbhSeMFdS8RvF9ztPn8Bg';
  final String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent';

  String _getDayOfWeek(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[day - 1];
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  Future<String> getRecommendation(
    String? lastRecommendation,
    Duration fastingDuration,
    String location,
  ) async {
    if (_apiKey == 'YOUR_API_KEY_HERE' || _apiKey.isEmpty) {
      return "Please add your Gemini API Key to the `GeminiFoodRecommendationService` class.";
    }
    final now = DateTime.now();
    final prompt =
        """
      You are a helpful nutrition assistant.
      The user is in $location and has just finished a ${fastingDuration.inHours}-hour intermittent fast.
      It is currently late ${_getTimeOfDay(now.hour)} on ${_getDayOfWeek(now.weekday)}.
      Suggest one healthy, hearty, and locally relevant meal to break their fast.
      The meal should be rich in protein and healthy fats but not overly heavy.
      Provide a brief, encouraging, one-sentence explanation of why it's a good choice.
      Do not repeat the last suggestion, which was: ${lastRecommendation ?? 'none'}.
      Respond only with the meal suggestion and the one-sentence explanation.
    """;
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            (data['candidates'] as List).isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null &&
              candidate['content']['parts'] != null &&
              (candidate['content']['parts'] as List).isNotEmpty) {
            return candidate['content']['parts'][0]['text'].trim();
          }
        }
        debugPrint(
          'GEMINI API WARNING: Response received, but no valid candidate content was found. Full Response: ${response.body}',
        );
        throw Exception(
          'The model returned an empty response. This may be due to safety settings.',
        );
      } else {
        debugPrint(
          'GEMINI API ERROR: Status ${response.statusCode}. Full Response: ${response.body}',
        );
        throw Exception(
          'Failed to get recommendation. Status: ${response.statusCode}.',
        );
      }
    } catch (e) {
      debugPrint('Error during API call: $e');
      rethrow;
    }
  }
}

// --- MAIN APPLICATION ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const FastingApp());
}

class FastingApp extends StatelessWidget {
  const FastingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WellFasted',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF81C784),
          surface: Color(0xFF1A1A1A),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1A1A),
          elevation: 8,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF1A1A1A),
          dialHandColor: const Color(0xFF4CAF50),
          hourMinuteTextColor: Colors.white,
          dayPeriodTextColor: Colors.white,
          entryModeIconColor: const Color(0xFF4CAF50),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// --- SCREENS ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final NotificationService _notificationService = NotificationService();
  final GeminiFoodRecommendationService _foodService =
      GeminiFoodRecommendationService();
  final Random _random = Random();

  // State
  Duration _fastingDuration = const Duration(hours: 16);
  TimeOfDay? _breakFastTime;
  DateTime? _fastStartTime;
  DateTime? _fastEndTime;
  FastingStatus _status = FastingStatus.idle;
  Duration _countdownTime = Duration.zero;
  Timer? _timer;
  String? _currentFoodRecommendation;
  String? _prefetchedRecommendation;
  bool _isRecommendationLoading = false;
  bool _isRecommendationFetched = false;
  final List<FastingSession> _history = [];
  final String _location = 'Kingston, Jamaica';

  // Tips
  String? _currentTip;
  int _lastTipUpdateMinute = -1;
  static const List<String> _fastingTips = [
    "Drink plenty of water throughout your fast to stay hydrated.",
    "Black coffee or tea are fine during your fast, but avoid sugar and milk.",
    "Listen to your body. If you feel unwell, consider breaking your fast.",
    "Ease into intermittent fasting. Start with a shorter fasting window and gradually increase it.",
    "Plan your meals for your eating window to avoid unhealthy impulse choices.",
    "Your first meal after a fast should be balanced, not a binge.",
    "Add a pinch of salt to your water if you're feeling dizzy to replenish electrolytes.",
    "Keep busy during your fasting hours to distract yourself from hunger.",
    "Fasting can improve mental clarity and focus for many people.",
    "Avoid strenuous workouts on an empty stomach if you're new to fasting.",
    "Herbal teas without added sugars are a great way to stay hydrated and add flavor.",
    "Intermittent fasting is a pattern of eating, not a diet dictating what to eat.",
    "Ensure your meals are nutrient-dense to fuel your body properly.",
    "Getting enough sleep is crucial, as it helps regulate hunger hormones.",
    "Break your fast gently with a small, easily digestible meal.",
    "Protein is key to feeling full and maintaining muscle mass.",
    "Don't forget healthy fats like avocado, nuts, and olive oil.",
    "Fasting can help improve your body's insulin sensitivity.",
    "Be patient. It can take a few weeks for your body to adapt to a new eating schedule.",
    "Sparkling water can help you feel full and combat hunger pangs.",
    "Mindful eating during your feeding window can enhance digestion and satisfaction.",
    "Chewing sugar-free gum can sometimes help with hunger, but be aware it might contain calories.",
    "Fasting isn't about starvation; it's about giving your digestive system a rest.",
    "Use a smaller plate to help with portion control when you break your fast.",
    "Consistency is more important than perfection.",
    "Track your progress to stay motivated. Note how you feel, not just the numbers.",
    "Intermittent fasting may help reduce inflammation in the body.",
    "Don't compare your fasting journey to others. Everyone is different.",
    "Focus on whole foods and minimize processed items.",
    "A walk can be a great way to curb hunger and get some light exercise.",
    "Bone broth is a nutritious option if you need something savory during your fast.",
    "Be mindful of your salt intake, especially if you drink a lot of water.",
    "Fasting can trigger cellular repair processes like autophagy.",
    "Tell friends and family about your fasting schedule so they can be supportive.",
    "Prepare your post-fast meal in advance to make healthy choices easier.",
    "Cinnamon in your coffee or tea can help regulate blood sugar.",
    "Avoid artificial sweeteners as they can sometimes spike insulin.",
    "The feeling of hunger often comes in waves and will pass.",
    "Don't be discouraged by a single off-day. Just get back on track.",
    "Light exercise like yoga or stretching can be beneficial during a fast.",
    "For longer fasts, consider consulting with a healthcare professional.",
    "Make sure you're getting enough fiber in your eating window.",
    "Vegetable soups are a great way to break a fast.",
    "Remember that the benefits of fasting go beyond weight loss.",
    "Fasting can help you learn the difference between true hunger and cravings.",
    "Stay positive and focus on the health benefits you're gaining.",
    "Apple cider vinegar (diluted in water) is a popular drink during fasts.",
    "Let your body adjust. Initial headaches or fatigue are common but usually temporary.",
    "Don't overeat when your window opens. Eat a normal-sized meal.",
    "Your energy levels might actually increase after the initial adjustment period.",
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimer(Timer timer) {
    final now = DateTime.now();
    FastingStatus newStatus = _status;
    Duration newCountdownTime = Duration.zero;

    if (_fastStartTime == null || _fastEndTime == null) {
      _cancelSchedule();
      return;
    }

    // Update tip every 30 minutes
    int currentMinute = now.difference(_fastStartTime!).inMinutes;
    if (_status != FastingStatus.idle &&
        currentMinute != _lastTipUpdateMinute &&
        currentMinute % 30 == 0) {
      setState(() {
        _currentTip = _fastingTips[_random.nextInt(_fastingTips.length)];
        _lastTipUpdateMinute = currentMinute;
      });
    }

    if (now.isBefore(_fastStartTime!)) {
      newStatus = FastingStatus.waiting;
      newCountdownTime = _fastStartTime!.difference(now);
    } else if (now.isBefore(_fastEndTime!)) {
      if (_status == FastingStatus.waiting) {
        _notificationService.showNotification(
          'Fast Started!',
          'Your ${_fastingDuration.inHours}-hour fast has begun.',
        );
      }
      newStatus = FastingStatus.fasting;
      newCountdownTime = _fastEndTime!.difference(now);
      // Prefetch recommendation in the last hour
      if (newCountdownTime.inHours < 1 &&
          !_isRecommendationFetched &&
          !_isRecommendationLoading) {
        _prefetchFoodRecommendation();
      }
    } else {
      if (_status == FastingStatus.fasting) {
        _notificationService.showNotification(
          'Fast Complete!',
          'Your ${_fastingDuration.inHours}-hour fast has ended. Time to eat.',
        );

        // Always add the completed fast to history
        String recommendation;
        if (_prefetchedRecommendation != null) {
          recommendation = _prefetchedRecommendation!;
          setState(() {
            _currentFoodRecommendation = _prefetchedRecommendation;
            _prefetchedRecommendation = null;
          });
        } else {
          // Use a temporary recommendation for history, will be updated when generated
          recommendation =
              "Enjoy a balanced, nutritious meal to break your fast!";
          _generateFeedingRecommendation(addToHistory: true);
        }

        // Add to history
        setState(() {
          _history.insert(
            0,
            FastingSession(
              id: DateTime.now().toIso8601String(),
              date: DateTime.now(),
              duration: _fastingDuration,
              foodRecommendation: recommendation,
            ),
          );
        });
      }
      newStatus = FastingStatus.feeding;
      newCountdownTime = Duration.zero;
    }

    setState(() {
      _status = newStatus;
      _countdownTime = newCountdownTime;
    });
  }

  void _scheduleFast() {
    if (_breakFastTime == null) return;
    final now = DateTime.now();
    DateTime breakTime = DateTime(
      now.year,
      now.month,
      now.day,
      _breakFastTime!.hour,
      _breakFastTime!.minute,
    );

    if (breakTime.isBefore(now)) {
      breakTime = breakTime.add(const Duration(days: 1));
    }

    setState(() {
      _fastEndTime = breakTime;
      _fastStartTime = breakTime.subtract(_fastingDuration);
      _status = FastingStatus.waiting;
      _currentTip =
          _fastingTips[_random.nextInt(
            _fastingTips.length,
          )]; // Show initial tip
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    _updateTimer(_timer!);
  }

  void _cancelSchedule() {
    _timer?.cancel();
    setState(() {
      _status = FastingStatus.idle;
      _breakFastTime = null;
      _fastStartTime = null;
      _fastEndTime = null;
      _countdownTime = Duration.zero;
      _currentFoodRecommendation = null;
      _prefetchedRecommendation = null;
      _isRecommendationFetched = false;
      _isRecommendationLoading = false;
      _currentTip = null;
      _lastTipUpdateMinute = -1;
    });
  }

  Future<void> _selectFastingDuration() async {
    final newDurationInHours = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        final options = [14, 16, 18, 20, 23, 0];
        return Container(
          color: const Color(0xFF1E1E1E),
          child: ListView(
            shrinkWrap: true,
            children: options
                .map(
                  (hours) => ListTile(
                    title: Center(
                      child: Text(hours == 0 ? 'Custom' : '$hours-Hour Fast'),
                    ),
                    onTap: () => Navigator.of(context).pop(hours),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (newDurationInHours != null) {
      if (newDurationInHours == 0) {
        _showCustomDurationDialog();
      } else {
        setState(() => _fastingDuration = Duration(hours: newDurationInHours));
        if (_breakFastTime != null) _scheduleFast();
      }
    }
  }

  Future<void> _showCustomDurationDialog() async {
    final controller = TextEditingController();
    final customHours = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Custom Duration'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Fasting Hours',
            hintText: 'e.g., 17',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Set'),
            onPressed: () {
              final hours = int.tryParse(controller.text);
              if (hours != null && hours > 0) Navigator.of(context).pop(hours);
            },
          ),
        ],
      ),
    );
    if (customHours != null) {
      setState(() => _fastingDuration = Duration(hours: customHours));
      if (_breakFastTime != null) _scheduleFast();
    }
  }

  Future<void> _selectBreakFastTime() async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _breakFastTime ?? TimeOfDay.now(),
    );
    if (newTime != null) {
      setState(() => _breakFastTime = newTime);
      _scheduleFast();
    }
  }

  Future<void> _prefetchFoodRecommendation() async {
    setState(() {
      _isRecommendationLoading = true;
      _isRecommendationFetched = true;
    });
    try {
      final recommendation = await _foodService.getRecommendation(
        _history.isNotEmpty ? _history.first.foodRecommendation : null,
        _fastingDuration,
        _location,
      );
      if (mounted) {
        setState(() => _prefetchedRecommendation = recommendation);
      }
    } catch (e) {
      debugPrint("Error pre-fetching recommendation: $e");
      if (mounted) {
        setState(
          () => _prefetchedRecommendation = "Could not get a recommendation.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecommendationLoading = false);
      }
    }
  }

  Future<void> _generateFeedingRecommendation({
    bool addToHistory = false,
  }) async {
    setState(() {
      _isRecommendationLoading = true;
    });
    try {
      final recommendation = await _foodService.getRecommendation(
        _history.isNotEmpty ? _history.first.foodRecommendation : null,
        _fastingDuration,
        _location,
      );
      if (mounted) {
        setState(() {
          _currentFoodRecommendation = recommendation;
          // Update the most recent history entry if this was for a completed fast
          if (addToHistory && _history.isNotEmpty) {
            _history[0] = FastingSession(
              id: _history[0].id,
              date: _history[0].date,
              duration: _history[0].duration,
              foodRecommendation: recommendation,
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error generating feeding recommendation: $e");
      if (mounted) {
        setState(() {
          _currentFoodRecommendation =
              "Enjoy a balanced, nutritious meal to break your fast!";
          // Update history entry if needed
          if (addToHistory && _history.isNotEmpty) {
            _history[0] = FastingSession(
              id: _history[0].id,
              date: _history[0].date,
              duration: _history[0].duration,
              foodRecommendation:
                  "Enjoy a balanced, nutritious meal to break your fast!",
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRecommendationLoading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('WellFasted'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.history_rounded, size: 24),
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, _) =>
                      HistoryScreen(history: _history),
                  transitionsBuilder: (context, animation, _, child) {
                    return SlideTransition(
                      position: animation.drive(
                        Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                      ),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimerDisplay(),
                      const SizedBox(height: 40),
                      if (_status == FastingStatus.idle) _buildIdleState(),
                      if (_status != FastingStatus.idle)
                        _buildFastingInfoSection(),
                    ],
                  ),
                ),
                if (_status != FastingStatus.idle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildCancelButton(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    String title;
    Color titleColor;
    Color timeColor;
    IconData? statusIcon;

    switch (_status) {
      case FastingStatus.waiting:
        title = 'Fast Starts In';
        titleColor = const Color(0xFF81C784);
        timeColor = const Color(0xFF4CAF50);
        statusIcon = Icons.schedule_rounded;
        break;
      case FastingStatus.fasting:
        title = 'Time Remaining';
        titleColor = const Color(0xFF64B5F6);
        timeColor = const Color(0xFF2196F3);
        statusIcon = Icons.timer_rounded;
        break;
      case FastingStatus.feeding:
        title = 'Fast Complete!';
        titleColor = const Color(0xFFFFB74D);
        timeColor = const Color(0xFFFF9800);
        statusIcon = Icons.restaurant_rounded;
        break;
      case FastingStatus.idle:
        title = 'Ready to Start';
        titleColor = Colors.white70;
        timeColor = Colors.white;
        statusIcon = Icons.play_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [timeColor.withValues(alpha: 0.1), Colors.transparent],
          radius: 1.5,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: titleColor, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: _status == FastingStatus.feeding
                  ? 42
                  : _status == FastingStatus.idle
                  ? 28
                  : 64,
              fontWeight: FontWeight.w700,
              color: timeColor,
              letterSpacing: 2,
              shadows: [
                Shadow(color: timeColor.withValues(alpha: 0.3), blurRadius: 8),
              ],
            ),
            child: Text(
              _status == FastingStatus.feeding
                  ? '🍽️ Feeding Window Open'
                  : _status == FastingStatus.idle
                  ? 'Tap below to begin'
                  : _formatDuration(_countdownTime),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingInfoSection() {
    // During feeding window, always show the meal recommendation
    if (_status == FastingStatus.feeding) {
      // If we don't have a current recommendation, generate one
      if (_currentFoodRecommendation == null && !_isRecommendationLoading) {
        _generateFeedingRecommendation();
      }

      if (_currentFoodRecommendation != null) {
        return _buildRecommendationCard(
          title: "Enjoy your meal!",
          recommendation: _currentFoodRecommendation!,
        );
      }
    }

    // During the last hour of the fast, show the upcoming meal
    if (_status == FastingStatus.fasting && _prefetchedRecommendation != null) {
      return _buildRecommendationCard(
        title: "Get ready to enjoy...",
        recommendation: _prefetchedRecommendation!,
      );
    }

    // While waiting or fasting (and no meal is ready), show a tip
    if ((_status == FastingStatus.waiting ||
            _status == FastingStatus.fasting) &&
        _currentTip != null) {
      return _buildTipCard();
    }

    return const SizedBox.shrink(); // Return empty space if none of the conditions are met
  }

  Widget _buildTipCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2196F3).withValues(alpha: 0.1),
            const Color(0xFF1A1A1A).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: const Color(0xFF64B5F6),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Fasting Tip',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFF64B5F6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentTip!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String recommendation,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF9800).withValues(alpha: 0.1),
            const Color(0xFF1A1A1A).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9800).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                color: const Color(0xFFFFB74D),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFFFFB74D),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isRecommendationLoading
              ? Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Preparing your meal suggestion...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                )
              : Text(
                  recommendation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Text(
            'Configure your fasting schedule and start your wellness journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.4,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            _buildInfoChip(
              icon: Icons.timer_rounded,
              label: 'Fasting Duration',
              value: '${_fastingDuration.inHours}h',
              onTap: _selectFastingDuration,
            ),
            _buildInfoChip(
              icon: Icons.schedule_rounded,
              label: 'Break Fast At',
              value: _breakFastTime?.format(context) ?? 'Set Time',
              onTap: _selectBreakFastTime,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4CAF50).withValues(alpha: 0.2),
                const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4CAF50), size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _cancelSchedule,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Stop Fasting',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<FastingSession> history;
  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Fasting History'),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No fasting history yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete your first fast to see it here',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final session = history[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF4CAF50).withValues(alpha: 0.1),
                            const Color(0xFF1A1A1A).withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${session.duration.inHours}-Hour Fast',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${session.date.day}/${session.date.month}/${session.date.year}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.restaurant_rounded,
                                  color: Color(0xFFFFB74D),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    session.foodRecommendation,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
