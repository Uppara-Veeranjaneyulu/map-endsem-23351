// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'dart:math' as math; // For generating random IDs
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';

import 'notifications_web.dart' if (dart.library.io) 'notifications_mobile.dart';

// --- DATA MODEL ---
class Plant {
  final String id;
  String name;
  String type; // e.g., Indoor, Outdoor, Succulent
  String imageUrl;
  int wateringFrequencyDays; // e.g., every 3 days
  DateTime? lastWateredDate;
  double? latitude;
  double? longitude;
  String? locationName;

  Plant({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.wateringFrequencyDays,
    this.lastWateredDate,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  factory Plant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Plant(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? 'Indoor',
      imageUrl: data['imageUrl'] ?? '',
      wateringFrequencyDays: data['wateringFrequencyDays'] ?? 7,
      lastWateredDate: data['lastWateredDate'] != null
          ? (data['lastWateredDate'] as Timestamp).toDate()
          : null,
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationName: data['locationName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'imageUrl': imageUrl,
      'wateringFrequencyDays': wateringFrequencyDays,
      'lastWateredDate': lastWateredDate != null ? Timestamp.fromDate(lastWateredDate!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  bool get needsWatering {
    if (lastWateredDate == null) {
      return true; // Assume needs watering if never wateredF
    }
    final Duration timeSinceLastWatered = DateTime.now().difference(
      lastWateredDate!,
    );
    return timeSinceLastWatered.inDays >= wateringFrequencyDays;
  }
}

class PlantProvider extends ChangeNotifier {
  List<Plant> _plants = [];
  String _searchQuery = '';
  String? _selectedSearchType;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  PlantProvider() {
    _db.collection('plants').snapshots().listen((snapshot) {
      _plants = snapshot.docs.map((doc) => Plant.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  List<Plant> get plants {
    List<Plant> filteredPlants = _plants.where((plant) {
      final matchesSearchQuery = plant.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesSelectedType =
          _selectedSearchType == null || plant.type == _selectedSearchType;
      return matchesSearchQuery && matchesSelectedType;
    }).toList();

    // Sort plants by name for consistent display
    filteredPlants.sort((a, b) => a.name.compareTo(b.name));
    return filteredPlants;
  }

  List<String> get plantTypes {
    final Set<String> types = _plants.map((p) => p.type).toSet();
    return [
      'Indoor',
      'Outdoor',
      'Succulent',
      'Flower',
      'Herb',
      'Vegetable',
      ...types,
    ].toSet().toList()..sort();
  }

  Future<void> addPlant(Plant plant) async {
    await _db.collection('plants').add(plant.toMap());
    await AppNotifications.scheduleWatering(plant);
  }

  Future<void> updatePlant(Plant updatedPlant) async {
    await _db.collection('plants').doc(updatedPlant.id).update(updatedPlant.toMap());
    await AppNotifications.scheduleWatering(updatedPlant);
  }

  Future<void> deletePlant(String id) async {
    await _db.collection('plants').doc(id).delete();
    await AppNotifications.cancel(id);
  }

  Future<void> markPlantAsWatered(String id) async {
    await _db.collection('plants').doc(id).update({
      'lastWateredDate': FieldValue.serverTimestamp(),
    });
    final Plant? plant = _plants.firstWhereOrNull((p) => p.id == id);
    if (plant != null) {
      plant.lastWateredDate = DateTime.now();
      await AppNotifications.scheduleWatering(plant);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedSearchType(String? type) {
    _selectedSearchType = type;
    notifyListeners();
  }
}

// --- SCREENS ---

class PlantGalleryScreen extends StatefulWidget {
  const PlantGalleryScreen({super.key});

  @override
  State<PlantGalleryScreen> createState() => _PlantGalleryScreenState();
}

class _PlantGalleryScreenState extends State<PlantGalleryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search plants...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  Provider.of<PlantProvider>(
                    context,
                    listen: false,
                  ).setSearchQuery(query);
                },
              )
            : const Text('Plant Care Companion'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  Provider.of<PlantProvider>(
                    context,
                    listen: false,
                  ).setSearchQuery('');
                }
              });
            },
          ),
          Consumer<PlantProvider>(
            builder: (context, plantProvider, child) {
              final List<String> availableTypes = plantProvider.plantTypes;
              final String? currentSelectedType =
                  plantProvider._selectedSearchType;
              return DropdownButton<String>(
                value: currentSelectedType,
                icon: const Icon(Icons.filter_list, color: Colors.white),
                underline: Container(),
                hint: const Text(
                  'Filter Type',
                  style: TextStyle(color: Colors.white),
                ),
                onChanged: (String? newValue) {
                  plantProvider.setSelectedSearchType(newValue);
                },
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Types'),
                  ),
                  ...availableTypes.map<DropdownMenuItem<String>>((
                    String value,
                  ) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<PlantProvider>(
        builder: (context, plantProvider, child) {
          if (plantProvider.plants.isEmpty &&
              !_isSearching &&
              plantProvider._selectedSearchType == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.eco, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No plants yet!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Add your first plant to get started.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          } else if (plantProvider.plants.isEmpty &&
              (_isSearching || plantProvider._selectedSearchType != null)) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.search_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No matching plants found.',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Try adjusting your search or filters.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.75, // Adjust as needed
            ),
            itemCount: plantProvider.plants.length,
            itemBuilder: (context, index) {
              final Plant plant = plantProvider.plants[index];
              return PlantCard(plant: plant);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const AddPlantScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlantCard extends StatelessWidget {
  final Plant plant;

  const PlantCard({required this.plant, super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    PlantProvider plantProvider,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plant'),
        content: Text(
          'Are you sure you want to delete "${plant.name}"? This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      plantProvider.deletePlant(plant.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  PlantDetailsScreen(plantId: plant.id, heroTag: plant.id),
            ),
          );
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Hero(
                    tag: plant.id,
                    child: Image.network(
                      plant.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plant.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Water every ${plant.wateringFrequencyDays} days',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Icon(
                            plant.needsWatering
                                ? Icons.opacity
                                : Icons.check_circle_outline,
                            color: plant.needsWatering
                                ? Colors.redAccent
                                : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            plant.needsWatering ? 'Needs Water' : 'Watered',
                            style: TextStyle(
                              fontSize: 12,
                              color: plant.needsWatering
                                  ? Colors.redAccent
                                  : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(
                    context,
                    Provider.of<PlantProvider>(context, listen: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddPlantScreen extends StatefulWidget {
  final Plant? plantToEdit;

  const AddPlantScreen({this.plantToEdit, super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _imageUrlController;
  late TextEditingController _locationController;
  double? _latitude;
  double? _longitude;
  late String _selectedType;
  late double _wateringFrequencyDays;
  late List<String> _plantTypes;

  @override
  void initState() {
    super.initState();
    final PlantProvider plantProvider = Provider.of<PlantProvider>(
      context,
      listen: false,
    );
    _plantTypes = plantProvider.plantTypes;

    _nameController = TextEditingController(
      text: widget.plantToEdit?.name ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.plantToEdit?.imageUrl ?? 'https://picsum.photos/250?image=9',
    ); // Placeholder image
    _locationController = TextEditingController(
      text: widget.plantToEdit?.locationName ?? '',
    );
    _latitude = widget.plantToEdit?.latitude;
    _longitude = widget.plantToEdit?.longitude;
    _selectedType =
        widget.plantToEdit?.type ??
        _plantTypes.firstWhere((element) => true, orElse: () => 'Indoor');
    _wateringFrequencyDays = (widget.plantToEdit?.wateringFrequencyDays ?? 7)
        .toDouble();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageUrlController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _tagLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
      if (_locationController.text.isEmpty) {
        _locationController.text = 'Tagged Location';
      }
    });
  }

  void _savePlant() {
    if (_formKey.currentState!.validate()) {
      final PlantProvider plantProvider = Provider.of<PlantProvider>(
        context,
        listen: false,
      );

      final Plant updated = Plant(
        id: widget.plantToEdit?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: _selectedType,
        imageUrl: _imageUrlController.text,
        wateringFrequencyDays: _wateringFrequencyDays.toInt(),
        lastWateredDate: widget.plantToEdit?.lastWateredDate,
        locationName: _locationController.text.isNotEmpty ? _locationController.text : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (widget.plantToEdit == null) {
        plantProvider.addPlant(updated);
      } else {
        plantProvider.updatePlant(updated);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.plantToEdit == null ? 'Add New Plant' : 'Edit Plant',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plant Name',
                  prefixIcon: Icon(Icons.local_florist),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a plant name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  prefixIcon: Icon(Icons.image),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an image URL.';
                  }
                  // Basic URL validation
                  if (!Uri.tryParse(value)!.hasAbsolutePath ?? true) {
                    return 'Please enter a valid URL.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location Name (e.g. Balcony)',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (_latitude != null && _longitude != null) 
                          ? 'GPS: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                          : 'No GPS tagged',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _tagLocation,
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: const Text('Tag GPS'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Plant Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: _plantTypes.map<DropdownMenuItem<String>>((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a plant type.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Watering Frequency: ${_wateringFrequencyDays.toInt()} days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _wateringFrequencyDays,
                min: 1,
                max: 30,
                divisions: 29, // 1 to 30 days
                label: _wateringFrequencyDays.toInt().toString(),
                onChanged: (double newValue) {
                  setState(() {
                    _wateringFrequencyDays = newValue;
                  });
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _savePlant,
                  icon: Icon(
                    widget.plantToEdit == null ? Icons.add_circle : Icons.save,
                  ),
                  label: Text(
                    widget.plantToEdit == null ? 'Add Plant' : 'Save Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      50,
                    ), // Full width button
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlantDetailsScreen extends StatelessWidget {
  final String plantId;
  final String heroTag; // For Hero animation

  const PlantDetailsScreen({
    required this.plantId,
    required this.heroTag,
    super.key,
  });

  Future<void> _confirmDelete(
    BuildContext context,
    PlantProvider plantProvider,
    Plant plant,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plant'),
        content: Text(
          'Are you sure you want to delete "${plant.name}"? This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      plantProvider.deletePlant(plantId);
      if (context.mounted) {
        Navigator.of(context).pop(); // Pop back to gallery after deletion
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final Plant? plant = plantProvider.plants.firstWhereOrNull(
          (p) => p.id == plantId,
        );

        if (plant == null) {
          // Plant not found, navigate back
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Plant not found!')));
          });
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(plant.name),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AddPlantScreen(plantToEdit: plant),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, plantProvider, plant),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Hero(
                  tag: heroTag,
                  child: Image.network(
                    plant.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        plant.name,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                      ),
                      const SizedBox(height: 16),
                      if (plant.locationName != null || plant.latitude != null)
                        _buildDetailRow(
                          context,
                          Icons.location_on,
                          'Location:',
                          '${plant.locationName ?? "Unknown"} ${plant.latitude != null ? "(${plant.latitude!.toStringAsFixed(4)}, ${plant.longitude!.toStringAsFixed(4)})" : ""}',
                        ),
                      _buildDetailRow(
                        context,
                        Icons.category,
                        'Plant Type:',
                        plant.type,
                      ),
                      _buildDetailRow(
                        context,
                        Icons.schedule,
                        'Watering Frequency:',
                        'Every ${plant.wateringFrequencyDays} days',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.calendar_today,
                        'Last Watered:',
                        plant.lastWateredDate != null
                            ? '${plant.lastWateredDate!.toLocal().day}/${plant.lastWateredDate!.toLocal().month}/${plant.lastWateredDate!.toLocal().year}'
                            : 'Never',
                        color: plant.needsWatering
                            ? const Color.fromARGB(255, 88, 49, 49)
                            : const Color.fromARGB(255, 125, 184, 127),
                      ),
                      _buildDetailRow(
                        context,
                        plant.needsWatering
                            ? Icons.opacity
                            : Icons.check_circle_outline,
                        'Status:',
                        plant.needsWatering ? 'Needs Watering' : 'Watered',
                        color: plant.needsWatering
                            ? const Color.fromARGB(255, 126, 76, 76)
                            : const Color.fromARGB(255, 130, 196, 132),
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            plantProvider.markPlantAsWatered(plant.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${plant.name} marked as watered!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.water_drop),
                          label: const Text('Mark as Watered'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).primaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: color ?? Colors.black87,
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

// --- MAIN APP ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppNotifications.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlantProvider>(
      create: (context) => PlantProvider(),
      builder: (context, child) {
        return MaterialApp(
          title: 'Plant Care Companion',
          theme: ThemeData(
            primarySwatch: Colors.green, // Green theme
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.green, width: 2.0),
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.green.shade200,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: TextStyle(color: Colors.green.shade700),
              floatingLabelStyle: const TextStyle(color: Colors.green),
            ),
            // cardTheme: CardTheme(
            //   elevation: 4,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            // ),
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.green,
            ).copyWith(secondary: Colors.lightGreen),
          ),
          home: const PlantGalleryScreen(),
        );
      },
    );
  }
}
