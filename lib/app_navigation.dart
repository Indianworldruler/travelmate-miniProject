import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'booking_master_folder_screen.dart';
import 'day_wise_itinerary_screen.dart';
import 'expense_tracking_screen.dart';
import 'google_maps_screen.dart';
import 'models.dart';
import 'offline_storage_screen.dart';
import 'packing_checklist_screen.dart';
import 'road_trip_planner_screen.dart';
import 'sync_service.dart';
import 'travel_notes_screen.dart';
import 'travel_todo_screen.dart';
import 'trip_dashboard_screen.dart';

class AppNavigation {
  static Route<dynamic>? onGenerateRoute(
    RouteSettings settings,
  ) {
    final String name = settings.name ?? '/';
    final Object? arguments = settings.arguments;

    // ============================================================
    // TRIP DASHBOARD
    // ============================================================

    if (name == '/trip') {
      return _createDashboardRoute(arguments);
    }

    // ============================================================
    // GET TRIP ID FOR OTHER SCREENS
    // ============================================================

    final String? tripId = _extractTripId(arguments);

    if (tripId == null) {
      return _fallbackRoute();
    }

    // ============================================================
    // TRIP TOOLS
    // ============================================================

    switch (name) {
      case '/itinerary':
        return _createTripRoute(
          arguments,
          (Trip trip) {
            return DayWiseItineraryScreen(
              trip: trip,
            );
          },
        );

      case '/bookings':
        return _createPageRoute(
          BookingMasterFolderScreen(
            tripId: tripId,
          ),
        );

      case '/offline':
        return _createPageRoute(
          OfflineStorageScreen(
            tripId: tripId,
          ),
        );

      case '/maps':
        return _createPageRoute(
          GoogleMapsScreen(
            tripId: tripId,
          ),
        );

      case '/road-trip':
        return _createPageRoute(
          RoadTripPlannerScreen(
            tripId: tripId,
          ),
        );

      case '/packing':
        return _createPageRoute(
          PackingChecklistScreen(
            tripId: tripId,
          ),
        );

      case '/todo':
        return _createPageRoute(
          TravelTodoScreen(
            tripId: tripId,
          ),
        );

      case '/notes':
        return _createPageRoute(
          TravelNotesScreen(
            tripId: tripId,
          ),
        );

      case '/expenses':
        return _createPageRoute(
          ExpenseTrackingScreen(
            tripId: tripId,
          ),
        );

      default:
        return _fallbackRoute();
    }
  }

  // ============================================================
  // DASHBOARD ROUTE
  // ============================================================

