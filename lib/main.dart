import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:test_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    runApp(const MyApp());
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference restaurantsCollection =
      FirebaseFirestore.instance.collection('restaurants');

  MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Integration - Subcollection'),
      ),
      body: StreamBuilder<List<String>>(
        stream: _getUserFavoritesStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          final favoriteRestaurantIds = userSnapshot.data ?? [];

          if (favoriteRestaurantIds.isEmpty) {
            return const Center(child: Text('No favorite restaurants.'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _getFavoriteRestaurantsStream(favoriteRestaurantIds),
            builder: (context, restaurantsSnapshot) {
              if (restaurantsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (restaurantsSnapshot.hasError) {
                return Center(
                    child: Text('Error: ${restaurantsSnapshot.error}'));
              }

              final restaurantDocs = restaurantsSnapshot.data?.docs ?? [];

              return ListView.builder(
                itemCount: restaurantDocs.length,
                itemBuilder: (context, index) {
                  var restaurantData =
                      restaurantDocs[index].data() as Map<String, dynamic>;

                  return ListTile(
                    title: Text(restaurantData['name'] as String? ?? ''),
                    subtitle: Text(restaurantData['cuisine'] as String? ?? ''),
                    trailing: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Stream<List<String>> _getUserFavoritesStream() {
    return usersCollection.doc('user_id').snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;

      if (data == null) {
        return <String>[];
      }

      final favoritesData = data['favorites'];
      return _parseFavorites(favoritesData) ?? [];
    });
  }

  Stream<QuerySnapshot> _getFavoriteRestaurantsStream(
      List<String> favoriteRestaurantIds) {
    return restaurantsCollection
        .where(FieldPath.documentId, whereIn: favoriteRestaurantIds)
        .snapshots();
  }

  List<String>? _parseFavorites(dynamic favoritesData) {
    if (favoritesData is List) {
      return favoritesData.whereType<String>().toList();
    }
    return null;
  }
}
