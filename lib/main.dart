import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
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
    return  MaterialApp(
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

  void addUserToDatabase(BuildContext context, String userName) {
    usersCollection.doc('user_id').set({
      'name': userName,
      'favorites': [],
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User created successfully!'),
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $error'),
        ),
      );
    });
  }

  void addRestaurantToDatabase(BuildContext context, String restaurantName) {
    restaurantsCollection.doc('restaurant_id').set({
      'name': restaurantName,
      'cuisine': 'Your Cuisine',
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant created successfully!'),
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create restaurant: $error'),
        ),
      );
    });
  }

  Widget _buildCreateDialog(
    String title,
    TextEditingController controller,
    VoidCallback onPressed,
  ) {
    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
      ),
      actions: [
        ElevatedButton(
          onPressed: onPressed,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _buildCreateDialog(
        'Create User',
        nameController,
        () => addUserToDatabase(context, nameController.text),
      ),
    );
  }

  void _showCreateRestaurantDialog(BuildContext context) {
    TextEditingController restaurantNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _buildCreateDialog(
        'Create Restaurant',
        restaurantNameController,
        () => addRestaurantToDatabase(context, restaurantNameController.text),
      ),
    );
  }

  void _showReadDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Read Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAllUsers(context);
              },
              child: const Text('All Users'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAllRestaurants(context);
              },
              child: const Text('All Restaurants'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Users'),
        content: StreamBuilder<QuerySnapshot>(
          stream: _getAllUsersStream(),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (usersSnapshot.hasError) {
              return Center(child: Text('Error: ${usersSnapshot.error}'));
            }

            final userDocs = usersSnapshot.data?.docs ?? [];

            return ListView.builder(
              itemCount: userDocs.length,
              itemBuilder: (context, index) {
                var userData = userDocs[index].data() as Map<String, dynamic>;

                return ListTile(
                  title: Text(userData['name'] as String? ?? ''),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAllRestaurants(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Restaurants'),
        content: StreamBuilder<QuerySnapshot>(
          stream: _getAllRestaurantsStream(),
          builder: (context, restaurantsSnapshot) {
            if (restaurantsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (restaurantsSnapshot.hasError) {
              return Center(child: Text('Error: ${restaurantsSnapshot.error}'));
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
                );
              },
            );
          },
        ),
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

  Stream<QuerySnapshot> _getAllUsersStream() {
    return usersCollection.snapshots();
  }

  Stream<QuerySnapshot> _getAllRestaurantsStream() {
    return restaurantsCollection.snapshots();
  }

  List<String>? _parseFavorites(dynamic favoritesData) {
    if (favoritesData is List) {
      return favoritesData.whereType<String>().toList();
    }
    return null;
  }

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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show dialog to create user or restaurant
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Choose Option'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateUserDialog(context);
                    },
                    child: const Text('Create User'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateRestaurantDialog(context);
                    },
                    child: const Text('Create Restaurant'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showReadDataDialog(context);
                    },
                    child: const Text('Read Data'),
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