  static Route<dynamic> _createDashboardRoute(
    Object? arguments,
  ) {
    // If a complete Trip object was passed, use it directly.
    if (arguments is Trip) {
      return MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return TripDashboardScreen(
            trip: arguments,
            onToolSelected: (String tool) {
              _openTool(
                context,
                arguments,
                tool,
              );
            },
          );
        },
      );
    }

    // Otherwise extract the trip ID and resolve the Trip.
    final String? tripId = _extractTripId(arguments);

    if (tripId == null) {
      return _fallbackRoute();
    }

    return MaterialPageRoute<void>(
      builder: (BuildContext context) {
        return FutureBuilder<Trip?>(
          future: SyncService.instance.resolveTrip(
            tripId,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<Trip?> snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (snapshot.hasError) {
              return const _NavigationFallback();
            }

            final Trip? trip = snapshot.data;

            if (trip == null) {
              return const _NavigationFallback();
            }

            return TripDashboardScreen(
              trip: trip,
              onToolSelected: (String tool) {
                _openTool(
                  context,
                  trip,
                  tool,
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // OPEN DASHBOARD TOOL
  // ============================================================

  static void _openTool(
    BuildContext context,
    Trip trip,
    String tool,
  ) {
    switch (tool) {
      // ----------------------------------------------------------
      // DAY-WISE ITINERARY
      // ----------------------------------------------------------

      case 'itinerary':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return DayWiseItineraryScreen(
                trip: trip,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // BOOKINGS
      // ----------------------------------------------------------

      case 'bookings':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return BookingMasterFolderScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // OFFLINE STORAGE
      // ----------------------------------------------------------

      case 'offline':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return OfflineStorageScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // GOOGLE MAPS
      // ----------------------------------------------------------

      case 'maps':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return GoogleMapsScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // ROAD TRIP
      // ----------------------------------------------------------

      case 'road_trip':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return RoadTripPlannerScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // PACKING
      // ----------------------------------------------------------

      case 'packing':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return PackingChecklistScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // TO-DO
      // ----------------------------------------------------------

      case 'todo':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return TravelTodoScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // NOTES
      // ----------------------------------------------------------

      case 'notes':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return TravelNotesScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // EXPENSES
      // ----------------------------------------------------------

      case 'expenses':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) {
              return ExpenseTrackingScreen(
                tripId: trip.id,
              );
            },
          ),
        );
        break;

      // ----------------------------------------------------------
      // REMOVED FEATURES
      // ----------------------------------------------------------

      case 'visual_itinerary':
      case 'custom_itinerary':
      case 'collaboration':
      case 'members':
        // These features were removed from TravelMate.
        break;

      default:
        break;
    }
  }

  // ============================================================
  // TRIP-BASED ROUTE
  // ============================================================

  static Route<dynamic> _createTripRoute(
    Object? arguments,
    Widget Function(Trip trip) builder,
  ) {
    // Trip already available.
    if (arguments is Trip) {
      return MaterialPageRoute<void>(
        builder: (_) {
          return builder(arguments);
        },
      );
    }

    final String? tripId = _extractTripId(arguments);

    if (tripId == null) {
      return _fallbackRoute();
    }

    return MaterialPageRoute<void>(
      builder: (_) {
        return FutureBuilder<Trip?>(
          future: SyncService.instance.resolveTrip(
            tripId,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<Trip?> snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (snapshot.hasError) {
              return const _NavigationFallback();
            }

            final Trip? trip = snapshot.data;

            if (trip == null) {
              return const _NavigationFallback();
            }

            return builder(trip);
          },
        );
      },
    );
  }

  // ============================================================
  // EXTRACT TRIP ID
  // ============================================================

  static String? _extractTripId(
    Object? arguments,
  ) {
    if (arguments is String) {
      final String value = arguments.trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    if (arguments is Trip) {
      return arguments.id;
    }

    if (arguments is Map) {
      final Object? tripIdValue =
          arguments['tripId'];

      if (tripIdValue is String) {
        final String value =
            tripIdValue.trim();

        if (value.isNotEmpty) {
          return value;
        }
      }

      final Object? tripValue =
          arguments['trip'];

      if (tripValue is Trip) {
        return tripValue.id;
      }
    }

    return null;
  }

  // ============================================================
  // PAGE ROUTE
  // ============================================================

  static MaterialPageRoute<void> _createPageRoute(
    Widget child,
  ) {
    return MaterialPageRoute<void>(
      builder: (_) {
        return child;
      },
    );
  }

  // ============================================================
  // FALLBACK ROUTE
  // ============================================================

  static MaterialPageRoute<void> _fallbackRoute() {
    return MaterialPageRoute<void>(
      builder: (_) {
        return const _NavigationFallback();
      },
    );
  }
}

// =================================================================
// LOADING SCREEN
// =================================================================

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// =================================================================
// NAVIGATION FALLBACK
// =================================================================

class _NavigationFallback extends StatelessWidget {
  const _NavigationFallback();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('TravelMate'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                size: 54,
                color: AppTheme.teal,
              ),
              const SizedBox(height: 14),
              const Text(
                'Trip not selected',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a trip first, then choose one of its travel tools.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                child: const Text(
                  'Go back',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}