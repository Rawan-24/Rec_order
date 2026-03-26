import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/screens/no_internet_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();

    // Check initial state
    _checkInitialConnectivity();

    // Listen for changes (Latest connectivity_plus uses List)
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  @override
  void dispose() {
    // Stop listening when the app is closed to prevent memory leaks
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    setState(() {
      // It is offline if the list contains 'none' or is empty
      isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use a Stack so the NoInternetScreen overlays the current screen
    return Stack(
      children: [
        widget.child,
        if (isOffline)
          const NoInternetScreen(),
      ],
    );
  }
}