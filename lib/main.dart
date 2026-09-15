import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'app_theme.dart';
import 'splash_screen.dart';
import 'trip_creation_screen.dart';
import 'trip_search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelMateApp());
}

class TravelMateApp extends StatelessWidget {
  const TravelMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelMate',
      debugShowCheckedModeBanner: false,
      theme: TravelMateTheme.light(),
      onGenerateRoute: AppNavigation.onGenerateRoute,
      home: SplashScreen(
        nextScreen: const TravelMateHome(),
      ),
    );
  }
}

class TravelMateHome extends StatelessWidget {
  const TravelMateHome({super.key});

  @override
  Widget build(BuildContext context) {
    return TripSearchScreen(
      onCreateTrip: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TripCreationScreen(
              onCreated: (trip) {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(
                  '/trip',
                  arguments: trip.id,
                );
              },
            ),
          ),
        );
      },
      onTripSelected: (trip) {
        Navigator.of(context).pushNamed(
          '/trip',
          arguments: trip.id,
        );
      },
    );
  }
}